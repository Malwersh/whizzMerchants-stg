const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { DynamoDBDocumentClient, ScanCommand, DeleteCommand } = require('@aws-sdk/lib-dynamodb');
const { ApiGatewayManagementApiClient, PostToConnectionCommand } = require('@aws-sdk/client-apigatewaymanagementapi');

const dynamoDbClient = new DynamoDBClient({ region: process.env.AWS_REGION || 'us-east-1' });
const dynamodb = DynamoDBDocumentClient.from(dynamoDbClient);

const WEBSOCKET_ENDPOINT = process.env.WEBSOCKET_ENDPOINT;
const WEBSOCKET_CONNECTIONS_TABLE = process.env.WEBSOCKET_CONNECTIONS_TABLE;
if (!WEBSOCKET_ENDPOINT) {
    throw new Error('Missing required env var: WEBSOCKET_ENDPOINT');
}
if (!WEBSOCKET_CONNECTIONS_TABLE) {
    throw new Error('Missing required env var: WEBSOCKET_CONNECTIONS_TABLE');
}

const apiGatewayManagementApi = new ApiGatewayManagementApiClient({
    region: process.env.AWS_REGION || 'us-east-1',
    endpoint: WEBSOCKET_ENDPOINT
});

/**
 * 📡 Business Status & Working Hours Broadcast Function
 * 
 * This function receives business status or working hours updates and broadcasts them to all
 * connected user apps via WebSocket connections.
 * 
 * Expected payload for status update:
 * {
 *   type: 'business_status_update',
 *   businessId: string,
 *   updateData: {
 *     businessName: string,
 *     status: 'available' | 'busy',
 *     statusMessage: string,
 *     canAcceptOrders: boolean,
 *     isBusy: boolean,
 *     lastStatusUpdate: string
 *   }
 * }
 * 
 * Expected payload for working hours update:
 * {
 *   type: 'working_hours_update',
 *   businessId: string,
 *   updateData: {
 *     businessName: string,
 *     workingHours: object,
 *     workingHoursUpdatedAt: string
 *   }
 * }
 */
exports.handler = async (event) => {
    console.log('📡 Business Status/Working Hours Broadcast Function invoked');
    console.log('📥 Raw event:', JSON.stringify(event, null, 2));
    
    try {
        // Parse the request body
        let requestBody;
        if (event.body) {
            console.log('🔍 Event has body, parsing...');
            requestBody = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
        } else {
            console.log('🔍 Direct invocation, using event as requestBody');
            requestBody = event; // Direct invocation
        }
        
        console.log('📋 Parsed request body:', JSON.stringify(requestBody, null, 2));
        
        const { type, businessId, updateData } = requestBody;
        
        console.log('🔍 Update type:', type);
        console.log('🔍 Extracted businessId:', businessId);
        console.log('🔍 Extracted updateData:', updateData);
        
        if (!businessId || !updateData) {
            console.error('❌ Missing required fields: businessId and updateData');
            return {
                statusCode: 400,
                headers: {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*',
                    'Access-Control-Allow-Headers': 'Content-Type,Authorization',
                    'Access-Control-Allow-Methods': 'POST,OPTIONS'
                },
                body: JSON.stringify({
                    error: 'Missing required fields: businessId and updateData'
                })
            };
        }
        
        // Broadcast based on type
        let result;
        if (type === 'working_hours_update') {
            console.log('📅 Broadcasting working hours update');
            result = await broadcastWorkingHoursUpdate(businessId, updateData);
        } else {
            console.log('📊 Broadcasting business status update');
            result = await broadcastBusinessStatusUpdate(businessId, updateData);
        }
        
        return {
            statusCode: 200,
            headers: {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type,Authorization',
                'Access-Control-Allow-Methods': 'POST,OPTIONS'
            },
            body: JSON.stringify({
                message: 'Business status broadcast completed',
                businessId: businessId,
                result: result
            })
        };
        
    } catch (error) {
        console.error('❌ Error in broadcast function:', error);
        
        return {
            statusCode: 500,
            headers: {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type,Authorization',
                'Access-Control-Allow-Methods': 'POST,OPTIONS'
            },
            body: JSON.stringify({
                error: 'Internal server error',
                message: error.message
            })
        };
    }
};

