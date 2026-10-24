const discountEngine=require('../shared/discount-engine');
const {patchTerms,supported,hasDiscountCustomizations,discountGoodsSelection}=require('../shared/discount-contract');
const {revision,fence}=require('../shared/campaign-version');
const {merchantLifecycleClient,merchantHandler,merchantRequestContext}=require('../shared/merchant-lifecycle');
const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { DynamoDBDocumentClient, GetCommand, PutCommand, UpdateCommand, QueryCommand, ScanCommand, DeleteCommand } = require('@aws-sdk/lib-dynamodb');
const { CognitoIdentityProviderClient, GetUserCommand } = require('@aws-sdk/client-cognito-identity-provider');
const { v4: uuidv4 } = require('uuid');

// JWT decode for ID token handling
function decodeJWT(token) {
    try {
        const base64Payload = token.split('.')[1];
        const payload = Buffer.from(base64Payload, 'base64').toString();
        return JSON.parse(payload);
    } catch (error) {
        console.error('Error decoding JWT:', error);
        return null;
    }
}

// Helper function to create API Gateway response
function createResponse(statusCode, body) {
    return {
        statusCode: statusCode,
        headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
            'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS'
        },
        body: JSON.stringify(body)
    };
}

function discountFailure(error,message){const conflict=['TransactionCanceledException','ConditionalCheckFailedException'].includes(error.name);return createResponse(error.status||(conflict?409:500),{success:false,code:error.status?error.message:conflict?'VERSION_OR_STATE_CONFLICT':'DISCOUNT_WRITE_FAILED',message:error.message==='INVALID_DISCOUNT_USAGE_LIMIT'?'أدخل حدود الاستخدام كأعداد صحيحة أكبر من صفر، أو اتركها فارغة دون حد.':error.message==='SHARED_DISCOUNT_TERMS_LOCKED'?'هذا خصم مشترك معتمد؛ لا يمكن تعديل شروطه. أوقفه وأنشئ خصمًا جديدًا.':error.message==='SHARED_DISCOUNT_DELETE_FORBIDDEN'?'لا يمكن حذف سجل خصم مشترك. يمكنك إيقافه وإنشاء بديل.':error.message==='SHARED_DISCOUNT_RESTART_FORBIDDEN'?'هذا الخصم المشترك متوقف؛ أنشئ بديلًا بمشاركة وموافقة جديدتين.':conflict?'تغير الخصم أو استخدامه؛ أعد تحميل القائمة.':message});}

function validateUsageTerms(data){for(const name of ['usageLimit','perCustomerLimit','maxDiscountAmount']){const value=data[name];if(value!==undefined&&value!==null&&(!Number.isSafeInteger(value)||value<1||value>1000000000))throw Object.assign(Error('INVALID_DISCOUNT_USAGE_LIMIT'),{status:400});}}

// Environment variables
const DISCOUNTS_TABLE = process.env.DISCOUNTS_TABLE || 'WhizzMerchants_Discounts';
const BUSINESSES_TABLE = process.env.BUSINESSES_TABLE || 'WhizzMerchants_Businesses';
const USER_POOL_ID = process.env.COGNITO_USER_POOL_ID;

