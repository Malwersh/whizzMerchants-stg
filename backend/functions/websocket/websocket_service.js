const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { DynamoDBDocumentClient, PutCommand, QueryCommand, DeleteCommand, UpdateCommand, GetCommand } = require('@aws-sdk/lib-dynamodb');

const dynamoDbClient = new DynamoDBClient({ region: process.env.AWS_REGION || 'us-east-1' });
const dynamodb = DynamoDBDocumentClient.from(dynamoDbClient);

const WEBSOCKET_CONNECTIONS_TABLE = process.env.WEBSOCKET_CONNECTIONS_TABLE;
if (!WEBSOCKET_CONNECTIONS_TABLE) {
    throw new Error('Missing required env var: WEBSOCKET_CONNECTIONS_TABLE');
}

/**
 * WebSocket Management Service
 * 
 * Centralized service for managing WebSocket connections, login tracking,
 * and business status integration. This service provides utilities for
 * both real WebSocket connections and virtual login tracking.
 */

/**
 * Connection Types
 */
const CONNECTION_TYPES = {
    REAL: 'REAL',        // Actual WebSocket connection
    VIRTUAL: 'VIRTUAL'   // Login tracking / virtual connection
};

/**
 * Business Status Types
 */
const BUSINESS_STATUS = {
    ONLINE: 'online',           // Has real connection + accepting orders
    AVAILABLE: 'available',     // Has login tracking + accepting orders
    LOGGED_IN: 'logged_in',     // Has connections but not accepting orders
    OFFLINE: 'offline'          // No connections
};

/**
 * Create a virtual connection for login tracking
 */
async function createVirtualConnection(businessId, userId, options = {}) {
    try {
        const {
            source = 'app_login',
            ttl = Math.floor(Date.now() / 1000) + 3600, // 1 hour default
            entityType = 'business'
        } = options;

        const connectionId = `VIRTUAL_${businessId}_${userId}_${Date.now()}`;
        const currentTime = new Date().toISOString();

        const connectionItem = {
            PK: `CONNECTION#${connectionId}`,
            SK: `CONNECTION#${connectionId}`,
            connectionId,
            businessId,
            userId,
            entityType,
            connectionType: CONNECTION_TYPES.VIRTUAL,
            connectedAt: currentTime,
            lastActivity: currentTime,
            ttl,
            isActive: true,
            isVirtualConnection: true,
            isLoginTracking: true,
            source,
            GSI1PK: `BUSINESS#${businessId}`,
            GSI1SK: `CONNECTION#${connectionId}`
        };

        await dynamodb.send(new PutCommand({
            TableName: WEBSOCKET_CONNECTIONS_TABLE,
            Item: connectionItem
        }));

        console.log(`✅ Virtual connection created: ${businessId} (${source})`);
        
        return {
            success: true,
            connectionId,
            businessId,
            userId,
            source
        };

    } catch (error) {
        console.error('Error creating virtual connection:', error);
        throw error;
    }
}

/**
 * Remove all connections for a business (logout scenario)
 */
async function removeBusinessConnections(businessId, userId, options = {}) {
    try {
        const {
            connectionType = null, // null = all types, or specify REAL/VIRTUAL
            source = 'app_logout'
        } = options;

        // Build filter expression
        let filterExpression = 'userId = :userId OR attribute_not_exists(userId)';
        const expressionAttributeValues = {
            ':businessPK': `BUSINESS#${businessId}`,
            ':userId': userId
        };

        if (connectionType) {
            filterExpression += ' AND connectionType = :connType';
            expressionAttributeValues[':connType'] = connectionType;
        }

        // Query all matching connections
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

        console.log(`✅ Removed ${deletedCount} connections for business: ${businessId} (type: ${connectionType || 'all'})`);

        return {
            success: true,
            businessId,
            deletedCount,
            connectionType: connectionType || 'all',
            source
        };

    } catch (error) {
        console.error('Error removing business connections:', error);
        throw error;
    }
}

/**
 * Get all active connections for a business
 */
async function getBusinessConnections(businessId) {
    try {
        const queryParams = {
            TableName: WEBSOCKET_CONNECTIONS_TABLE,
            IndexName: 'GSI1',
            KeyConditionExpression: 'GSI1PK = :businessPK',
            ExpressionAttributeValues: {
                ':businessPK': `BUSINESS#${businessId}`
            }
        };

        const result = await dynamodb.send(new QueryCommand(queryParams));
        const connections = result.Items || [];

        // Filter active connections
        const currentTime = Math.floor(Date.now() / 1000);
        const activeConnections = connections.filter(conn => 
            !conn.ttl || conn.ttl > currentTime
        );

        // Categorize connections
        const realConnections = activeConnections.filter(conn => 
            conn.connectionType === CONNECTION_TYPES.REAL || 
            (!conn.connectionType && !conn.isVirtualConnection)
        );

        const virtualConnections = activeConnections.filter(conn => 
            conn.connectionType === CONNECTION_TYPES.VIRTUAL || 
            conn.isVirtualConnection || 
            conn.isLoginTracking
        );

        return {
            total: activeConnections.length,
            real: realConnections,
            virtual: virtualConnections,
            summary: {
                realCount: realConnections.length,
                virtualCount: virtualConnections.length,
                hasRealTimeConnection: realConnections.length > 0,
                hasLoginTracking: virtualConnections.length > 0
            }
        };

    } catch (error) {
        console.error('Error getting business connections:', error);
        throw error;
    }
}