/**
 * Broadcast business status update to connected user apps
 * 🔧 FIXED: Direct broadcast to all active customer connections
 * This ensures reliable delivery without depending on subscriptions table
 */
async function broadcastBusinessStatusUpdate(businessId, statusData) {
    try {
        const timestamp = new Date().toISOString();
        
        console.log(`📢 Broadcasting business status update for ${businessId}:`, statusData);
        console.log(`🎯 Using DIRECT BROADCAST to all active customer connections`);
        
        let totalMessagesSent = 0;
        let totalConnectionsAttempted = 0;
        let staleConnectionsRemoved = 0;
        
        // 🔧 FIX: Direct broadcast to ALL active customer connections
        // This is more reliable than searching for specific subscriptions
        const connectionsTable = WEBSOCKET_CONNECTIONS_TABLE;
        
        try {
            const allCustomerConnectionsParams = {
                TableName: connectionsTable,
                FilterExpression: 'entityType = :entityType AND isActive = :isActive AND #status = :status',
                ExpressionAttributeNames: {
                    '#status': 'status'
                },
                ExpressionAttributeValues: {
                    ':entityType': 'customer',
                    ':isActive': true,
                    ':status': 'connected'
                }
            };
            
            const allConnectionsResult = await dynamodb.send(new ScanCommand(allCustomerConnectionsParams));
            
            if (allConnectionsResult.Items && allConnectionsResult.Items.length > 0) {
                console.log(`📡 Broadcasting to ${allConnectionsResult.Items.length} active customer connections`);
                totalConnectionsAttempted = allConnectionsResult.Items.length;
                
                const broadcastMessage = {
                    type: 'BUSINESS_STATUS_UPDATE',
                    businessId: businessId,
                    businessName: statusData.businessName || 'Unknown',
                    status: statusData.status,
                    statusMessage: statusData.statusMessage,
                    canAcceptOrders: statusData.canAcceptOrders,
                    isBusy: statusData.isBusy,
                    timestamp: timestamp
                };
                
                const sendAllPromises = allConnectionsResult.Items.map(async (connection) => {
                    try {
                        await sendMessageToConnection(connection.connectionId, broadcastMessage);
                        totalMessagesSent++;
                        console.log(`✅ Sent to connection ${connection.connectionId} (user: ${connection.userId || 'unknown'})`);
                    } catch (error) {
                        if (error.statusCode === 410) {
                            await removeStaleConnection(connection.connectionId);
                            staleConnectionsRemoved++;
                            console.log(`🗑️ Removed stale connection: ${connection.connectionId}`);
                        } else {
                            console.warn(`⚠️ Failed to send to connection ${connection.connectionId}:`, error.message);
                        }
                    }
                });
                
                await Promise.allSettled(sendAllPromises);
            } else {
                console.log('⚠️ No active customer connections found');
            }
        } catch (connectionsError) {
            console.error('❌ Error broadcasting to customer connections:', connectionsError);
            throw connectionsError;
        }
        
        // ✅ Direct broadcast completed - removed duplicate code
        
        const result = {
            businessId,
            totalConnectionsAttempted,
            totalMessagesSent,
            staleConnectionsRemoved,
            successRate: totalConnectionsAttempted > 0 ? (totalMessagesSent / totalConnectionsAttempted * 100).toFixed(1) + '%' : '0%'
        };
        
        console.log(`🎯 Business status broadcast completed for ${businessId}:`, result);
        return result;
        
    } catch (error) {
        console.error('❌ Error broadcasting business status update:', error);
        throw error;
    }
}

/**
 * Send message to a specific WebSocket connection
 */
async function sendMessageToConnection(connectionId, message) {
    try {
        const command = new PostToConnectionCommand({
            ConnectionId: connectionId,
            Data: JSON.stringify(message)
        });
        
        await apiGatewayManagementApi.send(command);
        
    } catch (error) {
        console.error(`❌ Failed to send message to connection ${connectionId}:`, error.message);
        throw error;
    }
}

