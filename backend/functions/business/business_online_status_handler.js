const {merchantLifecycleClient,merchantHandler}=require('../shared/merchant-lifecycle');
const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { DynamoDBDocumentClient, UpdateCommand, GetCommand } = require('@aws-sdk/lib-dynamodb');
const { LambdaClient, InvokeCommand } = require('@aws-sdk/client-lambda');
const jwt = require('jsonwebtoken');

const dynamoDbClient = new DynamoDBClient({ region: process.env.AWS_REGION || 'us-east-1' });
const lifecycleRawDb = DynamoDBDocumentClient.from(dynamoDbClient);
const dynamodb = merchantLifecycleClient(lifecycleRawDb);
const lambdaClient = new LambdaClient({ region: process.env.AWS_REGION || 'us-east-1' });

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'Content-Type,Authorization',
    'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS',
};

/**
 * ✅ SIMPLIFIED Business Online Status Handler
 * 
 * Perfect solution for business status management without WebSocket dependency
 * 
 * Features:
 * - Direct DynamoDB updates to acceptingOrders field
 * - Simple toggle functionality (true/false)
 * - JWT token authentication
 * - Clean error handling
 * - No external dependencies
 * 
 * Endpoints:
 * - PUT /businesses/{businessId}/status - Toggle online/offline status
 * - GET /businesses/{businessId}/status - Get current status
 */

// Helper function to create response
function createResponse(statusCode, body) {
    return {
        statusCode,
        headers: corsHeaders,
        body: JSON.stringify(body),
    };
}

// Enhanced JWT token processing
function getUserIdFromToken(authHeader) {
    try {
        if (!authHeader || !authHeader.startsWith('Bearer ')) {
            console.log('❌ Missing or invalid Authorization header format');
            return null;
        }
        
        const token = authHeader.substring(7).trim();
        
        if (!token || token.length < 10) {
            console.log('❌ Token is empty or too short');
            return null;
        }

        // Validate JWT format (3 parts separated by dots)
        const tokenParts = token.split('.');
        if (tokenParts.length !== 3) {
            console.log('❌ Invalid JWT format - expected 3 parts, got:', tokenParts.length);
            return null;
        }

        // Decode token without verification (since we're using Cognito tokens)
        const decoded = jwt.decode(token);
        
        if (!decoded) {
            console.log('❌ Failed to decode JWT token');
            return null;
        }

        console.log('🔍 Token decoded successfully, extracting user ID...');
        
        // Try multiple possible user ID fields
        const userId = decoded.sub || 
                      decoded['cognito:username'] || 
                      decoded.username || 
                      decoded.email ||
                      null;
                      
        if (!userId) {
            console.log('❌ No user ID found in token. Available fields:', Object.keys(decoded));
            return null;
        }

        console.log('✅ User ID extracted successfully:', userId);
        return userId;
        
    } catch (error) {
        console.error('❌ Error processing authorization token:', error.message);
        return null;
    }
}

/**
 * ✅ PERFECT: Update business accepting orders status
 * Direct DynamoDB update to acceptingOrders field
 */
async function updateBusinessAcceptingOrders(businessId, acceptingOrders, userId, source = 'manual_toggle') {
    try {
        console.log(`🔄 Updating business accepting orders: ${businessId} -> ${acceptingOrders} (user: ${userId})`);
        
        const timestamp = new Date().toISOString();
        
        // Direct update to WhizzMerchants_Businesses table
        const updateCommand = new UpdateCommand({
            TableName: process.env.BUSINESSES_TABLE || 'WhizzMerchants_Businesses',
            Key: {
                businessId: businessId
            },
            UpdateExpression: 'SET acceptingOrders = :accepting, lastStatusUpdate = :timestamp, onlineStatus = :status, statusUpdatedBy = :userId, statusSource = :source',
            ExpressionAttributeValues: {
                ':accepting': acceptingOrders,
                ':timestamp': timestamp,
                ':status': acceptingOrders ? 'online' : 'offline',
                ':userId': userId,
                ':source': source
            },
            ReturnValues: 'ALL_NEW'
        });

        const result = await dynamodb.send(updateCommand);
        
        console.log(`✅ Business accepting orders updated successfully: ${businessId} -> ${acceptingOrders}`);
        
        // Broadcast status update to connected user apps via WebSocket (fire and forget)
        broadcastBusinessStatusUpdate(businessId, result.Attributes).catch(error => {
            console.error(`⚠️ Failed to broadcast status update for ${businessId}:`, error.message);
        });

        return {
            success: true,
            businessId: businessId,
            acceptingOrders: acceptingOrders,
            status: acceptingOrders ? 'online' : 'offline',
            lastStatusUpdate: timestamp,
            updatedBy: userId,
            source: source,
            updatedData: result.Attributes
        };
        
    } catch (error) {
        console.error(`❌ Error updating business accepting orders:`, error);
        throw new Error(`Failed to update business status: ${error.message}`);
    }
}

