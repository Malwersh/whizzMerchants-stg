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

// Environment variables
const DISCOUNTS_TABLE = process.env.DISCOUNTS_TABLE || 'WhizzMerchants_Discounts';
const BUSINESSES_TABLE = process.env.BUSINESSES_TABLE || 'WhizzMerchants_Businesses';
const USER_POOL_ID = process.env.COGNITO_USER_POOL_ID;

exports.handler = async (event) => {
    console.log('Discount Management Handler - Event:', JSON.stringify(event, null, 2));

    // Instantiate AWS clients for this invocation
    const cognito = new CognitoIdentityProviderClient({ region: process.env.AWS_REGION || 'us-east-1' });
    const dynamoDbClient = new DynamoDBClient({ region: process.env.AWS_REGION || 'us-east-1' });
    const dynamodb = DynamoDBDocumentClient.from(dynamoDbClient);

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
        console.log('User info:', JSON.stringify(userInfo, null, 2));
        if (!userInfo) {
            return createResponse(401, { success: false, message: 'Invalid access token' });
        }

        // Get business info for user
        console.log('Getting business info for user...');
        const businessInfo = await getBusinessInfoForUser(dynamodb, userInfo.email);
        console.log('Business info:', JSON.stringify(businessInfo, null, 2));
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

            // If access token fails, try to decode as ID token
            const decoded = decodeJWT(token);
            if (decoded && decoded.email && decoded.sub) {
                console.log('✅ Successfully decoded ID token');
                return {
                    userId: decoded.sub,
                    email: decoded.email,
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
async function getBusinessInfoForUser(dynamodb, email) {
    const params = {
        TableName: BUSINESSES_TABLE,
        IndexName: 'email-index',
        KeyConditionExpression: 'email = :email',
        ExpressionAttributeValues: {
            ':email': email.toLowerCase().trim()
        }
    };

    try {
        const result = await dynamodb.send(new QueryCommand(params));
        if (result.Items && result.Items.length > 0) {
            return result.Items[0];
        }
        return null;
    } catch (error) {
        console.error('Error getting business info for user:', error);
        throw new Error('Failed to retrieve business information.');
    }
}

// GET /discounts - Get all discounts for a business
async function handleGetDiscounts(dynamodb, businessId) {
    try {
        const params = {
            TableName: DISCOUNTS_TABLE,
            FilterExpression: 'businessId = :businessId',
            ExpressionAttributeValues: {
                ':businessId': businessId
            }
        };
        const result = await dynamodb.send(new ScanCommand(params));

        return createResponse(200, {
            success: true,
            discounts: result.Items || [],
            count: result.Items?.length || 0
        });
    } catch (error) {
        console.error('Error getting discounts:', error);
        return createResponse(500, { success: false, message: 'Failed to retrieve discounts', error: error.message });
    }
}

// POST /discounts - Create a new discount
async function handleCreateDiscount(dynamodb, businessId, discountData) {
    try {
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
        const validTypes = ['percentage', 'conditional', 'freeDelivery', 'buyXGetY'];
        if (!validTypes.includes(discountData.type)) {
            return createResponse(400, {
                success: false,
                message: 'Invalid discount type'
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
            usage_limit: discountData.usageLimit || null,
            usage_count: 0,
            status: discountData.status || 'active',
            conditional_rule: discountData.conditionalRule || null,
            conditional_parameters: discountData.conditionalParameters || {},
            created_at: now,
            updated_at: now
        };

        const params = {
            TableName: DISCOUNTS_TABLE,
            Item: discount
        };

        await dynamodb.send(new PutCommand(params));

        return createResponse(201, {
            success: true,
            message: 'Discount created successfully',
            discount
        });
    } catch (error) {
        console.error('Error creating discount:', error);
        return createResponse(500, { success: false, message: 'Failed to create discount' });
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
            discount: result.Item
        });
    } catch (error) {
        console.error('Error getting discount:', error);
        return createResponse(500, { success: false, message: 'Failed to retrieve discount' });
    }
}

// PUT /discounts/{discountId} - Update a discount
async function handleUpdateDiscount(dynamodb, businessId, discountId, updateData) {
    try {
        // First, verify the discount exists and belongs to the user's business
        const existingDiscount = await handleGetDiscount(dynamodb, businessId, discountId);
        if (existingDiscount.statusCode !== 200) {
            return existingDiscount;
        }

        let updateExpression = 'SET updated_at = :timestamp';
        const expressionAttributeValues = {
            ':timestamp': new Date().toISOString()
        };

        if (updateData.title !== undefined) {
            updateExpression += ', title = :title';
            expressionAttributeValues[':title'] = updateData.title;
        }
        if (updateData.description !== undefined) {
            updateExpression += ', description = :description';
            expressionAttributeValues[':description'] = updateData.description;
        }
        if (updateData.value !== undefined) {
            updateExpression += ', value = :value';
            expressionAttributeValues[':value'] = parseFloat(updateData.value);
        }
        if (updateData.type !== undefined) {
            updateExpression += ', type = :type';
            expressionAttributeValues[':type'] = updateData.type;
        }
        if (updateData.applicability !== undefined) {
            updateExpression += ', applicability = :applicability';
            expressionAttributeValues[':applicability'] = updateData.applicability;
        }
        if (updateData.applicableItemIds !== undefined) {
            updateExpression += ', applicable_item_ids = :applicable_item_ids';
            expressionAttributeValues[':applicable_item_ids'] = updateData.applicableItemIds;
        }
        if (updateData.applicableCategoryIds !== undefined) {
            updateExpression += ', applicable_category_ids = :applicable_category_ids';
            expressionAttributeValues[':applicable_category_ids'] = updateData.applicableCategoryIds;
        }
        if (updateData.minimumOrderAmount !== undefined) {
            updateExpression += ', minimum_order_amount = :minimum_order_amount';
            expressionAttributeValues[':minimum_order_amount'] = parseFloat(updateData.minimumOrderAmount);
        }
        if (updateData.validFrom !== undefined) {
            updateExpression += ', valid_from = :valid_from';
            expressionAttributeValues[':valid_from'] = updateData.validFrom;
        }
        if (updateData.validTo !== undefined) {
            updateExpression += ', valid_to = :valid_to';
            expressionAttributeValues[':valid_to'] = updateData.validTo;
        }
        if (updateData.usageLimit !== undefined) {
            updateExpression += ', usage_limit = :usage_limit';
            expressionAttributeValues[':usage_limit'] = updateData.usageLimit;
        }
        if (updateData.status !== undefined) {
            updateExpression += ', status = :status';
            expressionAttributeValues[':status'] = updateData.status;
        }
        if (updateData.conditionalRule !== undefined) {
            updateExpression += ', conditional_rule = :conditional_rule';
            expressionAttributeValues[':conditional_rule'] = updateData.conditionalRule;
        }
        if (updateData.conditionalParameters !== undefined) {
            updateExpression += ', conditional_parameters = :conditional_parameters';
            expressionAttributeValues[':conditional_parameters'] = updateData.conditionalParameters;
        }

        // Always update the updatedAt timestamp
        updateExpression += ', updated_at = :updatedAt';
        expressionAttributeValues[':updatedAt'] = new Date().toISOString();

        const params = {
            TableName: DISCOUNTS_TABLE,
            Key: {
                discountId: discountId
            },
            UpdateExpression: updateExpression,
            ExpressionAttributeValues: expressionAttributeValues,
            ReturnValues: 'ALL_NEW'
        };

        const result = await dynamodb.send(new UpdateCommand(params));

        return createResponse(200, {
            success: true,
            message: 'Discount updated successfully',
            discount: result.Attributes
        });
    } catch (error) {
        console.error('Error updating discount:', error);
        return createResponse(500, { success: false, message: 'Failed to update discount' });
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
            ReturnValues: 'ALL_OLD'
        };

        const result = await dynamodb.send(new DeleteCommand(params));

        if (!result.Attributes) {
            return createResponse(404, { success: false, message: 'Discount not found' });
        }

        return createResponse(200, {
            success: true,
            message: 'Discount deleted successfully'
        });
    } catch (error) {
        console.error('Error deleting discount:', error);
        return createResponse(500, { success: false, message: 'Failed to delete discount' });
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
                '#updatedAt': 'updatedAt'
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
        return createResponse(500, { success: false, message: 'Failed to toggle discount status' });
    }
}

// POST /discounts/validate-discount - Validate if discount can be applied to an order
async function handleValidateDiscount(dynamodb, businessId, orderData) {
    try {
        const { discountId, orderTotal, items } = orderData;

        if (!discountId || orderTotal === undefined || !items) {
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

        const discount = result.Item;

        // Check if the discount belongs to the business
        if (discount.businessId !== businessId) {
            return createResponse(403, { success: false, message: 'Access denied to this discount' });
        }

        // Validate discount is active
        if (discount.status !== 'active') {
            return createResponse(400, {
                success: false,
                message: 'Discount is not active',
                valid: false
            });
        }

        // Validate date range
        const now = new Date();
        const validFrom = new Date(discount.validFrom);
        const validTo = new Date(discount.validTo);

        if (now < validFrom || now > validTo) {
            return createResponse(400, {
                success: false,
                message: 'Discount is not valid for current date',
                valid: false
            });
        }

        // Validate minimum order amount
        if (orderTotal < discount.minimumOrderAmount) {
            return createResponse(400, {
                success: false,
                message: `Order must be at least $${discount.minimumOrderAmount}`,
                valid: false
            });
        }

        // Validate usage limit
        if (discount.usageLimit && discount.usageCount >= discount.usageLimit) {
            return createResponse(400, {
                success: false,
                message: 'Discount usage limit reached',
                valid: false
            });
        }

        // Calculate discount amount
        const discountAmount = calculateDiscountAmount(discount, orderTotal, items);

        return createResponse(200, {
            success: true,
            valid: true,
            discountAmount,
            discount
        });
    } catch (error) {
        console.error('Error validating discount:', error);
        return createResponse(500, { success: false, message: 'Failed to validate discount' });
    }
}

// POST /discounts/apply-discount - Apply discount to an order
async function handleApplyDiscount(dynamodb, businessId, orderData) {
    try {
        const { discountId, orderTotal, items } = orderData;

        // First validate the discount
        const validation = await handleValidateDiscount(dynamodb, businessId, orderData);
        if (validation.statusCode !== 200) {
            return validation;
        }

        const validationBody = JSON.parse(validation.body);
        const discount = validationBody.discount;
        const discountAmount = validationBody.discountAmount;

        // Increment usage count
        const updateParams = {
            TableName: DISCOUNTS_TABLE,
            Key: {
                discountId: discountId
            },
            UpdateExpression: 'SET #usageCount = #usageCount + :inc, #updatedAt = :updatedAt',
            ExpressionAttributeNames: {
                '#usageCount': 'usageCount',
                '#updatedAt': 'updatedAt'
            },
            ExpressionAttributeValues: {
                ':inc': 1,
                ':updatedAt': new Date().toISOString()
            }
        };

        await dynamodb.send(new UpdateCommand(updateParams));

        return createResponse(200, {
            success: true,
            message: 'Discount applied successfully',
            discountAmount,
            finalTotal: orderTotal - discountAmount,
            discount
        });
    } catch (error) {
        console.error('Error applying discount:', error);
        return createResponse(500, { success: false, message: 'Failed to apply discount' });
    }
}

// GET /discounts/stats - Get discount statistics
async function handleGetDiscountStats(dynamodb, businessId) {
    try {
        const params = {
            TableName: DISCOUNTS_TABLE,
            IndexName: 'BusinessIdIndex',
            KeyConditionExpression: 'businessId = :businessId',
            ExpressionAttributeValues: {
                ':businessId': businessId
            }
        };

        const result = await dynamodb.send(new QueryCommand(params));
        const discounts = result.Items || [];

        const stats = {
            totalDiscounts: discounts.length,
            activeDiscounts: discounts.filter(d => d.status === 'active').length,
            expiredDiscounts: discounts.filter(d => new Date(d.validTo) < new Date()).length,
            totalUsage: discounts.reduce((sum, d) => sum + (d.usageCount || 0), 0),
            discountsByType: {}
        };

        // Group by type
        const types = ['percentage', 'conditional', 'freeDelivery', 'buyXGetY'];
        types.forEach(type => {
            stats.discountsByType[type] = discounts.filter(d => d.type === type).length;
        });

        return createResponse(200, {
            success: true,
            stats
        });
    } catch (error) {
        console.error('Error getting discount stats:', error);
        return createResponse(500, { success: false, message: 'Failed to retrieve discount statistics' });
    }
}

// Helper function to calculate discount amount
function calculateDiscountAmount(discount, orderTotal, items) {
    let discountableAmount = 0;

    // Determine discountable amount based on applicability
    switch (discount.applicability) {
        case 'allItems':
            discountableAmount = orderTotal;
            break;
        case 'specificItems':
            discountableAmount = items
                .filter(item => discount.applicable_item_ids.includes(item.dishId || item.id))
                .reduce((sum, item) => sum + (item.price * item.quantity), 0);
            break;
        case 'specificCategories':
            discountableAmount = items
                .filter(item => discount.applicable_category_ids.includes(item.categoryId))
                .reduce((sum, item) => sum + (item.price * item.quantity), 0);
            break;
        case 'minimumOrder':
            discountableAmount = orderTotal;
            break;
        default:
            discountableAmount = orderTotal;
    }

    // Calculate discount based on type
    switch (discount.type) {
        case 'percentage':
            return discountableAmount * (discount.value / 100);
        case 'buyXGetY':
        case 'conditional':
            // For Buy X Get Y, implement specific logic based on items
            return calculateBuyXGetYDiscount(discount, items);
        case 'freeDelivery':
            return 0; // This would be handled separately for delivery charges
        default:
            return 0; // Default to 0 for unknown types
    }
}

// Helper function for Buy X Get Y discount calculation
function calculateBuyXGetYDiscount(discount, items) {
    const params = discount.conditionalParameters || {};
    const buyItemId = params.buyItemId;
    const buyQuantity = params.buyQuantity;
    const getItemId = params.getItemId;
    const getQuantity = params.getQuantity;

    if (!buyItemId || !buyQuantity || !getItemId || !getQuantity) {
        return 0;
    }

    // Find buy item in order
    const buyItem = items.find(item => (item.dishId || item.id) === buyItemId);
    if (!buyItem || buyItem.quantity < buyQuantity) {
        return 0;
    }

    // Find get item in order
    const getItem = items.find(item => (item.dishId || item.id) === getItemId);
    if (!getItem) {
        return 0;
    }

    // Calculate how many free items customer gets
    const setsEligible = Math.floor(buyItem.quantity / buyQuantity);
    const freeItems = Math.min(setsEligible * getQuantity, getItem.quantity);

    // Calculate discount amount
    if (discount.value === 0) {
        // Free items
        return freeItems * getItem.price;
    } else {
        // Percentage discount on get items
        return freeItems * getItem.price * (discount.value / 100);
    }
}