exports.handler = async (event) => {
    console.log('Discount Management Handler - Event:', {method:event.httpMethod,path:event.path});

    // Instantiate AWS clients for this invocation
    const cognito = new CognitoIdentityProviderClient({ region: process.env.AWS_REGION || 'us-east-1' });
    const dynamoDbClient = new DynamoDBClient({ region: process.env.AWS_REGION || 'us-east-1' });
    const dynamodb = merchantLifecycleClient(DynamoDBDocumentClient.from(dynamoDbClient));

    const { httpMethod, path, pathParameters, headers } = event;

    // Handle Base64 encoded request body from API Gateway
    let requestBody = event.body;
    if (event.isBase64Encoded && requestBody) {
        try {
            requestBody = Buffer.from(requestBody, 'base64').toString('utf-8');
            console.log('📝 Decoded Base64 request body');
        } catch (decodeError) {
            console.error('❌ Failed to decode Base64 body:', decodeError);
        }
    }

    try {
        // Extract token from Authorization header (can be access token or ID token)
        const authHeader = headers?.Authorization || headers?.authorization;
        if (!authHeader || !authHeader.startsWith('Bearer ')) {
            return createResponse(401, { success: false, message: 'Missing or invalid authorization header' });
        }

        const token = authHeader.replace('Bearer ', '');

        // Verify the token and get user info (handles both access tokens and ID tokens)
        console.log('Getting user info from token...');
        const userInfo = await getUserInfoFromToken(cognito, token);
        console.log('Authenticated merchant discount request');
        if (!userInfo) {
            return createResponse(401, { success: false, message: 'Invalid access token' });
        }

        // Get business info for user
        console.log('Getting business info for user...');
        const businessInfo = await getBusinessInfoForUser(dynamodb, userInfo);
        console.log('Scoped merchant discount request');
        if (!businessInfo) {
            return createResponse(404, { success: false, message: 'Business not found for user' });
        }

        // Route the request based on HTTP method and path
        if (httpMethod === 'GET' && path === '/discounts') {
            return await handleGetDiscounts(dynamodb, businessInfo.businessId);
        } else if (httpMethod === 'POST' && path === '/discounts') {
            return await handleCreateDiscount(dynamodb, businessInfo.businessId, JSON.parse(requestBody || '{}'));
        } else if (httpMethod === 'GET' && pathParameters?.discountId) {
            return await handleGetDiscount(dynamodb, businessInfo.businessId, pathParameters.discountId);
        } else if (httpMethod === 'PUT' && pathParameters?.discountId) {
            return await handleUpdateDiscount(dynamodb, businessInfo.businessId, pathParameters.discountId, JSON.parse(requestBody || '{}'));
        } else if (httpMethod === 'DELETE' && pathParameters?.discountId) {
            return await handleDeleteDiscount(dynamodb, businessInfo.businessId, pathParameters.discountId);
        } else if (httpMethod === 'PATCH' && pathParameters?.discountId && path.includes('/toggle-status')) {
            return await handleToggleDiscountStatus(dynamodb, businessInfo.businessId, pathParameters.discountId);
        } else if (httpMethod === 'POST' && path.includes('/validate-discount')) {
            return await handleValidateDiscount(dynamodb, businessInfo.businessId, JSON.parse(requestBody || '{}'));
        } else if (httpMethod === 'POST' && path.includes('/apply-discount')) {
            return await handleApplyDiscount(dynamodb, businessInfo.businessId, JSON.parse(requestBody || '{}'));
        } else if (httpMethod === 'GET' && path.includes('/stats')) {
            return await handleGetDiscountStats(dynamodb, businessInfo.businessId);
        } else {
            return createResponse(404, { success: false, message: 'Endpoint not found' });
        }
    } catch (error) {
        console.error('Error in discount management handler:', error);
        return createResponse(500, { success: false, message: 'Internal server error', error: error.message });
    }
};

// Helper function to get user info from access token or ID token
async function getUserInfoFromToken(cognito, token) {
    try {
        // First try as access token with Cognito GetUser
        try {
            const command = new GetUserCommand({ AccessToken: token });
            const userResponse = await cognito.send(command);
            const email = userResponse.UserAttributes.find(attr => attr.Name === 'email')?.Value;
            const userId = userResponse.UserAttributes.find(attr => attr.Name === 'sub')?.Value;

            console.log('✅ Successfully validated access token');
            return {
                userId,
                email,
                cognitoUserId: userId
            };
        } catch (cognitoError) {
            console.log('⚠️ Access token validation failed, trying ID token decode:', cognitoError.message);

            // If access token fails, try to decode as ID token (phone-only users have no email)
            const decoded = decodeJWT(token);
            if (decoded && decoded.sub) {
                console.log('✅ Successfully decoded ID token');
                return {
                    userId: decoded.sub,
                    email: decoded.email || null,
                    phoneNumber: decoded.phone_number || null,
                    cognitoUserId: decoded.sub
                };
            }
        }

        console.error('❌ Both access token and ID token validation failed');
        return null;
    } catch (error) {
        console.error('Error getting user info from token:', error);
        return null;
    }
}

