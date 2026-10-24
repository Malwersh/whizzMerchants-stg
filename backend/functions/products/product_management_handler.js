const {readBranchProductOptions}=require('../shared/branch-product-options');
const {merchantLifecycleClient,merchantHandler}=require('../shared/merchant-lifecycle');
const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const {
  DynamoDBDocumentClient,
  ScanCommand,
  GetCommand,
  PutCommand,
  DeleteCommand,
  UpdateCommand,
  QueryCommand,
} = require('@aws-sdk/lib-dynamodb');
const { CognitoIdentityProviderClient, GetUserCommand } = require('@aws-sdk/client-cognito-identity-provider');
const { v4: uuidv4 } = require('uuid');

const PRODUCTS_TABLE = process.env.PRODUCTS_TABLE;
const CATEGORIES_TABLE = process.env.CATEGORIES_TABLE;
const BUSINESSES_TABLE = process.env.BUSINESSES_TABLE;
// Shared master catalog: one record per real-world product (name/image/barcode),
// reused by all merchants. Merchant rows in PRODUCTS_TABLE keep only price/availability.
const GLOBAL_PRODUCTS_TABLE = process.env.GLOBAL_PRODUCTS_TABLE || 'WhizzMerchants_GlobalProducts';
const DYNAMODB_REGION = process.env.DYNAMODB_REGION || 'us-east-1';
const COGNITO_REGION = process.env.COGNITO_REGION || 'us-east-1';

const client = new DynamoDBClient({ region: DYNAMODB_REGION });
const lifecycleRawDb = DynamoDBDocumentClient.from(client);
const docClient = merchantLifecycleClient(lifecycleRawDb);

const headers = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'Content-Type,Authorization,X-Staff-Session',
    'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS',
};
const validReference=value=>typeof value==='string'&&/^[A-Za-z0-9_-]{1,150}$/.test(value);

// Helper function to create response
function createResponse(statusCode, body) {
    return {
        statusCode,
        headers,
        body: JSON.stringify(body),
    };
}

async function getBusinessId(event) {
    const actor = require('../shared/merchant-lifecycle').merchantRequestContext.getStore();
    return actor?.businessId || null;
}

// --- Product Handlers ---

async function handleGetProducts(event) {
    const businessId = await getBusinessId(event);
    if (!businessId) {
        return createResponse(401, { message: 'Unauthorized' });
    }

    try {
        const params = {
            TableName: PRODUCTS_TABLE,
            IndexName: 'BusinessIdIndex',
            KeyConditionExpression: 'businessId = :businessId',
            ExpressionAttributeValues: { ':businessId': businessId },
        };
        const allItems=[];let lastKey;
        do {
            const page=await docClient.send(new QueryCommand({...params,ExclusiveStartKey:lastKey}));
            allItems.push(...(page.Items||[]));lastKey=page.LastEvaluatedKey;
        } while(lastKey);

        // Add 'id' field to each product for frontend compatibility
        const productsWithId = allItems.map(item => ({ ...item, id: item.productId }));

        return createResponse(200, { success: true, products: productsWithId });
    } catch (error) {
        console.error('Error getting products:', error);
        return createResponse(500, { success: false, message: 'Failed to get products', error: error.message });
    }
}

async function handleSearchProducts(event) {
    const businessId = await getBusinessId(event);
    if (!businessId) {
        return createResponse(401, { message: 'Unauthorized' });
    }

    const searchQuery = (event.queryStringParameters?.q || '').toLowerCase();
    
    try {
        const params = {
            TableName: PRODUCTS_TABLE,
            IndexName: 'BusinessIdIndex',
            KeyConditionExpression: 'businessId = :businessId',
            FilterExpression: 'contains(searchableName, :searchQuery)',
            ExpressionAttributeValues: {
                ':businessId': businessId,
                ':searchQuery': searchQuery,
            },
        };
        const Items=[];let lastKey;
        do {const page=await docClient.send(new QueryCommand({...params,ExclusiveStartKey:lastKey}));Items.push(...(page.Items||[]));lastKey=page.LastEvaluatedKey;} while(lastKey);

        // Add 'id' field to each product for frontend compatibility
        const productsWithId = (Items || []).map(item => ({ ...item, id: item.productId }));

        return createResponse(200, { success: true, products: productsWithId });
    } catch (error) {
        console.error('Error searching products:', error);
        return createResponse(500, { success: false, message: 'Failed to search products', error: error.message });
    }
}

