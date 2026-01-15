/**
 * Updated Business WebSocket Handler
 * Updated to use Universal WebSocket Manager for consistent connection management
 */

const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { DynamoDBDocumentClient, PutCommand } = require('@aws-sdk/lib-dynamodb');
const { UniversalWebSocketManager } = require('./universal_websocket_manager');

const dynamoDbClient = new DynamoDBClient({ region: process.env.AWS_REGION || 'us-east-1' });
const dynamodb = DynamoDBDocumentClient.from(dynamoDbClient);

// Initialize Universal WebSocket Manager
const universalManager = new UniversalWebSocketManager();

/**
 * Handle WebSocket connection establishment for Business App
 */
async function handleConnect(event) {
    try {
        const connectionId = event.requestContext.connectionId;
        const queryParams = event.queryStringParameters || {};
        
        const {
            merchantId,
            businessId,
            userId,
            entityType = 'business', // Default to business for merchant app
            deviceId,
            platform,
            appVersion,
            token
        } = queryParams;

        console.log(`🏪 Business WebSocket connection request: ${connectionId}`);
        console.log('📋 Connection params:', queryParams);

        // For merchants, use merchantId or businessId as the identifier
        const effectiveMerchantId = merchantId || businessId;
        const effectiveUserId = userId || effectiveMerchantId;

        if (!effectiveMerchantId && !effectiveUserId) {
            console.log('❌ Missing required parameters:', { merchantId, businessId, userId });
            return { statusCode: 400, body: 'Missing merchantId, businessId, or userId parameter' };
        }

        // Enhance query parameters for business connections
        const enhancedEvent = {
            ...event,
            queryStringParameters: {
                ...queryParams,
                // Set defaults for business connections
                entityType: 'business',
                userType: 'business',
                // Use businessId as userId for proper identification
                userId: effectiveUserId,
                businessId: effectiveMerchantId,
                deviceId: deviceId || `business_${effectiveMerchantId}_${Date.now()}`,
                platform: platform || 'unknown',
                appVersion: appVersion || '1.0.0',
                token: token || null
            }
        };

        // Store connection in merchant endpoints table (backward compatibility)
        if (effectiveMerchantId && process.env.MERCHANT_ENDPOINTS_TABLE) {
            try {
                const currentTime = new Date().toISOString();
                const merchantParams = {
                    TableName: process.env.MERCHANT_ENDPOINTS_TABLE,
                    Item: {
                        merchantId: effectiveMerchantId,
                        endpointType: 'websocket',
                        connectionId,
                        isActive: true,
                        connectedAt: currentTime,
                        updatedAt: currentTime
                    }
                };
                await dynamodb.send(new PutCommand(merchantParams));
                console.log(`✅ Stored connection in merchant endpoints table for merchant: ${effectiveMerchantId}`);
            } catch (error) {
                console.warn('⚠️ Could not store in merchant endpoints table (table may not exist):', error.message);
            }
        }

        // Use Universal Manager for primary connection management
        const result = await universalManager.handleConnect(connectionId, enhancedEvent);
        
        console.log(`✅ Business connection handled by universal manager: ${connectionId}`);
        
        // Add specific business connection logging
        if (result.statusCode === 200) {
            console.log(`🎯 Business connection successful:`, {
                connectionId: connectionId,
                businessId: effectiveMerchantId,
                userId: effectiveUserId,
                entityType: 'business',
                platform: platform
            });
        }
        
        return result;

    } catch (error) {
        console.error('❌ Error in business WebSocket connect:', error);
        return { 
            statusCode: 500, 
            body: JSON.stringify({
                error: 'Failed to connect',
                message: error.message
            })
        };
    }
}

/**
 * Handle WebSocket disconnection for Business App
 */
async function handleDisconnect(event) {
    try {
        const connectionId = event.requestContext.connectionId;
        
        console.log(`🔌 Business WebSocket disconnection request: ${connectionId}`);
        
        // Use Universal Manager for disconnection
        const result = await universalManager.handleDisconnect(connectionId);
        
        console.log(`✅ Business disconnection handled by universal manager: ${connectionId}`);
        
        return result;
        
    } catch (error) {
        console.error('❌ Error in business WebSocket disconnect:', error);
        return { 
            statusCode: 500, 
            body: JSON.stringify({
                error: 'Failed to disconnect',
                message: error.message
            })
        };
    }
}

/**
 * Handle default WebSocket messages for Business App
 */
async function handleDefault(event) {
    try {
        const connectionId = event.requestContext.connectionId;
        const body = JSON.parse(event.body || '{}');
        
        console.log(`📨 Business WebSocket message:`, {
            connectionId,
            action: body.action,
            type: body.type
        });
        
        // Handle different message types
        switch (body.action || body.type) {
            case 'ping':
            case 'heartbeat':
                // Update heartbeat
                await universalManager.updateHeartbeat(connectionId);
                return { statusCode: 200, body: 'Pong' };
                
            case 'status_update':
                // Handle business status updates
                return await handleBusinessStatusUpdate(connectionId, body);
                
            default:
                console.log(`⚠️ Unknown message type: ${body.action || body.type}`);
                return { statusCode: 400, body: 'Unknown message type' };
        }
        
    } catch (error) {
        console.error('❌ Error handling business WebSocket message:', error);
        return { 
            statusCode: 500, 
            body: JSON.stringify({
                error: 'Failed to process message',
                message: error.message
            })
        };
    }
}

/**
 * Handle business status updates
 */
async function handleBusinessStatusUpdate(connectionId, body) {
    try {
        const { businessId, status, data } = body;
        
        if (!businessId || !status) {
            return { statusCode: 400, body: 'Missing businessId or status' };
        }
        
        // Update business status and broadcast to relevant connections
        console.log(`🏪 Business status update: ${businessId} -> ${status}`);
        
        // Here you can add business-specific logic for status updates
        // For example, updating business online/offline status
        
        return { statusCode: 200, body: 'Status updated' };
        
    } catch (error) {
        console.error('❌ Error handling business status update:', error);
        return { statusCode: 500, body: 'Failed to update status' };
    }
}

/**
 * Main handler function for Business WebSocket events
 */
const handler = async (event) => {
    try {
        const { routeKey } = event.requestContext;
        
        console.log(`🏪 Business WebSocket event: ${routeKey}`);
        
        switch (routeKey) {
            case '$connect':
                return await handleConnect(event);
            case '$disconnect':
                return await handleDisconnect(event);
            case '$default':
                return await handleDefault(event);
            default:
                console.log(`⚠️ Unknown route: ${routeKey}`);
                return { statusCode: 400, body: `Unknown route: ${routeKey}` };
        }
        
    } catch (error) {
        console.error('❌ Error in business WebSocket handler:', error);
        return { 
            statusCode: 500, 
            body: JSON.stringify({
                error: 'Internal server error',
                message: error.message
            })
        };
    }
};

module.exports = {
    handler,
    handleConnect,
    handleDisconnect,
    handleDefault
};