// Helper function to get business info for user
async function getBusinessInfoForUser(dynamodb, userInfo) {
    const verified=merchantRequestContext.getStore();
    if(verified?.sub!==userInfo?.userId||!verified?.businessId)throw Error('VERIFIED_MERCHANT_SCOPE_REQUIRED');
    return (await dynamodb.send(new GetCommand({TableName:BUSINESSES_TABLE,Key:{businessId:verified.businessId},ConsistentRead:true}))).Item;
}

// Both views read the same branch index and must never report a partial page as complete.
async function readBusinessDiscounts(dynamodb, businessId) {
    const discounts = [];
    let cursor;
    for (let page = 0; page < 100; page++) {
        const result = await dynamodb.send(new QueryCommand({
            TableName: DISCOUNTS_TABLE,
            IndexName: 'BusinessIdIndex',
            KeyConditionExpression: '#business = :business',
            ExpressionAttributeNames: { '#business': 'businessId' },
            ExpressionAttributeValues: { ':business': businessId },
            Limit: 100,
            ...(cursor ? { ExclusiveStartKey: cursor } : {})
        }));
        discounts.push(...(result.Items || []).filter(row => row.businessId === businessId));
        cursor = result.LastEvaluatedKey;
        if (!cursor) return discounts;
    }
    throw Object.assign(Error('DISCOUNT_LIST_INCOMPLETE'), { statusCode: 503 });
}

async function sharingView(db,row){const lock=await require('../shared/shared-discount-lock').read(db,'MERCHANT',row);return {sharingLocked:lock.locked,sharingCanActivate:lock.initiallyInactive&&!row.sharedStopped};}

// GET /discounts - Get all discounts for a business
async function handleGetDiscounts(dynamodb, businessId) {
    try {
        const discounts = await readBusinessDiscounts(dynamodb, businessId);

        return createResponse(200, {
            success: true,
            discounts: await Promise.all(discounts.map(async row=>({...row,revision:revision(row),...await sharingView(dynamodb,row)}))),
            count: discounts.length
        });
    } catch (error) {
        console.error('Error getting discounts:', error);
        return createResponse(error.statusCode || 500, { success: false, message: 'Failed to retrieve discounts', error: error.message });
    }
}

