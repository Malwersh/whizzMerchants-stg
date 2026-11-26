const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { DynamoDBDocumentClient, PutCommand, UpdateCommand, DeleteCommand, GetCommand, QueryCommand, ScanCommand } = require('@aws-sdk/lib-dynamodb');
const { ApiGatewayManagementApiClient, PostToConnectionCommand } = require('@aws-sdk/client-apigatewaymanagementapi');
const { WebSocketConnectionsAdapter } = require('./websocket_table_adapter');

const dynamoDbClient = new DynamoDBClient({ region: process.env.AWS_REGION || 'us-east-1' });
const dynamodb = DynamoDBDocumentClient.from(dynamoDbClient);

const WEBSOCKET_CONNECTIONS_TABLE = process.env.WEBSOCKET_CONNECTIONS_TABLE;
const WEBSOCKET_SUBSCRIPTIONS_TABLE = process.env.WEBSOCKET_SUBSCRIPTIONS_TABLE;
if (!WEBSOCKET_CONNECTIONS_TABLE) {
    throw new Error('Missing required env var: WEBSOCKET_CONNECTIONS_TABLE');
}
if (!WEBSOCKET_SUBSCRIPTIONS_TABLE) {
    throw new Error('Missing required env var: WEBSOCKET_SUBSCRIPTIONS_TABLE');
}

// Initialize WebSocket connections adapter for schema compatibility
const connectionsAdapter = new WebSocketConnectionsAdapter(
    WEBSOCKET_CONNECTIONS_TABLE
);

const apiGatewayManagementApi = new ApiGatewayManagementApiClient({
    region: process.env.AWS_REGION || 'us-east-1',
    endpoint: process.env.WEBSOCKET_ENDPOINT
});

/**
 * Professional WebSocket Management System
 * 
 * Connection Types:
 * 1. REAL: CONNECTION#${connectionId} - Actual WebSocket channels for real-time messaging
 * 2. VIRTUAL: CONNECTION#VIRTUAL#${businessId}#${userId} - Login tracking for business presence
 * 
 * Features:
 * - Dual connection management (real WebSocket + login tracking)
 * - Professional stale connection cleanup
 * - Online/offline status integration
 * - Connection monitoring and heartbeat management
 * - Comprehensive error handling and logging
 */

/**
 * Handle WebSocket connection establishment
 */