async function handleCreateProduct(event) {
    const businessId = await getBusinessId(event);
    if (!businessId) {
        return createResponse(401, { message: 'Unauthorized' });
    }

    try {
        if(typeof event.body!=='string'||event.body.length>65536)return createResponse(413,{success:false,message:'PRODUCT_PAYLOAD_TOO_LARGE'});
        const body=JSON.parse(event.body);
        const allowed=new Set(['businessId','name','description','price','categoryId','imageUrl','isAvailable','globalProductId','barcode','optionGroups']);
        if(!body||typeof body!=='object'||Array.isArray(body)||Object.keys(body).some(k=>!allowed.has(k)))return createResponse(400,{success:false,message:'INVALID_PRODUCT_FIELDS'});
        const { name, description, price, categoryId, imageUrl, isAvailable, globalProductId, barcode, optionGroups } = body;
        if(globalProductId!==undefined&&!validReference(globalProductId))return createResponse(400,{success:false,message:'INVALID_GLOBAL_PRODUCT'});
        let branchOptions;
        try { if(optionGroups!==undefined)branchOptions=readBranchProductOptions(optionGroups); }
        catch { return createResponse(400,{success:false,message:'INVALID_BRANCH_PRODUCT_OPTIONS'}); }

        if(!Number.isSafeInteger(price)||price<=0||price>1000000000)return createResponse(400,{success:false,message:'INVALID_PRICE'});
        if(description!==undefined&&(typeof description!=='string'||description.length>2000)||isAvailable!==undefined&&typeof isAvailable!=='boolean')return createResponse(400,{success:false,message:'INVALID_PRODUCT_FIELDS'});
        if(barcode!==undefined&&(typeof barcode!=='string'||!/^[0-9A-Za-z._-]{1,100}$/.test(barcode)))return createResponse(400,{success:false,message:'INVALID_BARCODE'});
        if(imageUrl!==undefined&&(typeof imageUrl!=='string'||imageUrl.length>2000||!imageUrl.startsWith('https://')))return createResponse(400,{success:false,message:'INVALID_IMAGE_URL'});

        // 1) Picked from the shared catalog: reuse its name/image/description.
        let globalItem = null;
        if (globalProductId) {
            const g = await docClient.send(new GetCommand({
                TableName: GLOBAL_PRODUCTS_TABLE, Key: { globalProductId },
            }));
            globalItem = g.Item || null;
            if (!globalItem) {
                return createResponse(404, { success: false, message: 'Global product not found' });
            }
        }

        const finalName = name || globalItem?.canonicalName;
        const finalCategoryId = categoryId || globalItem?.categoryId;
        if (typeof finalName!=='string'||!finalName.trim()||finalName.length>150||typeof finalCategoryId!=='string'||!finalCategoryId.trim()||finalCategoryId.length>150) {
            return createResponse(400, {
                success: false,
                message: 'name and categoryId are required (or pick a global product)'
            });
        }

        const { Item: category } = await docClient.send(new GetCommand({
            TableName: CATEGORIES_TABLE, Key: { categoryId: finalCategoryId }, ConsistentRead: true,
        }));
        if (!category || category.isActive === false || category.is_active === false || category.businessId&&category.businessId!==businessId) {
            return createResponse(400, { success: false, message: 'اختر قسماً متاحاً من القائمة الحالية.' });
        }

        // 2) New product: dedupe by barcode, else add it to the catalog for others to reuse.
        if (!globalItem && barcode) {
            globalItem = await findOrCreateGlobalProduct({
                name: finalName,
                description: description || '',
                categoryId: finalCategoryId,
                imageUrl: imageUrl || null,
                barcode: barcode || null,
                createdBy: businessId,
            });
        } else if (globalItem) {
            await incrementGlobalUsage(globalItem.globalProductId);
        }

        const productId = uuidv4();
        const now = new Date().toISOString();
        const newItem = {
            productId,
            businessId,
            ...(branchOptions!==undefined?{optionGroups:branchOptions}:{}),
            globalProductId: globalItem?.globalProductId || null,
            name: finalName,
            description: description || globalItem?.description || '',
            price,
            categoryId: finalCategoryId,
            imageUrl: imageUrl || globalItem?.imageUrl || null,
            barcode: barcode || globalItem?.barcode || null,
            isAvailable: isAvailable !== false,
            searchableName: finalName.toLowerCase(),
            createdAt: now,
            updatedAt: now,
        };

        await docClient.send(new PutCommand({ TableName: PRODUCTS_TABLE, Item: newItem,ConditionExpression:'attribute_not_exists(productId)' }));

        const responseProduct = { ...newItem, id: newItem.productId };
        return createResponse(201, { success: true, product: responseProduct });
    } catch (error) {
        console.error('Error creating product:', error);
        return createResponse(500, { success: false, message: 'Failed to create product', error: error.message });
    }
}