// POST /discounts - Create a new discount
async function handleCreateDiscount(dynamodb, businessId, discountData) {
    try {
        validateUsageTerms(discountData);
        // Validate required fields
        const requiredFields = ['title', 'type', 'value', 'validFrom', 'validTo'];
        for (const field of requiredFields) {
            // Special handling for 'value' field to allow 0
            if (field === 'value') {
                if (discountData[field] === undefined || discountData[field] === null || discountData[field] === '') {
                    return createResponse(400, {
                        success: false,
                        message: `Missing required field: ${field}`
                    });
                }
            } else {
                if (!discountData[field]) {
                    return createResponse(400, {
                        success: false,
                        message: `Missing required field: ${field}`
                    });
                }
            }
        }

        // Validate discount type
        const validTypes = ['percentage', 'fixedAmount', 'freeDelivery'];
        if (!validTypes.includes(discountData.type)) {
            return createResponse(400, {
                success: false,
                message: 'Invalid discount type'
            });
        }

        // Validate value ranges (server-side, UI presets are cosmetic)
        const numValue = parseFloat(discountData.value);
        if (isNaN(numValue) || numValue < 0) {
            return createResponse(400, {
                success: false,
                message: 'Discount value must be a non-negative number'
            });
        }
        if (discountData.type === 'percentage' && (numValue <= 0 || numValue > 100)) {
            return createResponse(400, {
                success: false,
                message: 'Percentage discount must be between 1 and 100'
            });
        }
        if (discountData.type === 'fixedAmount' && numValue <= 0) {
            return createResponse(400, {
                success: false,
                message: 'Fixed amount discount must be greater than 0'
            });
        }

        // Validate applicability
        const validApplicability = ['allItems', 'specificItems', 'specificCategories', 'minimumOrder'];
        if (discountData.applicability && !validApplicability.includes(discountData.applicability)) {
            return createResponse(400, {
                success: false,
                message: 'Invalid discount applicability'
            });
        }

        // Validate Buy X Get Y specific fields
        if (discountData.type === 'buyXGetY' || discountData.type === 'conditional') {
            const conditionalParams = discountData.conditionalParameters || {};
            if (!conditionalParams.buyItemId || !conditionalParams.getItemId ||
                !conditionalParams.buyQuantity || !conditionalParams.getQuantity) {
                return createResponse(400, {
                    success: false,
                    message: 'Missing required fields for Buy X Get Y discount'
                });
            }
        }

        const discountId = uuidv4();
        const now = new Date().toISOString();
        const discount = {
            businessId: businessId,
            discountId: discountId,
            id: discountId, // For frontend compatibility
            title: discountData.title,
            description: discountData.description || '',
            type: discountData.type,
            value: parseFloat(discountData.value),
            applicability: discountData.applicability || 'allItems',
            applicable_item_ids: discountData.applicableItemIds || [],
            applicable_category_ids: discountData.applicableCategoryIds || [],
            minimum_order_amount: parseFloat(discountData.minimumOrderAmount || 0),
            valid_from: discountData.validFrom,
            valid_to: discountData.validTo,
            usage_limit: discountData.usageLimit ?? null,
            perCustomerLimit: discountData.perCustomerLimit ?? null,
            singleUse: discountData.perCustomerLimit === 1,
            maxDiscountAmount: discountData.maxDiscountAmount ?? null,
            usage_count: 0,
            status: discountData.status || 'active',
            conditional_rule: discountData.conditionalRule || null,
            conditional_parameters: discountData.conditionalParameters || {},
            imageUrl: discountData.imageUrl || null,
            created_at: now,
            updated_at: now
        };

        if(!supported(discount)||!discountEngine.validShape(discountEngine.normalizeDiscount(discount),Number.MAX_SAFE_INTEGER)) return createResponse(400,{success:false,message:'INVALID_DISCOUNT_TERMS'});
        const params = {
            TableName: DISCOUNTS_TABLE,
            Item: discount
        };

        await dynamodb.send(new PutCommand(params));

        return createResponse(201, {
            success: true,
            message: 'Discount created successfully',
            discount: {...discount,version:1,revision:revision({...discount,version:1})}
        });
    } catch (error) {
        console.error('Error creating discount:', error);
        return discountFailure(error, 'Failed to create discount');
    }
}

// GET /discounts/{discountId} - Get a specific discount
async function handleGetDiscount(dynamodb, businessId, discountId) {
    try {
        const params = {
            TableName: DISCOUNTS_TABLE,
            Key: {
                discountId: discountId
            }
        };

        const result = await dynamodb.send(new GetCommand(params));

        if (!result.Item) {
            return createResponse(404, { success: false, message: 'Discount not found' });
        }

        // Check if the discount belongs to the business
        if (result.Item.businessId !== businessId) {
            return createResponse(403, { success: false, message: 'Access denied to this discount' });
        }

        return createResponse(200, {
            success: true,
            discount: {...result.Item,revision:revision(result.Item),...await sharingView(dynamodb,result.Item)}
        });
    } catch (error) {
        console.error('Error getting discount:', error);
        return createResponse(500, { success: false, message: 'Failed to retrieve discount' });
    }
}