/**
 * Get comprehensive business status
 */
async function getBusinessStatus(businessId) {
    try {
        // Get connections
        const connections = await getBusinessConnections(businessId);

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

        // Determine overall status
        const acceptingOrders = businessData.acceptingOrders || false;
        const hasRealConnection = connections.summary.hasRealTimeConnection;
        const hasLoginTracking = connections.summary.hasLoginTracking;

        let overallStatus;
        if (hasRealConnection && acceptingOrders) {
            overallStatus = BUSINESS_STATUS.ONLINE;
        } else if (hasLoginTracking && acceptingOrders) {
            overallStatus = BUSINESS_STATUS.AVAILABLE;
        } else if (hasLoginTracking || hasRealConnection) {
            overallStatus = BUSINESS_STATUS.LOGGED_IN;
        } else {
            overallStatus = BUSINESS_STATUS.OFFLINE;
        }

        return {
            businessId,
            overallStatus,
            acceptingOrders,
            lastStatusUpdate: businessData.lastStatusUpdate,
            connections: {
                realTime: {
                    connected: hasRealConnection,
                    count: connections.summary.realCount,
                    details: connections.real.map(conn => ({
                        connectionId: conn.connectionId,
                        connectedAt: conn.connectedAt,
                        lastHeartbeat: conn.lastHeartbeat,
                        userId: conn.userId
                    }))
                },
                loginTracking: {
                    active: hasLoginTracking,
                    count: connections.summary.virtualCount,
                    details: connections.virtual.map(conn => ({
                        trackingId: conn.connectionId,
                        connectedAt: conn.connectedAt,
                        userId: conn.userId,
                        source: conn.source
                    }))
                }
            }
        };

    } catch (error) {
        console.error('Error getting business status:', error);
        throw error;
    }
}

/**
 * Update business online/offline status
 */
async function updateBusinessAcceptingOrders(businessId, acceptingOrders) {
    try {
        const updateParams = {
            TableName: process.env.BUSINESSES_TABLE || 'order-receiver-businesses-dev',
            Key: {
                businessId: businessId
            },
            UpdateExpression: 'SET acceptingOrders = :status, lastStatusUpdate = :timestamp',
            ExpressionAttributeValues: {
                ':status': acceptingOrders,
                ':timestamp': new Date().toISOString()
            }
        };

        await dynamodb.send(new UpdateCommand(updateParams));

        console.log(`✅ Business accepting orders updated: ${businessId} -> ${acceptingOrders}`);

        return {
            success: true,
            businessId,
            acceptingOrders,
            timestamp: new Date().toISOString()
        };

    } catch (error) {
        console.error('Error updating business accepting orders:', error);
        throw error;
    }
}

/**
 * Set business availability (combines login tracking + accepting orders)
 */
async function setBusinessAvailability(businessId, userId, isAvailable, options = {}) {
    try {
        const { source = 'status_toggle' } = options;

        // Update business accepting orders status
        await updateBusinessAcceptingOrders(businessId, isAvailable);

        if (isAvailable) {
            // Create virtual connection for tracking if going online
            await createVirtualConnection(businessId, userId, {
                source: `${source}_online`,
                ...options
            });
        } else {
            // Remove virtual connections if going offline
            await removeBusinessConnections(businessId, userId, {
                connectionType: CONNECTION_TYPES.VIRTUAL,
                source: `${source}_offline`
            });
        }

        console.log(`✅ Business availability updated: ${businessId} -> ${isAvailable ? 'available' : 'unavailable'}`);

        return {
            success: true,
            businessId,
            isAvailable,
            source,
            timestamp: new Date().toISOString()
        };

    } catch (error) {
        console.error('Error setting business availability:', error);
        throw error;
    }
}

/**
 * Clean up stale connections across the system
 */
async function cleanupStaleConnections() {
    try {
        console.log('🧹 Starting comprehensive stale connection cleanup...');

        const scanParams = {
            TableName: process.env.WEBSOCKET_CONNECTIONS_TABLE
        };

        const result = await dynamodb.send(new ScanCommand(scanParams));
        const connections = result.Items || [];

        // Find expired connections
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
            cleanedConnections: cleanedCount,
            timestamp: new Date().toISOString()
        };

    } catch (error) {
        console.error('Error during stale connection cleanup:', error);
        throw error;
    }
}

/**
 * Update connection heartbeat
 */
async function updateConnectionHeartbeat(connectionId) {
    try {
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
        return { success: true, connectionId };

    } catch (error) {
        console.warn('Warning: Could not update connection heartbeat:', error.message);
        return { success: false, connectionId, error: error.message };
    }
}