/**
 * Remove stale connection from database
 */
async function removeStaleConnection(connectionId) {
    try {
        const deleteParams = {
            TableName: WEBSOCKET_CONNECTIONS_TABLE,
            Key: {
                connectionId: connectionId
            }
        };
        
        await dynamodb.send(new DeleteCommand(deleteParams));
        console.log(`🗑️ Removed stale connection: ${connectionId}`);
        
    } catch (error) {
        console.warn(`⚠️ Failed to remove stale connection ${connectionId}:`, error.message);
    }
}

/**
 * Broadcast working hours update to connected user apps
 * 📅 Direct broadcast to all active customer connections
 */
async function broadcastWorkingHoursUpdate(businessId, workingHoursData) {
    try {
        const timestamp = new Date().toISOString();
        
        console.log(`📅 Broadcasting working hours update for ${businessId}:`, workingHoursData);
        console.log(`🎯 Using DIRECT BROADCAST to all active customer connections`);
        
        let totalMessagesSent = 0;
        let totalConnectionsAttempted = 0;
        let staleConnectionsRemoved = 0;
        
        // Direct broadcast to ALL active customer connections
        const connectionsTable = WEBSOCKET_CONNECTIONS_TABLE;
        
        try {
            const allCustomerConnectionsParams = {
                TableName: connectionsTable,
                FilterExpression: 'entityType = :entityType AND isActive = :isActive AND #status = :status',
                ExpressionAttributeNames: {
                    '#status': 'status'
                },
                ExpressionAttributeValues: {
                    ':entityType': 'customer',
                    ':isActive': true,
                    ':status': 'connected'
                }
            };
            
            const allConnectionsResult = await dynamodb.send(new ScanCommand(allCustomerConnectionsParams));
            
            if (allConnectionsResult.Items && allConnectionsResult.Items.length > 0) {
                console.log(`📡 Broadcasting working hours to ${allConnectionsResult.Items.length} active customer connections`);
                totalConnectionsAttempted = allConnectionsResult.Items.length;
                
                const broadcastMessage = {
                    type: 'WORKING_HOURS_UPDATE',
                    businessId: businessId,
                    businessName: workingHoursData.businessName || 'Unknown',
                    workingHours: workingHoursData.workingHours || {},
                    workingHoursUpdatedAt: workingHoursData.workingHoursUpdatedAt,
                    lastUpdate: workingHoursData.lastUpdate || workingHoursData.workingHoursUpdatedAt,
                    timestamp: timestamp
                };
                
                const sendAllPromises = allConnectionsResult.Items.map(async (connection) => {
                    try {
                        await sendMessageToConnection(connection.connectionId, broadcastMessage);
                        totalMessagesSent++;
                        console.log(`✅ Sent working hours update to connection ${connection.connectionId} (user: ${connection.userId || 'unknown'})`);
                    } catch (error) {
                        if (error.statusCode === 410) {
                            await removeStaleConnection(connection.connectionId);
                            staleConnectionsRemoved++;
                            console.log(`🗑️ Removed stale connection: ${connection.connectionId}`);
                        } else {
                            console.warn(`⚠️ Failed to send to connection ${connection.connectionId}:`, error.message);
                        }
                    }
                });
                
                await Promise.allSettled(sendAllPromises);
            } else {
                console.log('⚠️ No active customer connections found for working hours broadcast');
            }
        } catch (connectionsError) {
            console.error('❌ Error broadcasting working hours to customer connections:', connectionsError);
            throw connectionsError;
        }
        
        const result = {
            businessId,
            totalConnectionsAttempted,
            totalMessagesSent,
            staleConnectionsRemoved,
            successRate: totalConnectionsAttempted > 0 ? (totalMessagesSent / totalConnectionsAttempted * 100).toFixed(1) + '%' : '0%'
        };
        
        console.log(`🎯 Working hours broadcast completed for ${businessId}:`, result);
        return result;
        
    } catch (error) {
        console.error('❌ Error broadcasting working hours update:', error);
        throw error;
    }
}