async function handleConnect(event) {
    try {
        const connectionId = event.requestContext.connectionId;
        const merchantId = event.queryStringParameters?.merchantId;
        const businessId = event.queryStringParameters?.businessId;
        const userId = event.queryStringParameters?.userId;
        const userType = event.queryStringParameters?.userType;
        
        // FIXED: Properly handle entityType mapping between old and new apps
        let entityType = event.queryStringParameters?.entityType;
        
        // Map business/merchant entityTypes correctly
        if (entityType === 'business' || userType === 'merchant') {
            entityType = 'business';
        } else if (entityType === 'customer' || userType === 'customer') {
            entityType = 'customer';
        } else {
            // Default fallback based on presence of businessId
            entityType = (businessId || merchantId) ? 'business' : 'customer';
        }

        // Diagnostic: Authorization header presence/format (do not log token)
        const authHeader = event.headers?.Authorization || event.headers?.authorization;
        const hasBearer = typeof authHeader === 'string' && authHeader.startsWith('Bearer ');
        console.log('🔐 $connect auth header:', {
            present: !!authHeader,
            format: hasBearer ? 'Bearer' : (authHeader ? 'raw' : 'none')
        });

        // For merchants, use merchantId or businessId as the identifier
        const effectiveMerchantId = merchantId || businessId;
        const effectiveUserId = userId || effectiveMerchantId;

        if (!effectiveMerchantId && !effectiveUserId) {
            console.log('❌ Missing required parameters:', { merchantId, businessId, userId });
            return { statusCode: 400, body: 'Missing merchantId, businessId, or userId parameter' };
        }

        const currentTime = new Date().toISOString();
        const ttl = Math.floor(Date.now() / 1000) + 3600; // 1 hour TTL

        console.log(`🔌 WebSocket connection attempt:`, {
            connectionId,
            merchantId,
            businessId,
            userId,
            userType,
            entityType: `${event.queryStringParameters?.entityType} → ${entityType}`,
            effectiveMerchantId,
            effectiveUserId
        });

        // Store connection in merchant endpoints table (backward compatibility)
        if (effectiveMerchantId && process.env.MERCHANT_ENDPOINTS_TABLE) {
            try {
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

        // Store connection in primary websocket connections table using adapter
        await connectionsAdapter.createConnection({
            connectionId,
            entityType,
            userId: effectiveUserId,
            businessId: effectiveMerchantId,
            connectedAt: currentTime,
            ttl,
            isActive: true,
            connectionType: 'REAL',
            lastHeartbeat: currentTime
        });
        console.log(`✅ Stored real WebSocket connection in unified tracking table`);

        // Dedupe: keep only the newest REAL connection per business/user
        if (effectiveMerchantId) {
            try {
                const all = await getActiveConnectionsForBusiness(effectiveMerchantId);
                // Filter by same user and not the current connectionId
                const sameUser = all.filter(c => c.userId === effectiveUserId);
                if (sameUser.length > 1) {
                    // Sort by connectedAt desc and keep first
                    sameUser.sort((a, b) => (b.connectedAt || '').localeCompare(a.connectedAt || ''));
                    const keep = sameUser[0];
                    const toDelete = sameUser.filter(c => c.connectionId !== keep.connectionId);
                    if (toDelete.length > 0) {
                        await connectionsAdapter.deleteConnections(toDelete);
                        console.log(`🧹 Deduped ${toDelete.length} older connection(s) for ${effectiveMerchantId}/${effectiveUserId}`);
                    }
                }
            } catch (dedupeErr) {
                console.warn('⚠️ Dedupe failed:', dedupeErr.message);
            }
        }

        console.log(`🔌 WebSocket connected: ${connectionId} for ${entityType}: ${effectiveUserId}${effectiveMerchantId ? ` (business: ${effectiveMerchantId})` : ''}`);

        // Send welcome message
        await sendMessageToConnection(connectionId, {
            type: 'CONNECTION_ESTABLISHED',
            message: `Connected to ${entityType === 'merchant' ? 'merchant' : 'customer'} notifications`,
            timestamp: currentTime,
            entityType,
            connectionId,
            ...(effectiveMerchantId && { businessId: effectiveMerchantId })
        });

        return { statusCode: 200, body: 'Connected' };

    } catch (error) {
        console.error('Error handling WebSocket connection:', error);
        return { statusCode: 500, body: 'Failed to connect' };
    }
}

/**
 * Handle WebSocket disconnection with proper state management
 * Following best practices: Update connection state instead of deleting records
 */
async function handleDisconnect(event) {
    try {
        const connectionId = event.requestContext.connectionId;
        const disconnectTime = new Date().toISOString();
        
        console.log(`🔌 WebSocket disconnecting: ${connectionId}`);

        // ✅ CORRECT APPROACH: Update connection state instead of deleting
        // This preserves connection history for analytics and troubleshooting
        try {
            // First, get the existing connection to preserve its data
            const existingConnection = await connectionsAdapter.getConnection(connectionId);
            
            if (existingConnection) {
                // Update connection state to inactive instead of deleting
                await connectionsAdapter.updateConnection(connectionId, {
                    isActive: false,
                    disconnectedAt: disconnectTime,
                    lastActivity: disconnectTime,
                    lastHeartbeat: disconnectTime,
                    disconnectReason: 'normal_disconnect'
                });
                
                console.log(`✅ Updated connection state to inactive: ${connectionId}`);
                console.log(`   Business ID: ${existingConnection.businessId || 'N/A'}`);
                console.log(`   User ID: ${existingConnection.userId || 'N/A'}`);
                console.log(`   Entity Type: ${existingConnection.entityType || 'N/A'}`);
            } else {
                console.log(`⚠️ Connection ${connectionId} not found in table (may be already cleaned)`);
            }
            
        } catch (connectionError) {
            console.error('Error updating connection state:', connectionError);
            // Fall back to deletion if update fails for some reason
            console.log('Falling back to connection deletion...');
            await connectionsAdapter.deleteConnection(connectionId);
        }

        // Also update merchant endpoints table for backward compatibility
        try {
            const merchantParams = {
                TableName: process.env.MERCHANT_ENDPOINTS_TABLE,
                FilterExpression: 'connectionId = :connectionId',
                ExpressionAttributeValues: {
                    ':connectionId': connectionId
                }
            };

            const result = await dynamodb.send(new ScanCommand(merchantParams));
            if (result.Items && result.Items.length > 0) {
                const item = result.Items[0];
                // Update instead of delete
                await dynamodb.send(new UpdateCommand({
                    TableName: process.env.MERCHANT_ENDPOINTS_TABLE,
                    Key: {
                        merchantId: item.merchantId,
                        endpointType: 'websocket'
                    },
                    UpdateExpression: 'SET isActive = :inactive, disconnectedAt = :disconnectTime, lastActivity = :lastActivity',
                    ExpressionAttributeValues: {
                        ':inactive': false,
                        ':disconnectTime': disconnectTime,
                        ':lastActivity': disconnectTime
                    }
                }));
                console.log(`✅ Updated merchant endpoint state for: ${item.merchantId}`);
            }
        } catch (merchantError) {
            console.warn('Warning: Could not update merchant endpoints table:', merchantError.message);
        }

        return { statusCode: 200, body: 'Disconnected' };

    } catch (error) {
        console.error('Error handling WebSocket disconnection:', error);
        return { statusCode: 500, body: 'Failed to disconnect' };
    }
}

/**
 * Send message to specific WebSocket connection with stale connection handling
 */
async function sendMessageToConnection(connectionId, message) {
    try {
        await apiGatewayManagementApi.send(new PostToConnectionCommand({
            ConnectionId: connectionId,
            Data: Buffer.from(JSON.stringify(message)),
        }));

        // Update last activity timestamp
        await updateConnectionHeartbeat(connectionId);

        console.log(`🔌 Message sent to connection ${connectionId}: ${message.type || 'unknown'}`);

    } catch (error) {
        if (error.statusCode === 410 || error.name === 'GoneException') {
            // Connection is stale, remove from database
            console.log(`🔌 Stale connection detected, removing: ${connectionId}`);
            await removeStaleConnection(connectionId);
        } else {
            console.error('Error sending WebSocket message:', error);
            throw error;
        }
    }
}

/**
 * Update connection heartbeat timestamp
 */
async function updateConnectionHeartbeat(connectionId) {
    try {
        await connectionsAdapter.updateHeartbeat(connectionId);
    } catch (error) {
        console.warn('Warning: Could not update connection heartbeat:', error.message);
    }
}

/**
 * Send message to all active connections for a merchant/business
 */
async function sendMessageToMerchant(merchantId, message) {
    try {
        // Get all active real WebSocket connections for the merchant
        const connections = await getActiveConnectionsForBusiness(merchantId);
        
        if (connections.length === 0) {
            console.log(`📭 No active WebSocket connections found for merchant: ${merchantId}`);
            return;
        }

        // Send message to all active connections
        const promises = connections.map(connection =>
            sendMessageToConnection(connection.connectionId, {
                ...message,
                businessId: merchantId,
                timestamp: new Date().toISOString()
            })
        );

        await Promise.all(promises);
        console.log(`🔌 Message sent to ${connections.length} connections for merchant ${merchantId}`);

    } catch (error) {
        console.error('Error sending message to merchant:', error);
    }
}

/**
 * Get all active real WebSocket connections for a business
 */
async function getActiveConnectionsForBusiness(businessId) {
    try {
        // Use adapter to get business connections with REAL connection type
        const activeConnections = await connectionsAdapter.getBusinessConnections(businessId, 'REAL');

        return activeConnections;
    } catch (error) {
        console.error('Error getting active connections for business:', error);
        return [];
    }
}

/**
 * Remove stale connection from all tables
 */
async function removeStaleConnection(connectionId) {
    try {
        // Remove from primary WebSocket connections table using adapter
        await connectionsAdapter.deleteConnection(connectionId);

        // Remove from merchant endpoints table (backward compatibility)
        const merchantParams = {
            TableName: process.env.MERCHANT_ENDPOINTS_TABLE,
            FilterExpression: 'connectionId = :connectionId',
            ExpressionAttributeValues: {
                ':connectionId': connectionId
            }
        };

        const result = await dynamodb.send(new ScanCommand(merchantParams));
        if (result.Items && result.Items.length > 0) {
            const item = result.Items[0];
            await dynamodb.send(new DeleteCommand({
                TableName: process.env.MERCHANT_ENDPOINTS_TABLE,
                Key: {
                    merchantId: item.merchantId,
                    endpointType: 'websocket'
                }
            }));
        }

        console.log(`🔌 Removed stale connection: ${connectionId}`);

    } catch (error) {
        console.error('Error removing stale connection:', error);
    }
}

/**
 * Handle incoming WebSocket messages
 */
async function handleMessage(event) {
    try {
        const connectionId = event.requestContext.connectionId;
        const message = JSON.parse(event.body);

        console.log(`🔌 Received message from ${connectionId}:`, message);

        // Update heartbeat for this connection
        await updateConnectionHeartbeat(connectionId);

        // Handle different message types (support both 'type' and 'action' fields for backward compatibility)
        const messageType = message.type || message.action;
        switch (messageType) {
            case 'PING':
            case 'ping':
                await sendMessageToConnection(connectionId, {
                    type: 'PONG',
                    timestamp: new Date().toISOString()
                });
                break;

            case 'HEARTBEAT':
            case 'heartbeat':
                await sendMessageToConnection(connectionId, {
                    type: 'HEARTBEAT_ACK',
                    timestamp: new Date().toISOString()
                });
                break;

            case 'subscribe':
                // Handle generic subscription from user apps (backward compatibility)
                console.log(`🔄 Generic subscribe request from ${connectionId}:`, message);
                await sendMessageToConnection(connectionId, {
                    type: 'SUBSCRIPTION_CONFIRMED',
                    message: 'Connected and subscribed to notifications',
                    connectionId: connectionId,
                    timestamp: new Date().toISOString()
                });
                break;

            case 'SUBSCRIBE_ORDERS':
                // Subscribe to order updates AND create proper subscription record
                if (message.businessId) {
                    await handleSubscribeOrders(connectionId, message);
                } else {
                    await sendMessageToConnection(connectionId, {
                        type: 'ERROR',
                        message: 'Missing businessId for SUBSCRIBE_ORDERS'
                    });
                }
                break;

            case 'REGISTER_CONNECTION':
                // Safety-net registration to ensure REAL connection record exists
                if (message.businessId || message.userId) {
                    await handleRegisterConnection(connectionId, message);
                } else {
                    await sendMessageToConnection(connectionId, {
                        type: 'ERROR',
                        message: 'Missing businessId or userId for REGISTER_CONNECTION'
                    });
                }
                break;

            case 'subscribe_business_status':
            case 'SUBSCRIBE_BUSINESS_STATUS':
                // Handle business status subscription from customer apps
                if (message.businessId || message.business_id) {
                    await handleSubscribeBusinessStatus(connectionId, message);
                } else {
                    await sendMessageToConnection(connectionId, {
                        type: 'ERROR',
                        message: 'Missing businessId for business status subscription'
                    });
                }
                break;

            case 'unsubscribe_business_status':
            case 'UNSUBSCRIBE_BUSINESS_STATUS':
                // Handle business status unsubscription from customer apps
                if (message.businessId || message.business_id) {
                    await handleUnsubscribeBusinessStatus(connectionId, message);
                } else {
                    await sendMessageToConnection(connectionId, {
                        type: 'ERROR',
                        message: 'Missing businessId for business status unsubscription'
                    });
                }
                break;

            case 'ORDER_STATUS_UPDATE':
                // Handle order status updates for actual subscription pattern
                if (message.businessId && message.orderId && message.status && message.userId) {
                    await handleOrderStatusSubscriptionUpdate(
                        message.businessId, 
                        message.orderId, 
                        message.status, 
                        connectionId
                    );
                }
                break;

            case 'BUSINESS_STATUS_UPDATE':
                // Handle business status updates
                if (message.businessId && message.userId !== undefined && message.isActive !== undefined) {
                    await handleBusinessStatusSubscriptionUpdate(
                        message.businessId,
                        message.userId,
                        message.isActive,
                        connectionId
                    );
                }
                break;

            case 'BUSINESS_BUSY_STATUS_UPDATE':
                // Handle business busy status updates from business app
                if (message.businessId && message.isBusy !== undefined) {
                    await handleBusinessBusyStatusUpdate(
                        message.businessId,
                        message.userId || 'unknown',
                        message.isBusy,
                        connectionId
                    );
                }
                break;

            case 'MERCHANT_LOGOUT':
                // Handle merchant logout - set all subscriptions to inactive
                if (message.businessId && message.userId) {
                    await handleMerchantLogout(
                        message.businessId,
                        message.userId,
                        connectionId
                    );
                }
                break;

            default:
                const unknownType = message.type || message.action;
                console.log(`Unknown message type/action: ${unknownType}`, { 
                    type: message.type, 
                    action: message.action,
                    fullMessage: message 
                });
                await sendMessageToConnection(connectionId, {
                    type: 'ERROR',
                    message: `Unknown message type/action: ${unknownType}`,
                    originalType: message.type,
                    originalAction: message.action
                });
        }

        return { statusCode: 200, body: 'Message processed' };

    } catch (error) {
        console.error('Error handling WebSocket message:', error);
        return { statusCode: 500, body: 'Failed to process message' };
    }
}

/**
 * Handle SUBSCRIBE_ORDERS message and create proper subscription records
 */
async function handleSubscribeOrders(connectionId, message) {
    try {
        const { businessId, userId, entityType = 'merchant' } = message;
        const timestamp = new Date().toISOString();
        
        console.log(`🔄 SUBSCRIBE_ORDERS: ${businessId} (user: ${userId}, entity: ${entityType})`);
        
        // CRITICAL FIX: Force update connection entityType to "merchant" if businessId is present
        // This corrects the WizzUser system's default "customer" entity type for merchant connections
        if (businessId) {
            try {
                console.log(`🔧 FIXING: Updating connection ${connectionId} entityType from "customer" to "merchant"`);
                const connectionUpdateParams = {
                    TableName: WEBSOCKET_CONNECTIONS_TABLE,
                    Key: {
                        connectionId: connectionId
                    },
                    UpdateExpression: 'SET entityType = :entityType, businessId = :businessId, lastUpdate = :timestamp',
                    ExpressionAttributeValues: {
                        ':entityType': 'merchant',
                        ':businessId': businessId,
                        ':timestamp': timestamp
                    }
                };
                
                await dynamodb.send(new UpdateCommand(connectionUpdateParams));
                console.log(`✅ FIXED: Connection ${connectionId} entityType updated to "merchant"`);
            } catch (connectionUpdateError) {
                console.error('⚠️ Failed to update connection entityType:', connectionUpdateError);
                // Continue processing even if connection update fails
            }
        }
        
        // Prevent duplicate business_status subscriptions for same business/user
        const subscriptionsTable = WEBSOCKET_SUBSCRIPTIONS_TABLE;
        const findSubscriptionParams = {
            TableName: subscriptionsTable,
            FilterExpression: 'businessId = :businessId AND userId = :userId AND subscriptionType = :subscriptionType',
            ExpressionAttributeValues: {
                ':businessId': businessId,
                ':userId': userId || businessId,
                ':subscriptionType': 'business_status'
            }
        };
        
        const existing = await dynamodb.send(new ScanCommand(findSubscriptionParams));
        
        if (existing.Items && existing.Items.length > 0) {
            // Update the first existing subscription to be active and correct types
            const sub = existing.Items[0];
            const updateParams = {
                TableName: subscriptionsTable,
                Key: { subscriptionId: sub.subscriptionId },
                UpdateExpression: 'SET isActive = :isActive, userType = :userType, entityType = :entityType, connectionId = :connectionId, lastUpdate = :timestamp',
                ExpressionAttributeValues: {
                    ':isActive': true,
                    ':userType': 'merchant',
                    ':entityType': 'merchant',
                    ':connectionId': connectionId,
                    ':timestamp': timestamp
                }
            };
            await dynamodb.send(new UpdateCommand(updateParams));
            console.log(`🔁 Activated existing business_status subscription: ${sub.subscriptionId}`);
        } else {
            // Create business_status subscription with correct merchant entity type
            const subscriptionId = `${connectionId}_business_status_${Date.now()}`;
            
            const subscriptionParams = {
                TableName: subscriptionsTable,
                Item: {
                    subscriptionId,
                    connectionId,
                    businessId,
                    userId: userId || businessId,
                    userType: 'merchant', // FIXED: Use merchant instead of customer
                    entityType: 'merchant', // FIXED: Use merchant instead of customer  
                    subscriptionType: 'business_status',
                    topic: `business:${businessId}`,
                    isActive: true,
                    createdAt: timestamp,
                    lastUpdate: timestamp
                }
            };
            
            await dynamodb.send(new PutCommand(subscriptionParams));
            console.log(`✅ Created business_status subscription: ${subscriptionId} with userType=merchant`);
        }

        // Send success response
        await sendMessageToConnection(connectionId, {
            type: 'SUBSCRIBED',
            message: 'Subscribed to order updates',
            businessId,
            entityType: 'merchant',
            subscriptionType: 'business_status',
            timestamp
        });

    } catch (error) {
        console.error('Error handling SUBSCRIBE_ORDERS:', error);
        await sendMessageToConnection(connectionId, {
            type: 'ERROR',
            message: 'Failed to subscribe to orders',
            error: error.message
        });
    }
}

/**
 * Handle business status subscription update (toggle online/offline)
 */
async function handleBusinessStatusSubscriptionUpdate(businessId, userId, isActive, connectionId) {
    try {
        const timestamp = new Date().toISOString();
        
        console.log(`🔄 Business status update: ${businessId} (user: ${userId}) → isActive: ${isActive}`);
        
        // CRITICAL FIX: Force update connection entityType to "merchant" for any business operation
        if (businessId && connectionId) {
            try {
                console.log(`🔧 FIXING: Updating connection ${connectionId} entityType to "merchant" during toggle`);
                const connectionUpdateParams = {
                    TableName: WEBSOCKET_CONNECTIONS_TABLE,
                    Key: {
                        connectionId: connectionId
                    },
                    UpdateExpression: 'SET entityType = :entityType, businessId = :businessId, lastUpdate = :timestamp',
                    ExpressionAttributeValues: {
                        ':entityType': 'merchant',
                        ':businessId': businessId,
                        ':timestamp': timestamp
                    }
                };
                
                await dynamodb.send(new UpdateCommand(connectionUpdateParams));
                console.log(`✅ FIXED: Connection ${connectionId} entityType updated to "merchant"`);
            } catch (connectionUpdateError) {
                console.error('⚠️ Failed to update connection entityType during toggle:', connectionUpdateError);
                // Continue processing even if connection update fails
            }
        }
        
        // 1. Update the business isActive field in WhizzMerchants_Businesses table
        const businessUpdateParams = {
            TableName: process.env.BUSINESSES_TABLE || 'WhizzMerchants_Businesses',
            Key: {
                businessId: businessId
            },
            UpdateExpression: 'SET isActive = :isActive, updatedAt = :timestamp',
            ExpressionAttributeValues: {
                ':isActive': isActive,
                ':timestamp': timestamp
            }
        };
        
        await dynamodb.send(new UpdateCommand(businessUpdateParams));
        console.log(`✅ Updated business ${businessId} isActive field to: ${isActive}`);
        
        // 2. Find existing business_status subscriptions for this business (ignore userId to avoid mismatches)
        const subscriptionsTable = WEBSOCKET_SUBSCRIPTIONS_TABLE;
        const findSubscriptionParams = {
            TableName: subscriptionsTable,
            FilterExpression: 'businessId = :businessId AND subscriptionType = :subscriptionType',
            ExpressionAttributeValues: {
                ':businessId': businessId,
                ':subscriptionType': 'business_status'
            }
        };
        
        const scanResult = await dynamodb.send(new ScanCommand(findSubscriptionParams));
        
        if (scanResult.Items && scanResult.Items.length > 0) {
            // Update existing subscriptions with correct entity types and isActive status
            const updatePromises = scanResult.Items.map(async (subscription) => {
                const updateParams = {
                    TableName: subscriptionsTable,
                    Key: {
                        subscriptionId: subscription.subscriptionId
                    },
                    UpdateExpression: 'SET isActive = :isActive, userType = :userType, entityType = :entityType, lastUpdate = :timestamp',
                    ExpressionAttributeValues: {
                        ':isActive': isActive,
                        ':userType': 'merchant', // FIXED: Use merchant instead of customer
                        ':entityType': 'merchant', // FIXED: Use merchant instead of customer
                        ':timestamp': timestamp
                    }
                };
                
                return dynamodb.send(new UpdateCommand(updateParams));
            });
            
            await Promise.all(updatePromises);
            console.log(`✅ Updated ${scanResult.Items.length} business_status subscription(s) with merchant entity types`);
        } else {
            // No existing subscription found, create a new one with correct entity types
            const subscriptionId = `${connectionId}_business_status_${Date.now()}`;
            const subscriptionParams = {
                TableName: subscriptionsTable,
                Item: {
                    subscriptionId,
                    connectionId,
                    businessId,
                    userId,
                    userType: 'merchant', // FIXED: Use merchant instead of customer
                    entityType: 'merchant', // FIXED: Use merchant instead of customer
                    subscriptionType: 'business_status',
                    topic: `business:${businessId}`,
                    isActive: isActive,
                    createdAt: timestamp,
                    lastUpdate: timestamp
                }
            };
            
            await dynamodb.send(new PutCommand(subscriptionParams));
            console.log(`✅ Created new business_status subscription: ${subscriptionId} with merchant entity types`);
        }

        // 2a. Upsert shared status row for customers: subscriptionType=merchant_status, topic=merchant_status_<businessId>
        try {
            const sharedStatusId = `merchant_status_${businessId}`;
            const upsertSharedStatus = {
                TableName: subscriptionsTable,
                Key: { subscriptionId: sharedStatusId },
                UpdateExpression: 'SET businessId = :businessId, subscriptionType = :stype, topic = :topic, isActive = :isActive, userType = :userType, entityType = :entityType, lastUpdate = :timestamp ADD version :one',
                ExpressionAttributeValues: {
                    ':businessId': businessId,
                    ':stype': 'merchant_status',
                    ':topic': `merchant_status_${businessId}`,
                    ':isActive': isActive,
                    ':userType': 'merchant',
                    ':entityType': 'merchant',
                    ':timestamp': timestamp,
                    ':one': 1
                },
                ReturnValues: 'ALL_NEW'
            };
            await dynamodb.send(new UpdateCommand(upsertSharedStatus));
            console.log(`🗂️ Upserted shared merchant_status row: ${sharedStatusId} → isActive=${isActive}`);
        } catch (sharedErr) {
            console.warn('⚠️ Failed to upsert shared merchant_status row:', sharedErr?.message || sharedErr);
        }

        // 2b. Ecosystem broadcast: notify all customer apps subscribed to this merchant's status
        try {
            const statusText = isActive ? 'online' : 'offline';
            await broadcastMerchantStatusChange(businessId, statusText, timestamp);
            console.log(`📣 Broadcasted merchant status change to customers: ${businessId} → ${statusText}`);
        } catch (broadcastErr) {
            console.warn('⚠️ Failed to broadcast merchant status change:', broadcastErr?.message || broadcastErr);
        }

        // 3. Send confirmation back to the client
        await sendMessageToConnection(connectionId, {
            type: 'BUSINESS_STATUS_UPDATED',
            businessId: businessId,
            isActive: isActive,
            entityType: 'merchant',
            timestamp: timestamp,
            message: `Business status updated to ${isActive ? 'online' : 'offline'}`
        });

        console.log(`✅ Business status update completed for: ${businessId}`);

    } catch (error) {
        console.error('Error updating business status:', error);
        await sendMessageToConnection(connectionId, {
            type: 'ERROR',
            message: 'Failed to update business status',
            businessId: businessId,
            error: error.message
        });
    }
}

/**
 * Handle business busy status update and broadcast to subscribers
 */
async function handleBusinessBusyStatusUpdate(businessId, userId, isBusy, connectionId) {
    try {
        const timestamp = new Date().toISOString();
        
        console.log(`🔄 Business busy status update: ${businessId} (user: ${userId}) → isBusy: ${isBusy}`);
        
        // Get business name for the broadcast message
        let businessName = 'Unknown Business';
        try {
            const businessParams = {
                TableName: process.env.BUSINESSES_TABLE || 'WhizzMerchants_Businesses',
                Key: { businessId: businessId }
            };
            const businessResult = await dynamodb.send(new GetCommand(businessParams));
            if (businessResult.Item) {
                businessName = businessResult.Item.businessName || businessResult.Item.name || businessName;
            }
        } catch (error) {
            console.warn('Could not get business name:', error.message);
        }

        // Prepare status data for broadcast
        const statusData = {
            businessName: businessName,
            status: isBusy ? 'busy' : 'available',
            statusMessage: isBusy ? 'مشغول' : null,
            canAcceptOrders: !isBusy
        };

        // Broadcast the status update to all subscribers
        await broadcastBusinessStatusUpdate(businessId, statusData);
        
        // Send confirmation back to the business app
        await sendMessageToConnection(connectionId, {
            type: 'BUSINESS_BUSY_STATUS_RESPONSE',
            success: true,
            businessId: businessId,
            isBusy: isBusy,
            message: `Business busy status updated to: ${isBusy ? 'BUSY' : 'AVAILABLE'}`,
            timestamp: timestamp
        });

        console.log(`✅ Business busy status update completed for ${businessId}: ${isBusy ? 'BUSY' : 'AVAILABLE'}`);

    } catch (error) {
        console.error('Error handling business busy status update:', error);
        
        // Send error response back to the business app
        try {
            await sendMessageToConnection(connectionId, {
                type: 'BUSINESS_BUSY_STATUS_RESPONSE',
                success: false,
                businessId: businessId,
                error: 'Failed to update business busy status',
                message: error.message,
                timestamp: new Date().toISOString()
            });
        } catch (sendError) {
            console.error('Error sending error response:', sendError);
        }
    }
}

/**
 * Safety-net: explicitly register/refresh a REAL WebSocket connection from client message
 */
async function handleRegisterConnection(connectionId, message) {
    try {
        const currentTime = new Date().toISOString();
        const ttl = Math.floor(Date.now() / 1000) + 3600; // 1 hour TTL

        const entityType = message.entityType || 'merchant';
        const businessId = message.businessId || null;
        const userId = message.userId || businessId;

        await connectionsAdapter.createConnection({
            connectionId,
            entityType,
            userId,
            businessId,
            connectedAt: currentTime,
            ttl,
            isActive: true,
            connectionType: 'REAL',
            lastHeartbeat: currentTime,
            source: 'client_register'
        });

        console.log(`✅ REGISTER_CONNECTION upserted: ${connectionId} (userId=${userId}, businessId=${businessId})`);

        await sendMessageToConnection(connectionId, {
            type: 'REGISTERED',
            connectionId,
            entityType,
            businessId,
            userId,
            timestamp: currentTime
        });
    } catch (error) {
        console.error('Error handling REGISTER_CONNECTION:', error);
        await sendMessageToConnection(connectionId, {
            type: 'ERROR',
            message: 'Failed to register connection',
            error: error.message
        });
    }
}

/**
 * Handle merchant logout - proper connection state management
 * Following best practices: Update connection state instead of deleting
 */
async function handleMerchantLogout(businessId, userId, connectionId) {
    try {
        const timestamp = new Date().toISOString();
        
        console.log(`🔄 Merchant logout: ${businessId} (user: ${userId})`);
        
        // 1. Update the current connection state (instead of deleting)
        try {
            const existingConnection = await connectionsAdapter.getConnection(connectionId);
            
            if (existingConnection) {
                await connectionsAdapter.updateConnection(connectionId, {
                    isActive: false,
                    disconnectedAt: timestamp,
                    lastActivity: timestamp,
                    lastHeartbeat: timestamp,
                    disconnectReason: 'user_logout'
                });
                
                console.log(`✅ Updated connection ${connectionId} state to inactive (logout)`);
            } else {
                console.log(`⚠️ Connection ${connectionId} not found for logout update`);
            }
        } catch (connectionError) {
            console.warn('Error updating connection for logout:', connectionError);
        }
        
        // 2. Find and update all subscriptions for the merchant
        const findSubscriptionParams = {
            TableName: WEBSOCKET_SUBSCRIPTIONS_TABLE,
            FilterExpression: 'businessId = :businessId AND userId = :userId',
            ExpressionAttributeValues: {
                ':businessId': businessId,
                ':userId': userId
            }
        };

        const scanResult = await dynamodb.send(new ScanCommand(findSubscriptionParams));
        
        if (scanResult.Items && scanResult.Items.length > 0) {
            // Update each matching subscription to inactive
            const updatePromises = scanResult.Items.map(async (subscription) => {
                const updateParams = {
                    TableName: WEBSOCKET_SUBSCRIPTIONS_TABLE,
                    Key: {
                        subscriptionId: subscription.subscriptionId
                    },
                    UpdateExpression: 'SET isActive = :isActive, lastUpdate = :timestamp, deactivatedReason = :reason',
                    ExpressionAttributeValues: {
                        ':isActive': false,
                        ':timestamp': timestamp,
                        ':reason': 'user_logout'
                    }
                };
                
                return dynamodb.send(new UpdateCommand(updateParams));
            });
            
            await Promise.all(updatePromises);
            console.log(`✅ Updated ${scanResult.Items.length} subscription(s) to inactive for ${businessId}`);
        } else {
            console.log(`⚠️ No subscriptions found for ${businessId} and user ${userId}`);
        }

        // 2. Send confirmation back to the merchant
        await sendMessageToConnection(connectionId, {
            type: 'MERCHANT_LOGOUT_CONFIRMED',
            businessId: businessId,
            timestamp: timestamp,
            message: 'Merchant has been logged out and all subscriptions set to inactive'
        });

        console.log(`✅ Merchant logout processed: ${businessId}`);

    } catch (error) {
        console.error('Error processing merchant logout:', error);
        await sendMessageToConnection(connectionId, {
            type: 'ERROR',
            message: 'Failed to process merchant logout',
            businessId: businessId,
            error: error.message
        });
    }
}

/**
 * Broadcast message to multiple merchants
 */
async function broadcastToMerchants(merchantIds, message) {
    try {
        const promises = merchantIds.map(merchantId =>
            sendMessageToMerchant(merchantId, message)
        );

        await Promise.all(promises);
        console.log(`🔌 Broadcast sent to ${merchantIds.length} merchants`);

    } catch (error) {
        console.error('Error broadcasting to merchants:', error);
    }
}

/**
 * Broadcast merchant status change to customers app via shared WebSocket infrastructure
 * This notifies customers app about restaurant availability changes
 */
async function broadcastMerchantStatusChange(businessId, status, timestamp) {
    try {
        // Get all customer app subscriptions that should be notified about this merchant
        const customerSubscriptionsParams = {
            TableName: WEBSOCKET_SUBSCRIPTIONS_TABLE,
            IndexName: 'topic-createdAt-index', // Use the existing GSI
            KeyConditionExpression: 'topic = :topic',
            ExpressionAttributeValues: {
                ':topic': `merchant_status_${businessId}` // Customers subscribe to specific merchant status updates
            }
        };

        const subscriptionsResult = await dynamodb.send(new QueryCommand(customerSubscriptionsParams));
        
        if (subscriptionsResult.Items && subscriptionsResult.Items.length > 0) {
            // Create broadcast message for customers app
            const broadcastMessage = {
                type: 'MERCHANT_STATUS_CHANGE',
                data: {
                    merchantId: businessId,
                    status: status,
                    timestamp: timestamp,
                    isAcceptingOrders: status === 'online'
                }
            };

            // Get active WebSocket connections for customer apps that are subscribed
            const connectionPromises = subscriptionsResult.Items.map(async (subscription) => {
                try {
                    // Get active WebSocket connections for this user/customer
                    const connectionsParams = {
                        TableName: WEBSOCKET_CONNECTIONS_TABLE,
                        IndexName: 'userId-topic-index', // Use the existing GSI
                        KeyConditionExpression: 'userId = :userId',
                        FilterExpression: 'entityType = :entityType AND isActive = :isActive',
                        ExpressionAttributeValues: {
                            ':userId': subscription.userId,
                            ':entityType': 'customer',
                            ':isActive': true
                        }
                    };

                    const connectionsResult = await dynamodb.send(new QueryCommand(connectionsParams));
                    
                    if (connectionsResult.Items && connectionsResult.Items.length > 0) {
                        // Send message to all active customer connections
                        const sendPromises = connectionsResult.Items.map(connection =>
                            sendMessageToConnection(connection.connectionId, broadcastMessage)
                        );
                        
                        await Promise.allSettled(sendPromises);
                        console.log(`📤 Sent merchant status update to ${connectionsResult.Items.length} customer connections for user ${subscription.userId}`);
                    }
                } catch (connectionError) {
                    console.warn(`Warning: Could not send to user ${subscription.userId}:`, connectionError.message);
                }
            });

            await Promise.allSettled(connectionPromises);
            console.log(`🔔 Merchant status broadcast completed for ${businessId}: ${subscriptionsResult.Items.length} subscribers notified`);
        } else {
            console.log(`ℹ️ No customer subscriptions found for merchant ${businessId}`);
        }

    } catch (error) {
        console.error('Error broadcasting merchant status change:', error);
        // Don't throw error - this is a notification feature, not critical for main functionality
    }
}

/**
 * Clean up stale connections (can be called periodically)
 */
async function cleanupStaleConnections() {
    try {
        console.log('🧹 Starting stale connection cleanup...');

        // Get all REAL connections using adapter
        const connections = await connectionsAdapter.getAllConnections(
            'connectionType = :connType',
            { ':connType': 'REAL' }
        );

        // Check for expired connections
        const currentTime = Math.floor(Date.now() / 1000);
        const expiredConnections = connections.filter(conn => 
            conn.ttl && conn.ttl < currentTime
        );

        console.log(`Found ${expiredConnections.length} expired connections out of ${connections.length} total`);

        // Remove expired connections
        for (const connection of expiredConnections) {
            await removeStaleConnection(connection.connectionId);
        }

        console.log(`✅ Cleaned up ${expiredConnections.length} stale connections`);
        return expiredConnections.length;

    } catch (error) {
        console.error('Error during stale connection cleanup:', error);
        return 0;
    }
}

/**
 * Get comprehensive business connection status
 */
async function getBusinessConnectionStatus(businessId) {
    try {
        // Get real WebSocket connections
        const realConnections = await getActiveConnectionsForBusiness(businessId);

        // Get login tracking connections (virtual connections)
        const allConnections = await connectionsAdapter.getBusinessConnections(businessId);
        const activeLoginConnections = allConnections.filter(conn => 
            conn.isLoginTracking === true
        );

        // Get business settings
        const businessParams = {
            TableName: process.env.BUSINESSES_TABLE || 'order-receiver-businesses-dev',
            Key: {
                businessId: businessId
            },
            ProjectionExpression: 'acceptingOrders, lastStatusUpdate'
        };

        const businessResult = await dynamodb.send(new GetCommand(businessParams));
        const businessData = businessResult.Item || {};

        return {
            businessId,
            hasRealTimeConnection: realConnections.length > 0,
            realConnectionsCount: realConnections.length,
            hasLoginTracking: activeLoginConnections.length > 0,
            loginTrackingCount: activeLoginConnections.length,
            acceptingOrders: businessData.acceptingOrders || false,
            lastStatusUpdate: businessData.lastStatusUpdate,
            overallStatus: determineOverallBusinessStatus(
                realConnections.length > 0,
                activeLoginConnections.length > 0,
                businessData.acceptingOrders || false
            ),
            connectionDetails: {
                realConnections: realConnections.map(conn => ({
                    connectionId: conn.connectionId,
                    connectedAt: conn.connectedAt,
                    lastHeartbeat: conn.lastHeartbeat
                })),
                loginTracking: activeLoginConnections.map(conn => ({
                    trackingId: conn.connectionId,
                    connectedAt: conn.connectedAt,
                    userId: conn.userId
                }))
            }
        };

    } catch (error) {
        console.error('Error getting business connection status:', error);
        return {
            businessId,
            hasRealTimeConnection: false,
            realConnectionsCount: 0,
            hasLoginTracking: false,
            loginTrackingCount: 0,
            acceptingOrders: false,
            overallStatus: 'offline',
            error: error.message
        };
    }
}

/**
 * Determine overall business status based on connection types and settings
 */
function determineOverallBusinessStatus(hasRealConnection, hasLoginTracking, acceptingOrders) {
    if (hasRealConnection && acceptingOrders) {
        return 'online'; // Fully operational
    } else if (hasLoginTracking && acceptingOrders) {
        return 'available'; // Available but no real-time connection
    } else if (hasLoginTracking || hasRealConnection) {
        return 'logged_in'; // Logged in but not accepting orders
    } else {
        return 'offline'; // No connections
    }
}

/**
 * Main handler for WebSocket events
 */
async function handler(event) {
    const routeKey = event.requestContext.routeKey;

    console.log(`🔌 WebSocket event: ${routeKey}`, {
        connectionId: event.requestContext.connectionId,
        eventType: event.requestContext.eventType
    });

    switch (routeKey) {
        case '$connect':
            return await handleConnect(event);
        case '$disconnect':
            return await handleDisconnect(event);
        case '$default':
            return await handleMessage(event);
        default:
            console.log('Unknown route:', routeKey);
            return { statusCode: 404, body: 'Route not found' };
    }
}

/**
 * Broadcast business status updates to all subscribers
 * This function should be called whenever a restaurant's status changes
 */
async function broadcastBusinessStatusUpdate(businessId, statusData) {
    try {
        const timestamp = new Date().toISOString();
        
        console.log(`📢 Broadcasting business status update for ${businessId}:`, statusData);
        
        // Find all business status subscriptions for this business
        const subscriptionsTable = WEBSOCKET_SUBSCRIPTIONS_TABLE;
        const findSubscriptionParams = {
            TableName: subscriptionsTable,
            FilterExpression: 'businessId = :businessId AND subscriptionType = :subscriptionType AND isActive = :isActive',
            ExpressionAttributeValues: {
                ':businessId': businessId,
                ':subscriptionType': 'business_status',
                ':isActive': true
            }
        };
        
        const subscriptionsResult = await dynamodb.send(new ScanCommand(findSubscriptionParams));
        
        if (subscriptionsResult.Items && subscriptionsResult.Items.length > 0) {
            console.log(`📤 Found ${subscriptionsResult.Items.length} active subscribers for business ${businessId}`);
            
            // Create broadcast message for subscribers
            const broadcastMessage = {
                type: 'BUSINESS_STATUS_UPDATE',
                businessId: businessId,
                businessName: statusData.businessName || 'Unknown',
                status: statusData.status,
                statusMessage: statusData.statusMessage,
                canAcceptOrders: statusData.canAcceptOrders,
                timestamp: timestamp
            };

            // Get active WebSocket connections for all subscribers
            const connectionPromises = subscriptionsResult.Items.map(async (subscription) => {
                try {
                    // Get active WebSocket connections for this subscriber
                    const connectionsParams = {
                        TableName: WEBSOCKET_CONNECTIONS_TABLE,
                        FilterExpression: 'userId = :userId AND entityType = :entityType AND isActive = :isActive',
                        ExpressionAttributeValues: {
                            ':userId': subscription.userId,
                            ':entityType': 'customer', // Looking for customer connections
                            ':isActive': true
                        }
                    };

                    const connectionsResult = await dynamodb.send(new ScanCommand(connectionsParams));
                    
                    if (connectionsResult.Items && connectionsResult.Items.length > 0) {
                        // Send message to all active customer connections
                        const sendPromises = connectionsResult.Items.map(connection =>
                            sendMessageToConnection(connection.connectionId, broadcastMessage)
                                .catch(error => {
                                    console.warn(`Failed to send to connection ${connection.connectionId}:`, error.message);
                                })
                        );
                        
                        await Promise.allSettled(sendPromises);
                        console.log(`✅ Sent business status update to ${connectionsResult.Items.length} connections for user ${subscription.userId}`);
                    }
                } catch (connectionError) {
                    console.warn(`Warning: Could not send to user ${subscription.userId}:`, connectionError.message);
                }
            });

            await Promise.allSettled(connectionPromises);
            console.log(`🔔 Business status broadcast completed for ${businessId}: ${subscriptionsResult.Items.length} subscribers notified`);
        } else {
            console.log(`📭 No active subscribers found for business ${businessId}`);
        }
        
    } catch (error) {
        console.error('Error broadcasting business status update:', error);
        throw error;
    }
}

/**
 * Handle business status subscription from customer apps
 */
async function handleSubscribeBusinessStatus(connectionId, message) {
    try {
        const businessId = message.businessId || message.business_id;
        const userId = message.userId || 'anonymous_customer';
        const timestamp = new Date().toISOString();
        
        console.log(`🔄 SUBSCRIBE_BUSINESS_STATUS: ${businessId} (user: ${userId})`);
        
        // Ensure this is marked as a customer connection
        try {
            const connectionUpdateParams = {
                TableName: WEBSOCKET_CONNECTIONS_TABLE,
                Key: {
                    connectionId: connectionId
                },
                UpdateExpression: 'SET entityType = :entityType, lastUpdate = :timestamp',
                ExpressionAttributeValues: {
                    ':entityType': 'customer',
                    ':timestamp': timestamp
                }
            };
            
            await dynamodb.send(new UpdateCommand(connectionUpdateParams));
            console.log(`✅ Ensured connection ${connectionId} entityType is "customer"`);
        } catch (connectionUpdateError) {
            console.warn('⚠️ Could not update connection entityType:', connectionUpdateError.message);
        }
        
        // Check for existing subscription
        const subscriptionsTable = WEBSOCKET_SUBSCRIPTIONS_TABLE;
        const findSubscriptionParams = {
            TableName: subscriptionsTable,
            FilterExpression: 'businessId = :businessId AND userId = :userId AND subscriptionType = :subscriptionType',
            ExpressionAttributeValues: {
                ':businessId': businessId,
                ':userId': userId,
                ':subscriptionType': 'business_status'
            }
        };
        
        const existing = await dynamodb.send(new ScanCommand(findSubscriptionParams));
        
        if (existing.Items && existing.Items.length > 0) {
            // Update existing subscription to be active
            const sub = existing.Items[0];
            const updateParams = {
                TableName: subscriptionsTable,
                Key: { subscriptionId: sub.subscriptionId },
                UpdateExpression: 'SET isActive = :isActive, connectionId = :connectionId, lastUpdate = :timestamp',
                ExpressionAttributeValues: {
                    ':isActive': true,
                    ':connectionId': connectionId,
                    ':timestamp': timestamp
                }
            };
            await dynamodb.send(new UpdateCommand(updateParams));
            console.log(`🔁 Activated existing business_status subscription: ${sub.subscriptionId}`);
        } else {
            // Create new subscription
            const subscriptionId = `${connectionId}_business_status_${Date.now()}`;
            
            const subscriptionParams = {
                TableName: subscriptionsTable,
                Item: {
                    subscriptionId,
                    connectionId,
                    businessId,
                    userId,
                    userType: 'customer',
                    entityType: 'customer',
                    subscriptionType: 'business_status',
                    topic: `business:${businessId}`,
                    isActive: true,
                    createdAt: timestamp,
                    lastUpdate: timestamp
                }
            };
            
            await dynamodb.send(new PutCommand(subscriptionParams));
            console.log(`✅ Created business_status subscription: ${subscriptionId} for customer`);
        }

        // Send success response
        await sendMessageToConnection(connectionId, {
            type: 'BUSINESS_STATUS_SUBSCRIBED',
            success: true,
            businessId: businessId,
            message: 'Successfully subscribed to business status updates',
            timestamp: timestamp
        });

    } catch (error) {
        console.error('Error handling SUBSCRIBE_BUSINESS_STATUS:', error);
        await sendMessageToConnection(connectionId, {
            type: 'BUSINESS_STATUS_SUBSCRIBE_ERROR',
            success: false,
            businessId: message.businessId || message.business_id,
            error: 'Failed to subscribe to business status',
            message: error.message,
            timestamp: new Date().toISOString()
        });
    }
}

/**
 * Handle business status unsubscription from customer apps
 */
async function handleUnsubscribeBusinessStatus(connectionId, message) {
    try {
        const businessId = message.businessId || message.business_id;
        const userId = message.userId || 'anonymous_customer';
        const timestamp = new Date().toISOString();
        
        console.log(`🔄 UNSUBSCRIBE_BUSINESS_STATUS: ${businessId} (user: ${userId})`);
        
        // Find and deactivate subscription
        const subscriptionsTable = WEBSOCKET_SUBSCRIPTIONS_TABLE;
        const findSubscriptionParams = {
            TableName: subscriptionsTable,
            FilterExpression: 'businessId = :businessId AND userId = :userId AND subscriptionType = :subscriptionType',
            ExpressionAttributeValues: {
                ':businessId': businessId,
                ':userId': userId,
                ':subscriptionType': 'business_status'
            }
        };
        
        const existing = await dynamodb.send(new ScanCommand(findSubscriptionParams));
        
        if (existing.Items && existing.Items.length > 0) {
            // Deactivate all matching subscriptions
            const updatePromises = existing.Items.map(async (subscription) => {
                const updateParams = {
                    TableName: subscriptionsTable,
                    Key: { subscriptionId: subscription.subscriptionId },
                    UpdateExpression: 'SET isActive = :isActive, lastUpdate = :timestamp',
                    ExpressionAttributeValues: {
                        ':isActive': false,
                        ':timestamp': timestamp
                    }
                };
                return dynamodb.send(new UpdateCommand(updateParams));
            });
            
            await Promise.all(updatePromises);
            console.log(`✅ Deactivated ${existing.Items.length} business_status subscription(s) for ${businessId}`);
        } else {
            console.log(`⚠️ No active subscription found for ${businessId} and user ${userId}`);
        }

        // Send success response
        await sendMessageToConnection(connectionId, {
            type: 'BUSINESS_STATUS_UNSUBSCRIBED',
            success: true,
            businessId: businessId,
            message: 'Successfully unsubscribed from business status updates',
            timestamp: timestamp
        });

    } catch (error) {
        console.error('Error handling UNSUBSCRIBE_BUSINESS_STATUS:', error);
        await sendMessageToConnection(connectionId, {
            type: 'BUSINESS_STATUS_UNSUBSCRIBE_ERROR',
            success: false,
            businessId: message.businessId || message.business_id,
            error: 'Failed to unsubscribe from business status',
            message: error.message,
            timestamp: new Date().toISOString()
        });
    }
}

module.exports = {
    handler,
    handleConnect,
    handleDisconnect,
    handleMessage,
    sendMessageToConnection,
    sendMessageToMerchant,
    broadcastToMerchants,
    broadcastBusinessStatusUpdate,
    handleBusinessBusyStatusUpdate,
    handleSubscribeBusinessStatus,
    handleUnsubscribeBusinessStatus,
    cleanupStaleConnections,
    getBusinessConnectionStatus,
    getActiveConnectionsForBusiness,
    removeStaleConnection,
    updateConnectionHeartbeat
};

// Merchant clients use the authenticated, branch-pinned universal websocket.
module.exports.handler=async event=>({statusCode:event.httpMethod==='OPTIONS'?204:410,headers:{'Content-Type':'application/json','Access-Control-Allow-Origin':'*'},body:JSON.stringify({code:'AUTHENTICATED_REALTIME_REQUIRED'})});
