const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { DynamoDBDocumentClient, PutCommand, QueryCommand, DeleteCommand, ScanCommand, UpdateCommand, GetCommand } = require('@aws-sdk/lib-dynamodb');
const jwt = require('jsonwebtoken');

const dynamoDbClient = new DynamoDBClient({ region: process.env.AWS_REGION || 'us-east-1' });
const dynamodb = DynamoDBDocumentClient.from(dynamoDbClient);

const WEBSOCKET_CONNECTIONS_TABLE = process.env.WEBSOCKET_CONNECTIONS_TABLE;
if (!WEBSOCKET_CONNECTIONS_TABLE) {
    throw new Error('Missing required env var: WEBSOCKET_CONNECTIONS_TABLE');
}

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'Content-Type,Authorization',
    'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS',
};

/**
 * Professional WebSocket Connection Manager
 * 
 * Endpoints:
 * - POST /websocket/virtual-connection - Create login tracking
 * - DELETE /websocket/business-connections - Remove all business connections
 * - GET /websocket/business-connections - List business connections
 * - GET /websocket/business-status - Get comprehensive business status
 * - POST /websocket/cleanup-stale - Clean up stale connections
 * - POST /websocket/heartbeat - Update connection heartbeat
 */

// Helper function to create response
function createResponse(statusCode, body) {
    return {
        statusCode,
        headers: corsHeaders,
        body: JSON.stringify(body),
    };
}

// Helper function to extract user ID from token
function getUserIdFromToken(authHeader) {
    try {
        if (!authHeader || !authHeader.startsWith('Bearer ')) {
            return null;
        }
        
        const token = authHeader.substring(7);
        const decoded = jwt.decode(token);
        return decoded?.sub || decoded?.['cognito:username'] || null;
    } catch (error) {
        console.error('Error decoding token:', error);
        return null;
    }
}

/**
 * Get comprehensive business connection status
 */
async function getBusinessConnectionStatus(businessId) {
    try {
        // Get real WebSocket connections
        const realConnectionsParams = {
            TableName: WEBSOCKET_CONNECTIONS_TABLE,
            IndexName: 'GSI1',
            KeyConditionExpression: 'GSI1PK = :userPK',
            FilterExpression: 'entityType = :entityType AND isActive = :active',
            ExpressionAttributeValues: {
                ':userPK': `USER#${businessId}`,
                ':entityType': 'business',
                ':active': true
            }
        };

        const realResult = await dynamodb.send(new QueryCommand(realConnectionsParams));

        // Get login tracking connections (business apps)
        const loginParams = {
            TableName: WEBSOCKET_CONNECTIONS_TABLE,
            IndexName: 'GSI1',
            KeyConditionExpression: 'GSI1PK = :userPK',
            FilterExpression: 'entityType = :entityType',
            ExpressionAttributeValues: {
                ':userPK': `USER#${businessId}`,
                ':entityType': 'business'
            }
        };

        const loginResult = await dynamodb.send(new QueryCommand(loginParams));

        // Filter active connections
        const currentTime = Math.floor(Date.now() / 1000);
        const activeRealConnections = (realResult.Items || []).filter(conn => 
            !conn.ttl || conn.ttl > currentTime
        );
        const activeLoginConnections = (loginResult.Items || []).filter(conn => 
            !conn.ttl || conn.ttl > currentTime
        );

        // Get business settings
        const businessParams = {
            TableName: process.env.BUSINESSES_TABLE || 'WhizzMerchants_Businesses',
            Key: {
                businessId: businessId
            },
            ProjectionExpression: 'acceptingOrders, lastStatusUpdate'
        };

        const businessResult = await dynamodb.send(new GetCommand(businessParams));
        const businessData = businessResult.Item || {};

        return {
            businessId,
            realTimeConnection: {
                connected: activeRealConnections.length > 0,
                count: activeRealConnections.length,
                connections: activeRealConnections.map(conn => ({
                    connectionId: conn.connectionId,
                    connectedAt: conn.connectedAt,
                    lastHeartbeat: conn.lastHeartbeat,
                    userId: conn.userId
                }))
            },
            loginTracking: {
                active: activeLoginConnections.length > 0,
                count: activeLoginConnections.length,
                sessions: activeLoginConnections.map(conn => ({
                    trackingId: conn.connectionId,
                    connectedAt: conn.connectedAt,
                    userId: conn.userId,
                    source: conn.source
                }))
            },
            businessStatus: {
                acceptingOrders: businessData.acceptingOrders || false,
                lastStatusUpdate: businessData.lastStatusUpdate
            },
            overallStatus: determineOverallBusinessStatus(
                activeRealConnections.length > 0,
                activeLoginConnections.length > 0,
                businessData.acceptingOrders || false
            )
        };

    } catch (error) {
        console.error('Error getting business connection status:', error);
        throw error;
    }
}