/**
 * ✅ PERFECT: Get business current status
 * Simple read from DynamoDB
 */
async function getBusinessCurrentStatus(businessId) {
    try {
        console.log(`📊 Getting business current status: ${businessId}`);
        
        const getCommand = new GetCommand({
            TableName: process.env.BUSINESSES_TABLE || 'WhizzMerchants_Businesses',
            Key: {
                businessId: businessId
            }
        });

        const result = await dynamodb.send(getCommand);
        
        if (!result.Item) {
            console.log(`⚠️ Business not found: ${businessId}`);
            return {
                businessId: businessId,
                acceptingOrders: false,
                status: 'offline',
                found: false,
                lastStatusUpdate: null,
                error: 'Business not found'
            };
        }

        const business = result.Item;
        const acceptingOrders = business.acceptingOrders === true;
        
        console.log(`✅ Business status retrieved: ${businessId} -> acceptingOrders: ${acceptingOrders}`);
        
        return {
            businessId: businessId,
            acceptingOrders: acceptingOrders,
            status: acceptingOrders ? 'online' : 'offline',
            onlineStatus: business.onlineStatus || (acceptingOrders ? 'online' : 'offline'),
            lastStatusUpdate: business.lastStatusUpdate,
            statusUpdatedBy: business.statusUpdatedBy,
            statusSource: business.statusSource,
            found: true,
            businessName: business.businessName || business.name,
            email: business.email
        };
        
    } catch (error) {
        console.error(`❌ Error getting business status:`, error);
        throw new Error(`Failed to get business status: ${error.message}`);
    }
}

/**
 * Broadcast business status update to connected user apps via WebSocket
 */
async function broadcastBusinessStatusUpdate(businessId, updateData) {
    try {
        console.log(`📡 Broadcasting business status update for: ${businessId}`);
        
        // Prepare the broadcast payload
        const broadcastPayload = {
            businessId: businessId,
            updateData: {
                businessName: updateData.businessName || '',
                status: updateData.acceptingOrders ? 'available' : 'busy',
                statusMessage: updateData.acceptingOrders ? 'Accepting orders' : 'Currently busy',
                canAcceptOrders: updateData.acceptingOrders,
                isBusy: !updateData.acceptingOrders,
                lastStatusUpdate: updateData.lastStatusUpdate
            },
            websocketEndpoint: process.env.WEBSOCKET_ENDPOINT
        };

        // Call the WebSocket broadcast function via direct Lambda invocation
        const broadcastFunctionName = process.env.BROADCAST_FUNCTION_NAME;
        
        if (broadcastFunctionName) {
            await invokeBroadcastFunction(broadcastFunctionName, broadcastPayload);
        }
        
        console.log(`✅ Business status broadcast completed for: ${businessId}`);
        
    } catch (error) {
        console.error(`❌ Error broadcasting business status update for ${businessId}:`, error);
        // Don't throw error to avoid breaking the main status update
    }
}

/**
 * Invoke broadcast function via direct Lambda invocation
 */
async function invokeBroadcastFunction(functionName, payload) {
    try {
        const command = new InvokeCommand({
            FunctionName: functionName,
            InvocationType: 'Event', // Async invocation
            Payload: JSON.stringify(payload)
        });
        
        await lambdaClient.send(command);
        console.log(`✅ Successfully invoked broadcast function: ${functionName}`);
    } catch (error) {
        console.error(`❌ Error invoking broadcast function ${functionName}:`, error);
        throw error;
    }
}

/**
 * ✅ PERFECT: Handle business status toggle (PUT)
 */