// --- Global catalog helpers ---

async function incrementGlobalUsage(globalProductId) {
    try {
        await docClient.send(new UpdateCommand({
            TableName: GLOBAL_PRODUCTS_TABLE,
            Key: { globalProductId },
            UpdateExpression: 'ADD usageCount :one SET updatedAt = :now',
            ExpressionAttributeValues: { ':one': 1, ':now': new Date().toISOString() },
        }));
    } catch (e) {
        console.warn('incrementGlobalUsage failed (non-fatal):', e.message);
    }
}

async function findOrCreateGlobalProduct({ name, description, categoryId, imageUrl, barcode, createdBy }) {
    try {
        if (barcode) {
            const { Items } = await docClient.send(new QueryCommand({
                TableName: GLOBAL_PRODUCTS_TABLE,
                IndexName: 'BarcodeIndex',
                KeyConditionExpression: 'barcode = :b',
                ExpressionAttributeValues: { ':b': barcode },
                Limit: 1,
            }));
            if (Items && Items[0]) {
                await incrementGlobalUsage(Items[0].globalProductId);
                return Items[0];
            }
        }
        // Only share products that have an image (the expensive part to duplicate).
        if (!imageUrl) return null;

        const now = new Date().toISOString();
        const item = {
            globalProductId: uuidv4(),
            canonicalName: name,
            searchableName: name.toLowerCase().trim(),
            description,
            categoryId,
            imageUrl,
            usageCount: 1,
            createdBy,
            createdAt: now,
            updatedAt: now,
        };
        if (barcode) item.barcode = barcode;
        await docClient.send(new PutCommand({ TableName: GLOBAL_PRODUCTS_TABLE, Item: item }));
        return item;
    } catch (e) {
        console.warn('findOrCreateGlobalProduct failed (non-fatal):', e.message);
        return null;
    }
}

// GET /products/global-search?q=...  or  ?barcode=...
async function handleGlobalSearch(event) {
    const businessId = await getBusinessId(event);
    if (!businessId) return createResponse(401, { message: 'Unauthorized' });

    const q = (event.queryStringParameters?.q || '').toLowerCase().trim();
    const barcode = (event.queryStringParameters?.barcode || '').trim();
    try {
        let items = [];
        if (barcode) {
            const r = await docClient.send(new QueryCommand({
                TableName: GLOBAL_PRODUCTS_TABLE,
                IndexName: 'BarcodeIndex',
                KeyConditionExpression: 'barcode = :b',
                ExpressionAttributeValues: { ':b': barcode },
            }));
            items = r.Items || [];
        } else if (q.length >= 2) {
            // Paginated scan with contains(); fine for current size. Move to
            // OpenSearch when the catalog grows to hundreds of thousands of items.
            let lastKey;
            do {
                const r = await docClient.send(new ScanCommand({
                    TableName: GLOBAL_PRODUCTS_TABLE,
                    FilterExpression: 'contains(searchableName, :q)',
                    ExpressionAttributeValues: { ':q': q },
                    ExclusiveStartKey: lastKey,
                }));
                items.push(...(r.Items || []));
                lastKey = r.LastEvaluatedKey;
            } while (lastKey && items.length < 50);
        }
        items = items
            .filter((i) => i.imageUrl && !String(i.imageUrl).includes('example.com'))
            .sort((a, b) => (b.usageCount || 0) - (a.usageCount || 0))
            .slice(0, 20);
        return createResponse(200, { success: true, products: items });
    } catch (error) {
        console.error('Error searching global catalog:', error);
        return createResponse(500, { success: false, message: 'Failed to search catalog', error: error.message });
    }
}

