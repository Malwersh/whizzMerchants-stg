/**
 * WebSocket Table Schema Adapter
 * Adapts our WebSocket operations to work with the existing table schemas
 */

const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { 
    DynamoDBDocumentClient, 
    PutCommand, 
    DeleteCommand, 
    QueryCommand, 
    ScanCommand, 
    UpdateCommand,
    GetCommand
} = require('@aws-sdk/lib-dynamodb');

const dynamodb = DynamoDBDocumentClient.from(new DynamoDBClient());

/**
 * Adapter for WebSocket connections table operations
 * Maps our PK/SK schema to the existing connectionId schema
 */
class WebSocketConnectionsAdapter {
    constructor(tableName = process.env.WEBSOCKET_CONNECTIONS_TABLE) {
        if (!tableName) {
            throw new Error('Missing required WebSocket connections table name (set WEBSOCKET_CONNECTIONS_TABLE or pass tableName)');
        }
        this.tableName = tableName;
    }

    /**
     * Create a connection record compatible with existing schema
     */
    async createConnection(connectionData) {
        const {
            connectionId,
            entityType,
            userId,
            businessId,
            connectedAt,
            ttl,
            isActive = true,
            connectionType = 'REAL',
            lastHeartbeat,
            isLoginTracking = false,
            source
        } = connectionData;

        // Create GSI1PK for proper querying by order-stream-processor
        let gsi1PK = 'USER#' + (userId || businessId);
        if (entityType === 'business' || entityType === 'merchant') {
            gsi1PK = 'BUSINESS#' + (businessId || userId);
        } else if (entityType === 'driver') {
            gsi1PK = 'DRIVER#' + (userId || businessId);
        } else if (entityType === 'customer') {
            gsi1PK = 'USER#' + (userId || businessId);
        }

        const item = {
            connectionId, // Primary key for existing schema
            userId: userId || businessId, // Use businessId as userId for merchants
            connectedAt: connectedAt || new Date().toISOString(),
            entityType,
            ttl,
            isActive,
            connectionType,
            lastHeartbeat: lastHeartbeat || new Date().toISOString(),
            GSI1PK: gsi1PK, // 🔥 CRITICAL: Add GSI1PK for order-stream-processor queries
            GSI1SK: `CONNECTION#${connectionId}`, // GSI1SK for unique sorting
            ...(businessId && { businessId }),
            ...(isLoginTracking && { isLoginTracking }),
            ...(source && { source })
        };

        const params = {
            TableName: this.tableName,
            Item: item
        };

        console.log(`✅ Creating connection with GSI1PK: ${gsi1PK} for entityType: ${entityType}`);
        return await dynamodb.send(new PutCommand(params));
    }

    /**
     * Delete a connection by connectionId
     */
    async deleteConnection(connectionId) {
        const params = {
            TableName: this.tableName,
            Key: {
                connectionId
            }
        };

        return await dynamodb.send(new DeleteCommand(params));
    }

    /**
     * Update connection heartbeat
     */
    async updateHeartbeat(connectionId) {
        const params = {
            TableName: this.tableName,
            Key: {
                connectionId
            },
            UpdateExpression: 'SET lastHeartbeat = :timestamp, #ttl = :ttl',
            ExpressionAttributeNames: {
                '#ttl': 'ttl'
            },
            ExpressionAttributeValues: {
                ':timestamp': new Date().toISOString(),
                ':ttl': Math.floor(Date.now() / 1000) + (24 * 60 * 60) // 24 hours TTL
            }
        };

        return await dynamodb.send(new UpdateCommand(params));
    }

    /**
     * Get a connection by connectionId
     */
    async getConnection(connectionId) {
        const params = {
            TableName: this.tableName,
            Key: {
                connectionId
            }
        };

        const result = await dynamodb.send(new GetCommand(params));
        return result.Item || null;
    }

    /**
     * Update a connection with new data
     */
    async updateConnection(connectionId, updates) {
        const {
            isActive,
            disconnectedAt,
            lastActivity,
            lastHeartbeat,
            disconnectReason,
            ...otherUpdates
        } = updates;

        // Build dynamic update expression
        const updateExpressions = [];
        const expressionAttributeValues = {};
        const expressionAttributeNames = {};

        if (isActive !== undefined) {
            updateExpressions.push('isActive = :isActive');
            expressionAttributeValues[':isActive'] = isActive;
        }

        if (disconnectedAt) {
            updateExpressions.push('disconnectedAt = :disconnectedAt');
            expressionAttributeValues[':disconnectedAt'] = disconnectedAt;
        }

        if (lastActivity) {
            updateExpressions.push('lastActivity = :lastActivity');
            expressionAttributeValues[':lastActivity'] = lastActivity;
        }

        if (lastHeartbeat) {
            updateExpressions.push('lastHeartbeat = :lastHeartbeat');
            expressionAttributeValues[':lastHeartbeat'] = lastHeartbeat;
        }

        if (disconnectReason) {
            updateExpressions.push('disconnectReason = :disconnectReason');
            expressionAttributeValues[':disconnectReason'] = disconnectReason;
        }

        // Handle other updates
        Object.entries(otherUpdates).forEach(([key, value]) => {
            if (value !== undefined) {
                updateExpressions.push(`${key} = :${key}`);
                expressionAttributeValues[`:${key}`] = value;
            }
        });

        if (updateExpressions.length === 0) {
            throw new Error('No valid updates provided');
        }

        const params = {
            TableName: this.tableName,
            Key: {
                connectionId
            },
            UpdateExpression: `SET ${updateExpressions.join(', ')}`,
            ExpressionAttributeValues: expressionAttributeValues
        };

        if (Object.keys(expressionAttributeNames).length > 0) {
            params.ExpressionAttributeNames = expressionAttributeNames;
        }

        return await dynamodb.send(new UpdateCommand(params));
    }