/**
 * Determine overall business status
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
 * Clean up stale connections
 */
async function cleanupStaleConnections() {
    try {
        console.log('🧹 Starting comprehensive stale connection cleanup...');

        // Get all connections
        const scanParams = {
            TableName: WEBSOCKET_CONNECTIONS_TABLE
        };

        const result = await dynamodb.send(new ScanCommand(scanParams));
        const connections = result.Items || [];

        // Check for expired connections
        const currentTime = Math.floor(Date.now() / 1000);
        const expiredConnections = connections.filter(conn => 
            conn.ttl && conn.ttl < currentTime
        );

        console.log(`Found ${expiredConnections.length} expired connections out of ${connections.length} total`);

        // Remove expired connections
        let cleanedCount = 0;
        for (const connection of expiredConnections) {
            try {
                await dynamodb.send(new DeleteCommand({
                    TableName: WEBSOCKET_CONNECTIONS_TABLE,
                    Key: {
                        PK: connection.PK,
                        SK: connection.SK
                    }
                }));
                cleanedCount++;
            } catch (deleteError) {
                console.error('Error deleting expired connection:', connection.PK, deleteError);
            }
        }

        console.log(`✅ Cleaned up ${cleanedCount} stale connections`);
        return {
            totalConnections: connections.length,
            expiredConnections: expiredConnections.length,
            cleanedConnections: cleanedCount
        };

    } catch (error) {
        console.error('Error during stale connection cleanup:', error);
        throw error;
    }
}