async function handleGetProduct(event) {
    const businessId = await getBusinessId(event);
    if (!businessId) {
        return createResponse(401, { message: 'Unauthorized' });
    }
    
    const { productId } = event.pathParameters;

    try {
        const { Item } = await docClient.send(new GetCommand({ TableName: PRODUCTS_TABLE, Key: { productId: productId } }));
        if (!Item || Item.businessId !== businessId) {
            return createResponse(404, { success: false, message: 'Product not found' });
        }
        // Add 'id' field for frontend compatibility
        const responseProduct = { ...Item, id: Item.productId };
        return createResponse(200, { success: true, product: responseProduct });
    } catch (error) {
        console.error('Error getting product:', error);
        return createResponse(500, { success: false, message: 'Failed to get product', error: error.message });
    }
}

async function handleUpdateProduct(event) {
    const businessId = await getBusinessId(event);
    if (!businessId) {
        return createResponse(401, { message: 'Unauthorized' });
    }

    const { productId } = event.pathParameters;
    const updates = JSON.parse(event.body);
    const allowed=new Set(['businessId','name','description','price','categoryId','imageUrl','isAvailable','barcode','optionGroups']);
    if(!updates||typeof updates!=='object'||Array.isArray(updates)||Object.keys(updates).some(k=>!allowed.has(k)))return createResponse(400,{success:false,message:'INVALID_PRODUCT_FIELDS'});
    if(Object.hasOwn(updates,'optionGroups')){
        try { updates.optionGroups=readBranchProductOptions(updates.optionGroups); }
        catch { return createResponse(400,{success:false,message:'INVALID_BRANCH_PRODUCT_OPTIONS'}); }
    }

    if(Object.hasOwn(updates,'categoryId')&&!validReference(updates.categoryId))return createResponse(400,{success:false,message:'INVALID_CATEGORY'});
    if (Object.hasOwn(updates, 'categoryId')) {
        const { Item: category } = await docClient.send(new GetCommand({
            TableName: CATEGORIES_TABLE, Key: { categoryId: updates.categoryId }, ConsistentRead: true,
        }));
        if (!category || category.isActive === false || category.is_active === false || category.businessId&&category.businessId!==businessId) {
            return createResponse(400, { success: false, message: 'اختر قسماً متاحاً من القائمة الحالية.' });
        }
    }

    // Ensure businessId and productId are not being changed
    delete updates.businessId;
    delete updates.id;
    delete updates.productId;
    
    if(updates.name!==undefined&&(typeof updates.name!=='string'||!updates.name.trim()||updates.name.length>150))return createResponse(400,{success:false,message:'INVALID_NAME'});
    if(updates.description!==undefined&&(typeof updates.description!=='string'||updates.description.length>2000))return createResponse(400,{success:false,message:'INVALID_DESCRIPTION'});
    if(updates.price!==undefined&&(!Number.isSafeInteger(updates.price)||updates.price<=0||updates.price>1000000000))return createResponse(400,{success:false,message:'INVALID_PRICE'});
    if(updates.isAvailable!==undefined&&typeof updates.isAvailable!=='boolean')return createResponse(400,{success:false,message:'INVALID_AVAILABILITY'});
    if(updates.barcode!==undefined&&(typeof updates.barcode!=='string'||!/^[0-9A-Za-z._-]{1,100}$/.test(updates.barcode)))return createResponse(400,{success:false,message:'INVALID_BARCODE'});
    if(updates.imageUrl!==undefined&&(typeof updates.imageUrl!=='string'||updates.imageUrl.length>2000||!updates.imageUrl.startsWith('https://')))return createResponse(400,{success:false,message:'INVALID_IMAGE_URL'});
    if(updates.name!==undefined)updates.searchableName=updates.name.toLowerCase();
    if(!Object.keys(updates).length)return createResponse(400,{success:false,message:'NO_PRODUCT_CHANGES'});
    updates.updatedAt = new Date().toISOString();

    const updateExpression = 'set ' + Object.keys(updates).map(key => `#${key} = :${key}`).join(', ');
    const expressionAttributeNames = Object.keys(updates).reduce((acc, key) => ({...acc, [`#${key}`]: key}), {});
    const expressionAttributeValues = Object.keys(updates).reduce((acc, key) => ({...acc, [`:${key}`]: updates[key]}), {});

    try {
        // First check if the product exists and belongs to this business
        const { Item } = await docClient.send(new GetCommand({ TableName: PRODUCTS_TABLE, Key: { productId: productId } }));
        if (!Item || Item.businessId !== businessId) {
            return createResponse(404, { success: false, message: 'Product not found or you do not have permission to update it.' });
        }

        const params = {
            TableName: PRODUCTS_TABLE,
            Key: { productId: productId },
            UpdateExpression: updateExpression,
            ConditionExpression: Item.updatedAt===undefined?'#branchOwner = :branchOwner AND attribute_not_exists(#previousUpdatedAt)':'#branchOwner = :branchOwner AND #previousUpdatedAt = :previousUpdatedAt',
            ExpressionAttributeNames: {...expressionAttributeNames,'#branchOwner':'businessId','#previousUpdatedAt':'updatedAt'},
            ExpressionAttributeValues: {...expressionAttributeValues,':branchOwner':businessId,...(Item.updatedAt===undefined?{}:{':previousUpdatedAt':Item.updatedAt})},
            ReturnValues: 'ALL_NEW',
        };

        const { Attributes } = await docClient.send(new UpdateCommand(params));
        // Add 'id' field for frontend compatibility
        const responseProduct = { ...Attributes, id: Attributes.productId };
        return createResponse(200, { success: true, product: responseProduct });
    } catch (error) {
        console.error('Error updating product:', error);
        return createResponse(500, { success: false, message: 'Failed to update product', error: error.message });
    }
}