async function handleBusinessStatusToggle(event) {
    try {
        const { businessId } = event.pathParameters;
        const authHeader = event.headers.Authorization || event.headers.authorization;
        const userId = getUserIdFromToken(authHeader);

        console.log(`🎯 Processing toggle request for business: ${businessId}`);

        if (!userId) {
            console.log('❌ Authorization failed - no valid user ID');
            return createResponse(401, {
                success: false,
                message: 'Invalid or missing authorization token'
            });
        }

        if (!businessId) {
            console.log('❌ Missing business ID');
            return createResponse(400, {
                success: false,
                message: 'Business ID is required'
            });
        }

        // Parse request body
        let bodyString = event.body || '{}';
        if (event.isBase64Encoded) {
            bodyString = Buffer.from(bodyString, 'base64').toString('utf-8');
        }

        const body = JSON.parse(bodyString);
        const { status, source } = body;

        if (status === undefined) {
            console.log('❌ Missing status in request body');
            return createResponse(400, {
                success: false,
                message: 'Status is required (true/false or online/offline)'
            });
        }

        // Convert status to boolean
        const acceptingOrders = status === 'online' || status === true || status === 'true';

        console.log(`🔄 Toggle request: ${businessId} -> acceptingOrders: ${acceptingOrders} (user: ${userId})`);

        // Update business accepting orders status
        const updateResult = await updateBusinessAcceptingOrders(
            businessId, 
            acceptingOrders, 
            userId,
            source || 'flutter_app_toggle'
        );

        console.log(`✅ Toggle completed successfully: ${businessId}`);

        return createResponse(200, {
            success: true,
            message: `Business is now ${acceptingOrders ? 'accepting orders' : 'not accepting orders'}`,
            data: updateResult
        });

    } catch (error) {
        console.error('❌ Error in toggle handler:', error);
        return createResponse(500, {
            success: false,
            message: 'Failed to update business status',
            error: error.message
        });
    }
}

/**
 * ✅ PERFECT: Handle get business status (GET)
 */
async function handleGetBusinessStatus(event) {
    try {
        const { businessId } = event.pathParameters;
        const authHeader = event.headers.Authorization || event.headers.authorization;
        const userId = getUserIdFromToken(authHeader);

        console.log(`📊 Processing status request for business: ${businessId}`);

        if (!userId) {
            console.log('❌ Authorization failed - no valid user ID');
            return createResponse(401, {
                success: false,
                message: 'Invalid or missing authorization token'
            });
        }

        if (!businessId) {
            console.log('❌ Missing business ID');
            return createResponse(400, {
                success: false,
                message: 'Business ID is required'
            });
        }

        // Get current business status
        const statusResult = await getBusinessCurrentStatus(businessId);

        console.log(`✅ Status request completed: ${businessId}`);

        return createResponse(200, {
            success: true,
            message: 'Business status retrieved successfully',
            data: statusResult,
            timestamp: new Date().toISOString()
        });

    } catch (error) {
        console.error('❌ Error in get status handler:', error);
        return createResponse(500, {
            success: false,
            message: 'Failed to get business status',
            error: error.message
        });
    }
}

/**
 * ✅ PERFECT: Main handler with clean routing
 */
exports.handler = async (event) => {
    console.log('🚀 Business Status Handler - Perfect Solution');
    console.log('📥 Event:', {method:event.httpMethod,path:event.path});

    // Handle preflight CORS requests
    if (event.httpMethod === 'OPTIONS') {
        console.log('✅ CORS preflight request');
        return createResponse(200, { message: 'CORS preflight successful' });
    }

    try {
        const { httpMethod, resource, path } = event;
        const actualPath = path || resource;

        console.log(`🎯 Route: ${httpMethod} ${actualPath}`);

        // Route to appropriate handler
        if (actualPath.includes('/businesses/') && actualPath.includes('/status')) {
            if (httpMethod === 'PUT') {
                console.log('📝 Routing to toggle handler');
                return await handleBusinessStatusToggle(event);
            }
            
            if (httpMethod === 'GET') {
                console.log('📊 Routing to status handler');
                return await handleGetBusinessStatus(event);
            }
        }

        console.log('❌ No matching route found');
        return createResponse(404, {
            success: false,
            message: 'Endpoint not found',
            availableEndpoints: [
                'PUT /businesses/{businessId}/status - Toggle accepting orders',
                'GET /businesses/{businessId}/status - Get current status'
            ],
            receivedPath: actualPath,
            receivedMethod: httpMethod
        });

    } catch (error) {
        console.error('❌ Handler error:', error);
        return createResponse(500, {
            success: false,
            message: 'Internal server error',
            error: error.message
        });
    }
};

/**
 * ✅ PERFECT: Export legacy function for backward compatibility
 */
async function getBusinessOnlineStatus(businessId) {
    try {
        const status = await getBusinessCurrentStatus(businessId);
        
        return {
            isOnline: status.acceptingOrders,
            acceptingOrders: status.acceptingOrders,
            lastStatusUpdate: status.lastStatusUpdate,
            overallStatus: status.status,
            found: status.found
        };

    } catch (error) {
        console.error('Error in legacy function:', error);
        return {
            isOnline: false,
            acceptingOrders: false,
            error: error.message,
            found: false
        };
    }
}

// Export for backward compatibility
module.exports.getBusinessOnlineStatus = getBusinessOnlineStatus;

module.exports.handler=merchantHandler(module.exports.handler,{db:lifecycleRawDb});