module.exports.handler = async (event) => {
    console.log('WebSocket Connection Manager Handler:', JSON.stringify(event, null, 2));
    
    const { httpMethod, path, headers, queryStringParameters } = event;

    if (httpMethod === 'OPTIONS') {
        return createResponse(204, {});
    }

    try {
        // Handle virtual connection creation (POST /websocket/virtual-connection)
        if (path === '/websocket/virtual-connection' && httpMethod === 'POST') {
            const authHeader = headers.authorization || headers.Authorization;
            const userId = getUserIdFromToken(authHeader);
            
            if (!userId) {
                return createResponse(401, {
                    success: false,
                    message: 'Invalid or missing authorization token'
                });
            }

            const body = JSON.parse(event.body || '{}');
            const { connectionId, businessId, entityType, isVirtualConnection, connectedAt, ttl, source } = body;

            if (!connectionId || !businessId || !entityType) {
                return createResponse(400, {
                    success: false,
                    message: 'Missing required fields: connectionId, businessId, entityType'
                });
            }

            // Create virtual connection entry in the websocket connections table
            const connectionItem = {
                PK: `CONNECTION#${connectionId}`,
                SK: `CONNECTION#${connectionId}`,
                connectionId,
                entityType,
                connectedAt: connectedAt || new Date().toISOString(),
                ttl: ttl || Math.floor(Date.now() / 1000) + 3600, // 1 hour default
                userId: userId,
                isVirtualConnection: true,
                isLoginTracking: true, // Mark as login tracking
                source: source || 'app_login',
                lastActivity: new Date().toISOString(),
                isActive: true,
                businessId: businessId,
                connectionType: 'VIRTUAL',
                GSI1PK: `BUSINESS#${businessId}`,
                GSI1SK: `CONNECTION#${connectionId}`
            };

            await dynamodb.send(new PutCommand({
                TableName: WEBSOCKET_CONNECTIONS_TABLE,
                Item: connectionItem
            }));

            console.log(`✅ Virtual WebSocket connection created for business login: ${businessId}`);

            return createResponse(200, {
                success: true,
                message: 'Virtual WebSocket connection created successfully',
                connectionId: connectionId,
                businessId: businessId,
                source: source
            });
        }

        // Handle business connections removal (DELETE /websocket/business-connections)
        if (path === '/websocket/business-connections' && httpMethod === 'DELETE') {
            const authHeader = headers.authorization || headers.Authorization;
            const userId = getUserIdFromToken(authHeader);
            
            if (!userId) {
                return createResponse(401, {
                    success: false,
                    message: 'Invalid or missing authorization token'
                });
            }

            const body = JSON.parse(event.body || '{}');
            const { businessId, source, connectionType } = body;

            if (!businessId) {
                return createResponse(400, {
                    success: false,
                    message: 'Missing required field: businessId'
                });
            }

            // Build filter expression based on connection type
            let filterExpression = 'userId = :userId OR attribute_not_exists(userId)';
            const expressionAttributeValues = {
                ':businessPK': `BUSINESS#${businessId}`,
                ':userId': userId
            };

            // If connectionType is specified, filter by it
            if (connectionType) {
                filterExpression += ' AND connectionType = :connType';
                expressionAttributeValues[':connType'] = connectionType;
            }

            // Query all matching connections for this business
            const queryParams = {
                TableName: WEBSOCKET_CONNECTIONS_TABLE,
                IndexName: 'GSI1',
                KeyConditionExpression: 'GSI1PK = :businessPK',
                FilterExpression: filterExpression,
                ExpressionAttributeValues: expressionAttributeValues
            };

            const queryResult = await dynamodb.send(new QueryCommand(queryParams));
            const connectionsToDelete = queryResult.Items || [];

            // Delete each connection
            let deletedCount = 0;
            for (const connection of connectionsToDelete) {
                try {
                    await dynamodb.send(new DeleteCommand({
                        TableName: WEBSOCKET_CONNECTIONS_TABLE,
                        Key: {
                            PK: connection.PK,
                            SK: connection.SK
                        }
                    }));
                    deletedCount++;
                } catch (deleteError) {
                    console.error('Error deleting connection:', connection.PK, deleteError);
                }
            }

            console.log(`✅ Removed ${deletedCount} WebSocket connections for business: ${businessId} (type: ${connectionType || 'all'})`);

            return createResponse(200, {
                success: true,
                message: `Successfully removed ${deletedCount} WebSocket connections`,
                businessId: businessId,
                deletedCount: deletedCount,
                connectionType: connectionType || 'all',
                source: source || 'app_logout'
            });
        }

        // Handle listing business connections (GET /websocket/business-connections)
        if (path === '/websocket/business-connections' && httpMethod === 'GET') {
            const authHeader = headers.authorization || headers.Authorization;
            const userId = getUserIdFromToken(authHeader);
            
            if (!userId) {
                return createResponse(401, {
                    success: false,
                    message: 'Invalid or missing authorization token'
                });
            }

            const businessId = queryStringParameters?.businessId;

            if (!businessId) {
                return createResponse(400, {
                    success: false,
                    message: 'Missing query parameter: businessId'
                });
            }

            // Query all connections for this business
            const queryParams = {
                TableName: WEBSOCKET_CONNECTIONS_TABLE,
                IndexName: 'GSI1',
                KeyConditionExpression: 'GSI1PK = :businessPK',
                ExpressionAttributeValues: {
                    ':businessPK': `BUSINESS#${businessId}`
                }
            };

            const queryResult = await dynamodb.send(new QueryCommand(queryParams));
            const connections = queryResult.Items || [];

            // Filter active connections and categorize them
            const currentTime = Math.floor(Date.now() / 1000);
            const activeConnections = connections.filter(conn => {
                return conn.ttl && conn.ttl > currentTime && conn.isActive !== false;
            });

            // Separate real and virtual connections
            const realConnections = activeConnections.filter(conn => 
                conn.connectionType === 'REAL' || (!conn.connectionType && !conn.isVirtualConnection)
            );
            const virtualConnections = activeConnections.filter(conn => 
                conn.connectionType === 'VIRTUAL' || conn.isVirtualConnection || conn.isLoginTracking
            );

            return createResponse(200, {
                success: true,
                businessId: businessId,
                summary: {
                    totalConnections: connections.length,
                    activeConnections: activeConnections.length,
                    realConnections: realConnections.length,
                    virtualConnections: virtualConnections.length
                },
                connections: {
                    real: realConnections.map(conn => ({
                        connectionId: conn.connectionId,
                        entityType: conn.entityType,
                        connectedAt: conn.connectedAt,
                        lastHeartbeat: conn.lastHeartbeat,
                        userId: conn.userId
                    })),
                    virtual: virtualConnections.map(conn => ({
                        connectionId: conn.connectionId,
                        entityType: conn.entityType,
                        connectedAt: conn.connectedAt,
                        source: conn.source || 'unknown',
                        userId: conn.userId,
                        isLoginTracking: conn.isLoginTracking || false
                    }))
                }
            });
        }

        // Handle comprehensive business status (GET /websocket/business-status)
        if (path === '/websocket/business-status' && httpMethod === 'GET') {
            const authHeader = headers.authorization || headers.Authorization;
            const userId = getUserIdFromToken(authHeader);
            
            if (!userId) {
                return createResponse(401, {
                    success: false,
                    message: 'Invalid or missing authorization token'
                });
            }

            const businessId = queryStringParameters?.businessId;

            if (!businessId) {
                return createResponse(400, {
                    success: false,
                    message: 'Missing query parameter: businessId'
                });
            }

            const status = await getBusinessConnectionStatus(businessId);

            return createResponse(200, {
                success: true,
                ...status,
                timestamp: new Date().toISOString()
            });
        }

        // Handle stale connection cleanup (POST /websocket/cleanup-stale)
        if (path === '/websocket/cleanup-stale' && httpMethod === 'POST') {
            const authHeader = headers.authorization || headers.Authorization;
            const userId = getUserIdFromToken(authHeader);
            
            if (!userId) {
                return createResponse(401, {
                    success: false,
                    message: 'Invalid or missing authorization token'
                });
            }

            const cleanupResult = await cleanupStaleConnections();

            return createResponse(200, {
                success: true,
                message: 'Stale connection cleanup completed',
                ...cleanupResult,
                timestamp: new Date().toISOString()
            });
        }

        // Handle connection heartbeat update (POST /websocket/heartbeat)
        if (path === '/websocket/heartbeat' && httpMethod === 'POST') {
            const authHeader = headers.authorization || headers.Authorization;
            const userId = getUserIdFromToken(authHeader);
            
            if (!userId) {
                return createResponse(401, {
                    success: false,
                    message: 'Invalid or missing authorization token'
                });
            }

            const body = JSON.parse(event.body || '{}');
            const { connectionId, businessId } = body;

            if (!connectionId) {
                return createResponse(400, {
                    success: false,
                    message: 'Missing required field: connectionId'
                });
            }

            // Update connection heartbeat
            const updateParams = {
                TableName: WEBSOCKET_CONNECTIONS_TABLE,
                Key: {
                    PK: `CONNECTION#${connectionId}`,
                    SK: `CONNECTION#${connectionId}`
                },
                UpdateExpression: 'SET lastHeartbeat = :timestamp, lastActivity = :activity, #ttl = :ttl',
                ExpressionAttributeNames: {
                    '#ttl': 'ttl'
                },
                ExpressionAttributeValues: {
                    ':timestamp': new Date().toISOString(),
                    ':activity': new Date().toISOString(),
                    ':ttl': Math.floor(Date.now() / 1000) + 3600 // Extend TTL by 1 hour
                }
            };

            await dynamodb.send(new UpdateCommand(updateParams));

            console.log(`✅ Updated heartbeat for connection: ${connectionId}`);

            return createResponse(200, {
                success: true,
                message: 'Connection heartbeat updated successfully',
                connectionId: connectionId,
                businessId: businessId,
                timestamp: new Date().toISOString()
            });
        }

        return createResponse(404, {
            success: false,
            message: 'Endpoint not found',
            path: path,
            method: httpMethod
        });

    } catch (error) {
        console.error('Error in WebSocket Connection Manager:', error);
        return createResponse(500, {
            success: false,
            message: 'Internal server error',
            error: error.message
        });
    }
};