// PUT /discounts/{discountId} - Update a discount
async function handleUpdateDiscount(dynamodb, businessId, discountId, updateData) {
    try {
        validateUsageTerms(updateData);
        // First, verify the discount exists and belongs to the user's business
        const existingDiscount = await handleGetDiscount(dynamodb, businessId, discountId);
        if (existingDiscount.statusCode !== 200) {
            return existingDiscount;
        }

        // Use expression attribute names for every field: bare names like
        // "status" (and potentially "type"/"value") collide with DynamoDB
        // reserved keywords and make every update fail with a
        // ValidationException.
        let updateExpression = 'SET #updated_at = :timestamp';
        const expressionAttributeNames = {
            '#updated_at': 'updated_at'
        };
        const expressionAttributeValues = {
            ':timestamp': new Date().toISOString()
        };
        for(const field of ['perCustomerLimit','maxDiscountAmount'])if(updateData[field]!==undefined){expressionAttributeNames['#'+field]=field;expressionAttributeValues[':'+field]=updateData[field];updateExpression+=', #'+field+' = :'+field;}
        if(updateData.perCustomerLimit!==undefined){expressionAttributeNames['#singleUse']='singleUse';expressionAttributeValues[':singleUse']=updateData.perCustomerLimit===1;updateExpression+=', #singleUse = :singleUse';}
        const validTypes = ['percentage', 'fixedAmount', 'freeDelivery'];
        const effectiveType = updateData.type !== undefined
            ? updateData.type
            : JSON.parse(existingDiscount.body).discount?.type;
        if (updateData.type !== undefined && !validTypes.includes(updateData.type)) {
            return createResponse(400, {
                success: false,
                message: 'Invalid discount type'
            });
        }
        if (updateData.value !== undefined) {
            const numValue = parseFloat(updateData.value);
            if (isNaN(numValue) || numValue < 0) {
                return createResponse(400, {
                    success: false,
                    message: 'Discount value must be a non-negative number'
                });
            }
            if (effectiveType === 'percentage' && (numValue <= 0 || numValue > 100)) {
                return createResponse(400, {
                    success: false,
                    message: 'Percentage discount must be between 1 and 100'
                });
            }
            if (effectiveType === 'fixedAmount' && numValue <= 0) {
                return createResponse(400, {
                    success: false,
                    message: 'Fixed amount discount must be greater than 0'
                });
            }
        }

        if (updateData.title !== undefined) {
            updateExpression += ', #title = :title';
            expressionAttributeNames['#title'] = 'title';
            expressionAttributeValues[':title'] = updateData.title;
        }
        if (updateData.description !== undefined) {
            updateExpression += ', #description = :description';
            expressionAttributeNames['#description'] = 'description';
            expressionAttributeValues[':description'] = updateData.description;
        }
        if (updateData.value !== undefined) {
            updateExpression += ', #value = :value';
            expressionAttributeNames['#value'] = 'value';
            expressionAttributeValues[':value'] = parseFloat(updateData.value);
        }
        if (updateData.type !== undefined) {
            updateExpression += ', #type = :type';
            expressionAttributeNames['#type'] = 'type';
            expressionAttributeValues[':type'] = updateData.type;
        }
        if (updateData.applicability !== undefined) {
            updateExpression += ', #applicability = :applicability';
            expressionAttributeNames['#applicability'] = 'applicability';
            expressionAttributeValues[':applicability'] = updateData.applicability;
        }
        if (updateData.applicableItemIds !== undefined) {
            updateExpression += ', #applicable_item_ids = :applicable_item_ids';
            expressionAttributeNames['#applicable_item_ids'] = 'applicable_item_ids';
            expressionAttributeValues[':applicable_item_ids'] = updateData.applicableItemIds;
        }
        if (updateData.applicableCategoryIds !== undefined) {
            updateExpression += ', #applicable_category_ids = :applicable_category_ids';
            expressionAttributeNames['#applicable_category_ids'] = 'applicable_category_ids';
            expressionAttributeValues[':applicable_category_ids'] = updateData.applicableCategoryIds;
        }
        if (updateData.minimumOrderAmount !== undefined) {
            updateExpression += ', #minimum_order_amount = :minimum_order_amount';
            expressionAttributeNames['#minimum_order_amount'] = 'minimum_order_amount';
            expressionAttributeValues[':minimum_order_amount'] = parseFloat(updateData.minimumOrderAmount);
        }
        if (updateData.validFrom !== undefined) {
            updateExpression += ', #valid_from = :valid_from';
            expressionAttributeNames['#valid_from'] = 'valid_from';
            expressionAttributeValues[':valid_from'] = updateData.validFrom;
        }
        if (updateData.validTo !== undefined) {
            updateExpression += ', #valid_to = :valid_to';
            expressionAttributeNames['#valid_to'] = 'valid_to';
            expressionAttributeValues[':valid_to'] = updateData.validTo;
        }
        if (updateData.usageLimit !== undefined) {
            updateExpression += ', #usage_limit = :usage_limit';
            expressionAttributeNames['#usage_limit'] = 'usage_limit';
            expressionAttributeValues[':usage_limit'] = updateData.usageLimit;
        }
        if (updateData.status !== undefined) {
            updateExpression += ', #status = :status';
            expressionAttributeNames['#status'] = 'status';
            expressionAttributeValues[':status'] = updateData.status;
        }
        if (updateData.conditionalRule !== undefined) {
            updateExpression += ', #conditional_rule = :conditional_rule';
            expressionAttributeNames['#conditional_rule'] = 'conditional_rule';
            expressionAttributeValues[':conditional_rule'] = updateData.conditionalRule;
        }
        if (updateData.conditionalParameters !== undefined) {
            updateExpression += ', #conditional_parameters = :conditional_parameters';
            expressionAttributeNames['#conditional_parameters'] = 'conditional_parameters';
            expressionAttributeValues[':conditional_parameters'] = updateData.conditionalParameters;
        }
        if (updateData.imageUrl !== undefined) {
            updateExpression += ', #imageUrl = :imageUrl';
            expressionAttributeNames['#imageUrl'] = 'imageUrl';
            expressionAttributeValues[':imageUrl'] = updateData.imageUrl;
        }

        const {revision:_revision,sharingLocked:_sharingLocked,sharingCanActivate:_sharingCanActivate,...old}=JSON.parse(existingDiscount.body).discount;
        const fieldMap={minimumOrderAmount:'minimum_order_amount',validFrom:'valid_from',validTo:'valid_to',usageLimit:'usage_limit',applicableItemIds:'applicable_item_ids',applicableCategoryIds:'applicable_category_ids',conditionalRule:'conditional_rule',conditionalParameters:'conditional_parameters'};
        const patch=Object.fromEntries(Object.entries(updateData).filter(([key])=>['title','description','type','value','applicability',...Object.keys(fieldMap),'status','imageUrl','perCustomerLimit','maxDiscountAmount'].includes(key)).map(([key,value])=>[fieldMap[key]||key,value]));
        if(updateData.perCustomerLimit!==undefined)patch.singleUse=updateData.perCustomerLimit===1;
        const next=patchTerms(old,patch,'merchant');
        if(!supported(next)||!discountEngine.validShape(discountEngine.normalizeDiscount(next),Number.MAX_SAFE_INTEGER))return createResponse(400,{success:false,message:'INVALID_DISCOUNT_TERMS'});
        const original=fence(old,'view');
        const params = {
            TableName: DISCOUNTS_TABLE,
            Key: {
                discountId: discountId
            },
            UpdateExpression: updateExpression,
            ConditionExpression: original.ConditionExpression,
            ExpressionAttributeNames: {...original.ExpressionAttributeNames,...expressionAttributeNames},
            ExpressionAttributeValues: {...original.ExpressionAttributeValues,...expressionAttributeValues},
            ReturnValues: 'ALL_NEW'
        };

        const result = await dynamodb.send(new UpdateCommand(params));

        return createResponse(200, {
            success: true,
            message: 'Discount updated successfully',
            discount: {...result.Attributes,revision:revision(result.Attributes)}
        });
    } catch (error) {
        console.error('Error updating discount:', error);
        return discountFailure(error, 'Failed to update discount');
    }
}

