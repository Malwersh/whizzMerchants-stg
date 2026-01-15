const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { DynamoDBDocumentClient, PutCommand, QueryCommand, DeleteCommand, UpdateCommand, GetCommand, ScanCommand } = require('@aws-sdk/lib-dynamodb');

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
            entityType = 'business',
            platform = 'unknown',
            appVersion = '1.0.0',
            deviceId
        } = options;

        const connectionId = `VIRTUAL_${businessId}_${userId}_${Date.now()}`;
        const currentTime = new Date().toISOString();

        const role = 'merchant';
        const resolvedDeviceId = deviceId || `${platform}_${businessId}_${Date.now()}`;

        const connectionItem = {
            // Primary identifiers (connection-centric)
            connectionId,
            PK: `CONNECTION#${connectionId}`,
            SK: `CONNECTION#${connectionId}`,

            // Business GSI
            GSI1PK: `BUSINESS#${businessId}`,
            GSI1SK: `CONNECTION#${connectionId}`,

            // Core identity
            businessId,
            entityType,
            entityId: businessId,
            userId,
            cognitoSub: userId,
            merchantId: userId,
            role,
            userType: role,

            // Connection status
            authenticated: true,
            status: 'connected',
            isActive: true,
            connectionType: CONNECTION_TYPES.VIRTUAL,

            // Tracking
            connectedAt: currentTime,
            lastActivity: currentTime,
            lastHeartbeat: currentTime,
            lastSeen: currentTime,
            timestamp: currentTime,
            ttl,

            // Device/app
            platform,
            appVersion,
            deviceId: resolvedDeviceId,
            deviceInfo: {},

            // Flags
            isVirtualConnection: true,
            isLoginTracking: true,
            isGuest: false,
            source,
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
 * Create a real WebSocket connection for login tracking
 * This matches the structure used by customer app
 */
async function createRealWebSocketConnection(businessId, userId, options = {}) {
    try {
        const {
            platform = 'ios',
            appVersion = '1.0.0',
            deviceId = `device_${Date.now()}`,
            source = 'merchant_login',
            ttl = Math.floor(Date.now() / 1000) + (24 * 3600) // 24 hours default
        } = options;

        // Generate a real connection ID similar to API Gateway format
        const connectionId = generateConnectionId();
        const currentTime = new Date().toISOString();

        const role = 'merchant';
        const entityType = 'business';

        const connectionItem = {
            // Primary identifiers (connection-centric)
            connectionId,
            PK: `CONNECTION#${connectionId}`,
            SK: `CONNECTION#${connectionId}`,

            // Business GSI
            GSI1PK: `BUSINESS#${businessId}`,
            GSI1SK: `CONNECTION#${connectionId}`,

            // Core identity
            businessId,
            entityType,
            entityId: businessId,
            userId,
            cognitoSub: userId,
            merchantId: userId,
            role,
            userType: role,

            // Connection status
            authenticated: true,
            status: 'connected',
            isActive: true,
            connectionType: CONNECTION_TYPES.REAL,

            // Tracking
            connectedAt: currentTime,
            lastActivity: currentTime,
            lastHeartbeat: currentTime,
            lastSeen: currentTime,
            timestamp: currentTime,
            ttl,

            // Device/app
            platform,
            appVersion,
            deviceId,
            deviceInfo: {},

            // Flags
            isGuest: false,
            source,
        };

        await dynamodb.send(new PutCommand({
            TableName: WEBSOCKET_CONNECTIONS_TABLE,
            Item: connectionItem
        }));

        console.log(`✅ Real WebSocket connection created: ${businessId} (${connectionId})`);
        
        return {
            success: true,
            connectionId,
            businessId,
            userId,
            entityType: 'business',
            platform,
            appVersion,
            deviceId,
            source
        };

    } catch (error) {
        console.error('Error creating real WebSocket connection:', error);
        throw error;
    }
}

/**
 * Generate a connection ID similar to API Gateway format
 */
function generateConnectionId() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    let result = '';
    for (let i = 0; i < 16; i++) {
        result += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    return result + '=';
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
 * Validate business data before creating connections
 */
async function validateBusinessData(businessId, userId) {
    try {
        console.log(`🔍 Validating business data: ${businessId}, user: ${userId}`);
        
        // Query business table to verify this is a valid business
        const businessParams = {
            TableName: process.env.BUSINESSES_TABLE || 'WhizzMerchants_Businesses',
            Key: {
                businessId: businessId
            }
        };

        const businessResult = await dynamodb.send(new GetCommand(businessParams));
        const businessData = businessResult.Item;

        if (!businessData) {
            throw new Error(`Business not found: ${businessId}`);
        }

        // Verify userId matches cognitoUserId
        if (businessData.cognitoUserId !== userId) {
            console.warn(`⚠️ userId mismatch for business ${businessId}:`);
            console.warn(`  - Provided userId: ${userId}`);
            console.warn(`  - Expected cognitoUserId: ${businessData.cognitoUserId}`);
            
            // Use the correct userId from business data
            return {
                valid: true,
                correctedUserId: businessData.cognitoUserId,
                businessName: businessData.businessName,
                email: businessData.email
            };
        }

        console.log(`✅ Business data validated: ${businessData.businessName}`);
        
        return {
            valid: true,
            correctedUserId: userId,
            businessName: businessData.businessName,
            email: businessData.email
        };

    } catch (error) {
        console.error('❌ Business validation failed:', error.message);
        return {
            valid: false,
            error: error.message
        };
    }
}

/**
 * Handle login scenario (create real WebSocket connection like customer app)
 */
async function handleUserLogin(businessId, userId, email, options = {}) {
    try {
        // First validate business data
        const validation = await validateBusinessData(businessId, userId);
        
        if (!validation.valid) {
            throw new Error(`Business validation failed: ${validation.error}`);
        }

        // Use corrected userId if needed
        const correctedUserId = validation.correctedUserId;
        const businessName = validation.businessName;

        console.log(`✅ Creating WebSocket connection for: ${businessName} (${businessId})`);
        console.log(`   User ID: ${correctedUserId}`);
        console.log(`   Email: ${email}`);

        // Extract platform and device info from options
        const {
            platform = 'ios',
            appVersion = '1.0.0',
            deviceId,
            source,
            ...restOptions
        } = options;

        // Create a REAL WebSocket connection instead of virtual
        const result = await createRealWebSocketConnection(businessId, correctedUserId, {
            platform,
            appVersion,
            deviceId: deviceId || `business_${businessId}_${Date.now()}`,
            source: source || 'merchant_login',
            ...restOptions
        });

        console.log(`✅ Real WebSocket connection created for business login: ${businessId} - ${email}`);
        
        return result;

    } catch (error) {
        console.error('Error handling user login:', error);
        throw error;
    }
}

/**
 * Handle logout scenario (update connection states instead of deleting)
 * Following best practices: Preserve connection history for analytics
 */
async function handleUserLogout(businessId, userId, options = {}) {
    try {
        console.log(`🔄 Processing logout for business: ${businessId}, user: ${userId}`);
        
        // First validate business data to get correct userId
        const validation = await validateBusinessData(businessId, userId);
        const correctedUserId = validation.valid ? validation.correctedUserId : userId;
        
        const timestamp = new Date().toISOString();
        let totalUpdated = 0;
        
        // ✅ CORRECT APPROACH: Update connection states instead of deleting
        
        // Step 1: Find all active connections for this business/user
        const connectionsParams = {
            TableName: WEBSOCKET_CONNECTIONS_TABLE,
            IndexName: 'userId-connectedAt-index',
            KeyConditionExpression: 'userId = :userId',
            FilterExpression: 'businessId = :businessId AND isActive = :isActive',
            ExpressionAttributeValues: {
                ':userId': correctedUserId,
                ':businessId': businessId,
                ':isActive': true
            }
        };

        const connectionsResult = await dynamodb.send(new QueryCommand(connectionsParams));
        
        if (connectionsResult.Items && connectionsResult.Items.length > 0) {
            console.log(`Found ${connectionsResult.Items.length} active connection(s) to update`);
            
            // Update each connection to inactive state (preserve records)
            const updatePromises = connectionsResult.Items.map(async (connection) => {
                const updateParams = {
                    TableName: WEBSOCKET_CONNECTIONS_TABLE,
                    Key: {
                        connectionId: connection.connectionId
                    },
                    UpdateExpression: 'SET isActive = :inactive, disconnectedAt = :timestamp, lastActivity = :timestamp, disconnectReason = :reason',
                    ExpressionAttributeValues: {
                        ':inactive': false,
                        ':timestamp': timestamp,
                        ':reason': 'user_logout'
                    }
                };
                
                return dynamodb.send(new UpdateCommand(updateParams));
            });
            
            await Promise.all(updatePromises);
            totalUpdated += connectionsResult.Items.length;
            
            console.log(`✅ Updated ${connectionsResult.Items.length} connection(s) to inactive state`);
        } else {
            console.log('ℹ️ No active connections found to update');
        }

        // Step 2: Update any login tracking entries (if using old approach)
        try {
            const loginTrackingParams = {
                TableName: WEBSOCKET_CONNECTIONS_TABLE,
                FilterExpression: 'businessId = :businessId AND userId = :userId AND isLoginTracking = :isTracking',
                ExpressionAttributeValues: {
                    ':businessId': businessId,
                    ':userId': correctedUserId,
                    ':isTracking': true
                }
            };

            const trackingResult = await dynamodb.send(new ScanCommand(loginTrackingParams));
            
            if (trackingResult.Items && trackingResult.Items.length > 0) {
                const deletePromises = trackingResult.Items.map(async (item) => {
                    return dynamodb.send(new DeleteCommand({
                        TableName: WEBSOCKET_CONNECTIONS_TABLE,
                        Key: {
                            connectionId: item.connectionId
                        }
                    }));
                });
                
                await Promise.all(deletePromises);
                console.log(`✅ Cleaned up ${trackingResult.Items.length} login tracking entries`);
                totalUpdated += trackingResult.Items.length;
            }
        } catch (trackingError) {
            console.warn('Warning: Could not clean up login tracking entries:', trackingError.message);
        }

        console.log(`✅ User logout processed: ${businessId}, updated ${totalUpdated} records`);
        
        return {
            success: true,
            businessId,
            userId: correctedUserId,
            totalUpdated,
            timestamp,
            preservedHistory: true,  // Important: We preserve connection history
            message: 'Connection states updated to inactive, history preserved'
        };

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
    createRealWebSocketConnection,
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
    cleanupBusinessStaleConnections,
    
    // Utilities
    generateConnectionId
};