async function handleDeleteProduct(event) {
    const businessId = await getBusinessId(event);
    if (!businessId) {
        return createResponse(401, { message: 'Unauthorized' });
    }

    const { productId } = event.pathParameters;

    try {
        const { Item } = await docClient.send(new GetCommand({ TableName: PRODUCTS_TABLE, Key: { productId: productId } }));
        if (!Item || Item.businessId !== businessId) {
            return createResponse(404, { success: false, message: 'Product not found or you do not have permission to delete it.' });
        }

        await docClient.send(new DeleteCommand({ TableName: PRODUCTS_TABLE, Key: { productId: productId },ConditionExpression:Item.updatedAt===undefined?'businessId=:b AND attribute_not_exists(updatedAt)':'businessId=:b AND updatedAt=:u',ExpressionAttributeValues:{':b':businessId,...(Item.updatedAt===undefined?{}:{':u':Item.updatedAt})} }));
        return createResponse(200, { success: true, message: 'Product deleted successfully' });
    } catch (error) {
        console.error('Error deleting product:', error);
        return createResponse(500, { success: false, message: 'Failed to delete product', error: error.message });
    }
}

// --- Category Handlers ---

async function handleGetCategories(event) {
    try {
        const { Items } = await docClient.send(new ScanCommand({ TableName: CATEGORIES_TABLE }));
        const actor=require('../shared/merchant-lifecycle').merchantRequestContext.getStore();
        const categories=(Items||[]).filter(c=>!c.businessId||c.businessId===actor?.businessId).map(c=>Object.fromEntries(['categoryId','categoryName','name_ar','name','description','sortOrder','isActive','is_active','businessId','version','createdAt','updatedAt'].filter(k=>c[k]!==undefined).map(k=>[k,c[k]])));
        return createResponse(200, { success: true, categories });
    } catch (error) {
        console.error('Error getting categories:', error);
        return createResponse(500, { success: false, message: 'Failed to get categories', error: error.message });
    }
}

async function handleGetCategoriesByBusinessType(event) {
    const { businessType } = event.pathParameters;
    try {
        let Items = [];
        try {
            const params = {
                TableName: CATEGORIES_TABLE,
                IndexName: 'BusinessTypeIndex',
                KeyConditionExpression: 'businessType = :businessType',
                ExpressionAttributeValues: { ':businessType': businessType },
            };
            ({ Items } = await docClient.send(new QueryCommand(params)));
        } catch (indexError) {
            console.warn('BusinessTypeIndex query failed, will fall back to scan:', indexError.message);
            Items = [];
        }

        // Legacy categories have no businessType attribute. If the type-specific
        // query returns nothing, fall back to all active categories (shared set).
        if (!Items || Items.length === 0) {
            const { Items: allItems } = await docClient.send(new ScanCommand({ TableName: CATEGORIES_TABLE }));
            Items = (allItems || []).filter((c) => c.isActive !== false);
        }

        const actor=require('../shared/merchant-lifecycle').merchantRequestContext.getStore();
        const categories=(Items||[]).filter(c=>(!c.businessId||c.businessId===actor?.businessId)&&c.isActive!==false&&c.is_active!==false);
        return createResponse(200, { success: true, categories });
    } catch (error) {
        console.error('Error getting categories by business type:', error);
        return createResponse(500, { success: false, message: 'Failed to get categories', error: error.message });
    }
}