// DELETE /discounts/{discountId} - Delete a discount
async function handleDeleteDiscount(dynamodb, businessId, discountId) {
    try {
        // First get the discount to verify ownership
        const getParams = {
            TableName: DISCOUNTS_TABLE,
            Key: {
                discountId: discountId
            }
        };

        const getResult = await dynamodb.send(new GetCommand(getParams));

        if (!getResult.Item) {
            return createResponse(404, { success: false, message: 'Discount not found' });
        }

        // Check if the discount belongs to the business
        if (getResult.Item.businessId !== businessId) {
            return createResponse(403, { success: false, message: 'Access denied to this discount' });
        }

        // Now delete the discount
        const params = {
            TableName: DISCOUNTS_TABLE,
            Key: {
                discountId: discountId
            },
            ConditionExpression: 'businessId = :business',
            ExpressionAttributeValues: { ':business': businessId }
        };

        await dynamodb.send(new DeleteCommand(params));

        return createResponse(200, {
            success: true,
            message: 'Discount deleted successfully'
        });
    } catch (error) {
        console.error('Error deleting discount:', error);
        return discountFailure(error, 'Failed to delete discount');
    }
}

// PATCH /discounts/{discountId}/toggle-status - Toggle discount status
async function handleToggleDiscountStatus(dynamodb, businessId, discountId) {
    try {
        // Get current discount
        const getParams = {
            TableName: DISCOUNTS_TABLE,
            Key: {
                discountId: discountId
            }
        };

        const result = await dynamodb.send(new GetCommand(getParams));
        if (!result.Item) {
            return createResponse(404, { success: false, message: 'Discount not found' });
        }

        // Check if the discount belongs to the business
        if (result.Item.businessId !== businessId) {
            return createResponse(403, { success: false, message: 'Access denied to this discount' });
        }

        const currentStatus = result.Item.status;
        const newStatus = currentStatus === 'active' ? 'paused' : 'active';

        const updateParams = {
            TableName: DISCOUNTS_TABLE,
            Key: {
                discountId: discountId
            },
            UpdateExpression: 'SET #status = :status, #updatedAt = :updatedAt',
            ExpressionAttributeNames: {
                '#status': 'status',
                '#updatedAt': 'updated_at'
            },
            ExpressionAttributeValues: {
                ':status': newStatus,
                ':updatedAt': new Date().toISOString()
            },
            ReturnValues: 'ALL_NEW'
        };

        const updateResult = await dynamodb.send(new UpdateCommand(updateParams));

        return createResponse(200, {
            success: true,
            message: `Discount status changed to ${newStatus}`,
            discount: updateResult.Attributes
        });
    } catch (error) {
        console.error('Error toggling discount status:', error);
        return discountFailure(error, 'Failed to toggle discount status');
    }
}