/**
 * Handle login scenario (create login tracking)
 */
async function handleUserLogin(businessId, userId, email, options = {}) {
    try {
        const result = await createVirtualConnection(businessId, userId, {
            source: 'user_login',
            ...options
        });

        console.log(`✅ User login tracked: ${businessId} - ${email}`);
        
        return result;

    } catch (error) {
        console.error('Error handling user login:', error);
        throw error;
    }
}

/**
 * Handle logout scenario (remove login tracking)
 */
async function handleUserLogout(businessId, userId, options = {}) {
    try {
        console.log(`🔄 Processing logout for business: ${businessId}, user: ${userId}`);
        
        // Remove all connections (both virtual and real) for this business/user
        const result = await removeBusinessConnections(businessId, userId, {
            source: 'user_logout',
            connectionType: null, // Remove all types of connections
            ...options
        });

        console.log(`✅ User logout processed: ${businessId}, removed ${result.deletedCount} connections`);
        
        return result;

    } catch (error) {
        console.error('Error handling user logout:', error);
        throw error;
    }
}

/**
 * Enhanced logout cleanup for all user connections
 */
async function performLogoutCleanup(businessId, userId, options = {}) {
    try {
        console.log(`🧹 Starting comprehensive logout cleanup for business: ${businessId}, user: ${userId}`);
        
        const { force = false, cleanupStale = true } = options;
        
        let totalCleaned = 0;
        
        // Step 1: Remove login tracking connections
        const virtualResult = await removeBusinessConnections(businessId, userId, {
            connectionType: CONNECTION_TYPES.VIRTUAL,
            source: 'logout_cleanup_virtual'
        });
        totalCleaned += virtualResult.deletedCount;
        
        // Step 2: Optionally remove real WebSocket connections (forced logout)
        if (force) {
            const realResult = await removeBusinessConnections(businessId, userId, {
                connectionType: CONNECTION_TYPES.REAL,
                source: 'logout_cleanup_real_forced'
            });
            totalCleaned += realResult.deletedCount;
        }
        
        // Step 3: Clean up any stale connections if requested
        if (cleanupStale) {
            const staleResult = await cleanupBusinessStaleConnections(businessId);
            totalCleaned += staleResult.cleanedCount;
        }
        
        console.log(`✅ Logout cleanup completed: ${businessId}, total cleaned: ${totalCleaned}`);
        
        return {
            success: true,
            businessId,
            userId,
            totalCleaned,
            cleanupDetails: {
                virtualConnections: virtualResult.deletedCount,
                realConnections: force ? virtualResult.deletedCount : 0,
                staleConnections: cleanupStale ? 0 : 0
            },
            timestamp: new Date().toISOString()
        };
        
    } catch (error) {
        console.error('Error performing logout cleanup:', error);
        throw error;
    }
}

/**
 * Clean up stale connections for a specific business
 */
async function cleanupBusinessStaleConnections(businessId) {
    try {
        console.log(`🧹 Cleaning stale connections for business: ${businessId}`);
        
        // Get all connections for this business
        const connections = await getBusinessConnections(businessId);
        const allConnections = [...connections.real, ...connections.virtual];
        
        // Find expired connections
        const currentTime = Math.floor(Date.now() / 1000);
        const expiredConnections = allConnections.filter(conn => 
            conn.ttl && conn.ttl < currentTime
        );
        
        console.log(`Found ${expiredConnections.length} expired connections for business: ${businessId}`);
        
        // Remove expired connections
        let cleanedCount = 0;
        for (const connection of expiredConnections) {
            try {
                await dynamodb.send(new DeleteCommand({
                    TableName: WEBSOCKET_CONNECTIONS_TABLE,
                    Key: {
                        PK: connection.PK || `CONNECTION#${connection.connectionId}`,
                        SK: connection.SK || `CONNECTION#${connection.connectionId}`
                    }
                }));
                cleanedCount++;
                console.log(`🗑️ Removed expired connection: ${connection.connectionId}`);
            } catch (deleteError) {
                console.error('Error deleting expired connection:', connection.connectionId, deleteError);
            }
        }
        
        console.log(`✅ Cleaned ${cleanedCount} stale connections for business: ${businessId}`);
        
        return {
            businessId,
            totalConnections: allConnections.length,
            expiredConnections: expiredConnections.length,
            cleanedCount
        };
        
    } catch (error) {
        console.error('Error cleaning business stale connections:', error);
        throw error;
    }
}

module.exports = {
    // Constants
    CONNECTION_TYPES,
    BUSINESS_STATUS,
    
    // Core connection management
    createVirtualConnection,
    removeBusinessConnections,
    getBusinessConnections,
    getBusinessStatus,
    
    // Business status management
    updateBusinessAcceptingOrders,
    setBusinessAvailability,
    
    // System maintenance
    cleanupStaleConnections,
    updateConnectionHeartbeat,
    
    // User flow handlers
    handleUserLogin,
    handleUserLogout,
    performLogoutCleanup,
    cleanupBusinessStaleConnections
};