module.exports.handler = async (event) => {
    console.log('Received event in Product Management Handler:', {method:event.httpMethod,path:event.path});
    const { httpMethod, path } = event;

    if (httpMethod === 'OPTIONS') {
        return createResponse(204, {});
    }

    try {
    const actor=require('../shared/merchant-lifecycle').merchantRequestContext.getStore();
    if(actor?.deviceGuards&&path.startsWith('/products/imports/')){
        return createResponse(403,{success:false,code:'IMPORT_PERMISSION_REQUIRED'});
    }
    if(actor&&['POST','PUT','DELETE'].includes(httpMethod)&&!path.startsWith('/products/imports/')&&path.startsWith('/products')){
        const mutationActor={...actor,ownerId:actor.ownerId||actor.sub,deviceGuards:actor.deviceGuards||[]};
        const result=await require('../shared/branch-device-menu').mutate(actor.deviceGuards?lifecycleRawDb:docClient,mutationActor,event);
        return {...result,headers};
    }
    // Route products endpoints
        if(actor&&['POST','PUT','DELETE'].includes(httpMethod)&&path.startsWith('/categories')){
            if(actor.deviceGuards)return createResponse(403,{success:false,code:'CATEGORY_PERMISSION_REQUIRED'});
            const categories=require('./branch_categories').createBranchCategoryService(docClient,{actor:()=>actor});
            const category=await categories.mutate(actor.businessId,event);return createResponse(httpMethod==='POST'?201:200,{success:true,category});
        }
        if (path === '/products/imports/preview' && httpMethod === 'POST') {
            const businessId=await getBusinessId(event);
            const productImports=require('./product_import').createProductImportService(docClient,{actor:()=>require('../shared/merchant-lifecycle').merchantRequestContext.getStore()});
            return createResponse(201,{success:true,job:await productImports.preview(businessId,JSON.parse(event.body||'{}'))});
        }
        if (path.startsWith('/products/imports/')) {
            const businessId=await getBusinessId(event);
            const productImports=require('./product_import').createProductImportService(docClient,{actor:()=>require('../shared/merchant-lifecycle').merchantRequestContext.getStore()});
            const jobId=event.pathParameters?.importJobId||path.split('/')[3];
            if(httpMethod==='GET')return createResponse(200,{success:true,job:await productImports.get(businessId,jobId)});
            if(httpMethod==='POST'&&path.endsWith('/commit'))return createResponse(200,{success:true,job:await productImports.commit(businessId,jobId,JSON.parse(event.body||'{}'))});
        }
        if (path.startsWith('/products/global-search')) {
            return handleGlobalSearch(event);
        }
        if (path.startsWith('/products/search')) {
            return handleSearchProducts(event);
        }
        if (path.startsWith('/products/')) {
            if (httpMethod === 'GET') return handleGetProduct(event);
            if (httpMethod === 'PUT') return handleUpdateProduct(event);
            if (httpMethod === 'DELETE') return handleDeleteProduct(event);
        }
        if (path === '/products') {
            if (httpMethod === 'GET') return handleGetProducts(event);
            if (httpMethod === 'POST') return handleCreateProduct(event);
        }

        // Route category endpoints
        if (path.startsWith('/categories/business-type/')) {
            return handleGetCategoriesByBusinessType(event);
        }
        if (path === '/categories') {
            return handleGetCategories(event);
        }

        return createResponse(404, { success: false, message: 'Route Not Found in Product Handler' });
    } catch (error) {
        if(error.status)return createResponse(error.status,{success:false,code:error.message});
        console.error('Unhandled error in product handler:', error);
        return createResponse(500, { success: false, message: 'Internal server error' });
    }
};

const protectedProductHandler = merchantHandler(module.exports.handler,{db:lifecycleRawDb,deviceMenu:true});
module.exports.handler = (event, context) => {
    // Reference reads still verify the caller and the explicitly selected branch.
    if (event.httpMethod === 'GET' && event.path?.startsWith('/categories') && event.queryStringParameters?.businessId) {
        event = {...event, body: JSON.stringify({businessId: event.queryStringParameters.businessId})};
    }
    return protectedProductHandler(event, context);
};