    /**
     * Get connections for a business using the existing userId-connectedAt-index
     * Adapted to work with current table schema: connectionId (PK), userId-connectedAt-index (GSI)
     */
    async getBusinessConnections(businessId, connectionType = null) {
        const params = {
            TableName: this.tableName,
            IndexName: 'userId-connectedAt-index',
            KeyConditionExpression: 'userId = :businessId',
            ExpressionAttributeValues: {
                ':businessId': businessId
            }
        };

        // Add filter for connection type if specified
        if (connectionType) {
            params.FilterExpression = 'connectionType = :connType AND isActive = :active';
            params.ExpressionAttributeValues[':connType'] = connectionType;
            params.ExpressionAttributeValues[':active'] = true;
        } else {
            params.FilterExpression = 'isActive = :active';
            params.ExpressionAttributeValues[':active'] = true;
        }

        const result = await dynamodb.send(new QueryCommand(params));
        
        // Filter out expired connections
        const currentTime = Math.floor(Date.now() / 1000);
        const activeConnections = (result.Items || []).filter(conn => 
            !conn.ttl || conn.ttl > currentTime
        );
        
        return activeConnections;
    }

    /**
     * Get all connections (for cleanup operations)
     */
    async getAllConnections(filterExpression = null, expressionAttributeValues = {}) {
        const params = {
            TableName: this.tableName
        };

        if (filterExpression) {
            params.FilterExpression = filterExpression;
            params.ExpressionAttributeValues = expressionAttributeValues;
        }

        const result = await dynamodb.send(new ScanCommand(params));
        return result.Items || [];
    }

    /**
     * Delete multiple connections (for cleanup)
     */
    async deleteConnections(connections) {
        const deletePromises = connections.map(connection => 
            this.deleteConnection(connection.connectionId)
        );
        
        return await Promise.allSettled(deletePromises);
    }
}

/**
 * Adapter for WebSocket subscriptions table operations
 */
class WebSocketSubscriptionsAdapter {
    constructor(tableName = process.env.WEBSOCKET_SUBSCRIPTIONS_TABLE) {
        if (!tableName) {
            throw new Error('Missing required WebSocket subscriptions table name (set WEBSOCKET_SUBSCRIPTIONS_TABLE or pass tableName)');
        }
        this.tableName = tableName;
    }

    /**
     * Create a subscription record
     */
    async createSubscription(subscriptionData) {
        const {
            subscriptionId,
            userId,
            topic,
            connectionId,
            createdAt = new Date().toISOString(),
            ttl
        } = subscriptionData;

        const item = {
            subscriptionId, // Primary key
            userId,
            topic,
            connectionId,
            createdAt,
            ...(ttl && { ttl })
        };

        const params = {
            TableName: this.tableName,
            Item: item
        };

        return await dynamodb.send(new PutCommand(params));
    }

    /**
     * Get subscriptions by topic
     */
    async getSubscriptionsByTopic(topic) {
        const params = {
            TableName: this.tableName,
            IndexName: 'topic-createdAt-index',
            KeyConditionExpression: 'topic = :topic',
            ExpressionAttributeValues: {
                ':topic': topic
            }
        };

        const result = await dynamodb.send(new QueryCommand(params));
        return result.Items || [];
    }

    /**
     * Get subscriptions by user
     */
    async getSubscriptionsByUser(userId) {
        const params = {
            TableName: this.tableName,
            IndexName: 'userId-topic-index',
            KeyConditionExpression: 'userId = :userId',
            ExpressionAttributeValues: {
                ':userId': userId
            }
        };

        const result = await dynamodb.send(new QueryCommand(params));
        return result.Items || [];
    }

    /**
     * Delete a subscription
     */
    async deleteSubscription(subscriptionId) {
        const params = {
            TableName: this.tableName,
            Key: {
                subscriptionId
            }
        };

        return await dynamodb.send(new DeleteCommand(params));
    }
}

module.exports = {
    WebSocketConnectionsAdapter,
    WebSocketSubscriptionsAdapter
};