// Normalize a raw DynamoDB discount item to the camelCase shape the
// validation/calculation logic expects. The table stores snake_case
// (valid_from, minimum_order_amount, usage_limit, ...), so reading the
// camelCase names directly would silently disable those checks.
function normalizeDiscount(d) { return discountEngine.normalizeDiscount(d); }

// POST /discounts/validate-discount - Validate if discount can be applied to an order
async function handleValidateDiscount(dynamodb, businessId, orderData) {
    try {
        const { discountId, orderTotal, items, deliveryFee } = orderData;
        if(hasDiscountCustomizations(items))return createResponse(409,{success:false,valid:false,message:'UNSUPPORTED_DISCOUNT_ITEMS'});

        if (!discountId || orderTotal === undefined || !Array.isArray(items)) {
            return createResponse(400, {
                success: false,
                message: 'Missing required fields: discountId, orderTotal, items'
            });
        }

        // Get discount
        const getParams = {
            TableName: DISCOUNTS_TABLE,
            Key: {
                discountId: discountId
            }
        };

        const result = await dynamodb.send(new GetCommand(getParams));
        if (!result.Item) {
            return createResponse(404, { success: false, message: 'Discount not found' });
        }

        const discount = normalizeDiscount(result.Item);

        // Check if the discount belongs to the business
        if (discount.businessId !== businessId) {
            return createResponse(403, { success: false, message: 'Access denied to this discount' });
        }

        let totalMinor;
        let selected;
        {
            const catalog=await require('../shared/branch-product-pricing').createStagingOrderGoodsPricing({db:dynamodb}).price({branchId:businessId,items:items.map(i=>discountGoodsSelection({...i,id:i.id||i.itemId||i.dishId}))});
            totalMinor=catalog.goodsGross.minorAmount;
            selected=catalog.lines.map(line=>{
                const check=catalog.conditions.find(c=>c.ConditionCheck?.Key?.productId===line.productId)?.ConditionCheck;
                const alias=Object.keys(check?.ExpressionAttributeNames||{}).find(k=>check.ExpressionAttributeNames[k]==='categoryId');
                return {itemId:line.productId,...(line.lineId?{lineId:line.lineId}:{}),quantity:line.quantity,price:line.unitPrice.minorAmount,categoryId:alias?check.ExpressionAttributeValues[':'+alias.slice(1)]:null};
            });
        }
        const validation=discountEngine.validateDiscount(discount,totalMinor);
        if(!validation.valid)return createResponse(400,{success:false,valid:false,message:validation.message});
        const scoped=selected.filter(i=>discount.applicability==='specificItems'?(discount.applicable_item_ids||[]).includes(i.itemId):discount.applicability==='specificCategories'?(discount.applicable_category_ids||[]).includes(i.categoryId):true);
        if(['specificItems','specificCategories'].includes(discount.applicability)&&!scoped.length)return createResponse(400,{success:false,valid:false,message:'NO_ELIGIBLE_ITEMS'});
        const discountAmount=discountEngine.calculateCheckoutDiscountAmount(discount,totalMinor,selected,discountEngine.decimalThousand(deliveryFee||0))/1000;
        if(discountAmount===0)return createResponse(409,{success:false,valid:false,message:'OFFER_NO_SAVINGS'});
        return createResponse(200, {
            success: true,
            valid: true,
            discountAmount,
            previewOnly:true,
            eligibilityRequiresCustomer:true,
            discount
        });
    } catch (error) {
        console.error('Error validating discount:', error);
        if(['INVALID_GOODS_SELECTION','GOODS_UNAVAILABLE','GOODS_PRICING_UNSUPPORTED','GOODS_PRICING_UNAVAILABLE'].includes(error.code))return createResponse(error.code==='GOODS_PRICING_UNAVAILABLE'?503:409,{success:false,valid:false,message:error.code});
        return createResponse(500, { success: false, message: 'Failed to validate discount' });
    }
}

