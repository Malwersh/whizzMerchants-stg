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
const DYNAMODB_REGION = process.env.DYNAMODB_REGION || 'us-east-1';
const COGNITO_REGION = process.env.COGNITO_REGION || 'us-east-1';

const client = new DynamoDBClient({ region: DYNAMODB_REGION });
const docClient = DynamoDBDocumentClient.from(client);

const headers = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'Content-Type,Authorization',
    'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS',
};

// Helper function to create response
function createResponse(statusCode, body) {
    return {
        statusCode,
        headers,
        body: JSON.stringify(body),
    };
}

async function getBusinessId(event) {
    try {
        const authHeader = event.headers?.Authorization || event.headers?.authorization;
        if (!authHeader || !authHeader.startsWith('Bearer ')) {
            console.log("Authorization header is missing or invalid");
            return null;
        }

        const token = authHeader.replace('Bearer ', '');

        // Decode the JWT token (ID token or Access token) to get email
        // JWT format: header.payload.signature
        const parts = token.split('.');
        if (parts.length !== 3) {
            console.log("Invalid JWT token format");
            return null;
        }

        const payload = JSON.parse(Buffer.from(parts[1], 'base64').toString());
        console.log('Decoded token payload:', JSON.stringify(payload, null, 2));
        
        // ID tokens have 'email', Access tokens have 'username' (which is the Cognito user sub/email)
        // Also check 'cognito:username' for other token types
        const email = payload.email || payload.username || payload['cognito:username'];

        if (!email) {
            console.log("Email/username not found in token payload. Available fields:", Object.keys(payload));
            return null;
        }

        console.log(`Getting business for user: ${email}`);

        // Query businesses by email using the email-index (case-insensitive)
        const normalizedEmail = email.toLowerCase().trim();
        const queryParams = {
            TableName: BUSINESSES_TABLE,
            IndexName: 'email-index',
            KeyConditionExpression: 'email = :email',
            ExpressionAttributeValues: {
                ':email': normalizedEmail
            }
        };

        console.log(`Querying business with normalized email: ${normalizedEmail} (v2)`);
        const result = await docClient.send(new QueryCommand(queryParams));

        if (result.Items && result.Items.length > 0) {
            const businessId = result.Items[0].businessId || result.Items[0].id;
            console.log(`Found business ID: ${businessId}`);
            return businessId;
        }

        console.log("No business found for this user");
        return null;
    } catch (error) {
        console.error('Error getting business ID:', error);
        return null;
    }
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
        const { Items } = await docClient.send(new QueryCommand(params));

        // Add 'id' field to each product for frontend compatibility
        const productsWithId = (Items || []).map(item => ({ ...item, id: item.productId }));

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
            FilterExpression: 'businessId = :businessId and contains(searchableName, :searchQuery)',
            ExpressionAttributeValues: {
                ':businessId': businessId,
                ':searchQuery': searchQuery,
            },
        };
        const { Items } = await docClient.send(new ScanCommand(params));

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
        const { name, description, price, categoryId, imageUrl, isAvailable } = JSON.parse(event.body);

        // Validate required fields
        if (!name || !description || price == null || !categoryId) {
            return createResponse(400, {
                success: false,
                message: 'Name, description, price, and categoryId are required'
            });
        }

        const productId = uuidv4();
        const searchableName = name.toLowerCase();

        const newItem = {
            productId: productId, // Use 'productId' as primary key to match existing table structure
            businessId,
            name,
            description,
            price: parseFloat(price),
            categoryId,
            imageUrl: imageUrl || null,
            isAvailable: isAvailable !== false,
            searchableName,
            createdAt: new Date().toISOString(),
            updatedAt: new Date().toISOString(),
        };

        await docClient.send(new PutCommand({ TableName: PRODUCTS_TABLE, Item: newItem }));

        // Return with 'id' field for frontend compatibility
        const responseProduct = { ...newItem, id: newItem.productId };
        return createResponse(201, { success: true, product: responseProduct });
    } catch (error) {
        console.error('Error creating product:', error);
        return createResponse(500, { success: false, message: 'Failed to create product', error: error.message });
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

    // Ensure businessId and productId are not being changed
    delete updates.businessId;
    delete updates.id;
    delete updates.productId;
    
    if (updates.name) {
        updates.searchableName = updates.name.toLowerCase();
    }
    if (updates.price) {
        updates.price = parseFloat(updates.price);
    }
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
            ExpressionAttributeNames: expressionAttributeNames,
            ExpressionAttributeValues: expressionAttributeValues,
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

        await docClient.send(new DeleteCommand({ TableName: PRODUCTS_TABLE, Key: { productId: productId } }));
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
        return createResponse(200, { success: true, categories: Items || [] });
    } catch (error) {
        console.error('Error getting categories:', error);
        return createResponse(500, { success: false, message: 'Failed to get categories', error: error.message });
    }
}

async function handleGetCategoriesByBusinessType(event) {
    const { businessType } = event.pathParameters;
    try {
        const params = {
            TableName: CATEGORIES_TABLE,
            IndexName: 'BusinessTypeIndex',
            KeyConditionExpression: 'businessType = :businessType',
            ExpressionAttributeValues: { ':businessType': businessType },
        };
        const { Items } = await docClient.send(new QueryCommand(params));
        return createResponse(200, { success: true, categories: Items || [] });
    } catch (error) {
        console.error('Error getting categories by business type:', error);
        return createResponse(500, { success: false, message: 'Failed to get categories', error: error.message });
    }
}

module.exports.handler = async (event) => {
    console.log('Received event in Product Management Handler:', JSON.stringify(event, null, 2));
    const { httpMethod, path } = event;

    if (httpMethod === 'OPTIONS') {
        return createResponse(204, {});
    }

    try {
    // Route products endpoints
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
        console.error('Unhandled error in product handler:', error);
        return createResponse(500, { success: false, message: 'Internal server error' });
    }
};