// POST /discounts/apply-discount - Apply discount to an order
async function handleApplyDiscount() {
    // Usage belongs to the atomic customer order transaction. Preview never consumes another use.
    return createResponse(409, {success:false, code:'DISCOUNT_REDEMPTION_REQUIRES_ORDER', message:'يُسجل استخدام الخصم عند تأكيد الطلب.'});
}

// GET /discounts/stats - Get discount statistics
async function handleGetDiscountStats(dynamodb, businessId) {
    try {
        const discounts = await readBusinessDiscounts(dynamodb, businessId);

        const stats = {
            totalDiscounts: discounts.length,
            activeDiscounts: discounts.filter(d => d.status === 'active').length,
            expiredDiscounts: discounts.filter(d => new Date(d.validTo || d.valid_to) <= new Date()).length,
            totalUsage: discounts.reduce((sum, d) => sum + (d.usageCount ?? d.usage_count ?? 0), 0),
            discountsByType: {}
        };

        // Group by type
        const types = ['percentage', 'fixedAmount', 'freeDelivery'];
        types.forEach(type => {
            stats.discountsByType[type] = discounts.filter(d => d.type === type).length;
        });

        return createResponse(200, {
            success: true,
            stats
        });
    } catch (error) {
        console.error('Error getting discount stats:', error);
        return createResponse(error.statusCode || 500, { success: false, message: 'Failed to retrieve discount statistics' });
    }
}

module.exports.handler=merchantHandler(module.exports.handler,{db:DynamoDBDocumentClient.from(new DynamoDBClient({region:"us-east-1"}))});
