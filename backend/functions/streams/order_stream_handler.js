// Version: 2.0.1 - Fixed GSI1 index query for merchant WebSocket connections
const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { DynamoDBDocumentClient, QueryCommand, DeleteCommand, GetCommand } = require('@aws-sdk/lib-dynamodb');
const { SNSClient, PublishCommand } = require('@aws-sdk/client-sns');
const { ApiGatewayManagementApiClient, PostToConnectionCommand } = require('@aws-sdk/client-apigatewaymanagementapi');
const { unmarshall } = require('@aws-sdk/util-dynamodb');

const ddbClient = new DynamoDBClient({});
const dynamodb = DynamoDBDocumentClient.from(ddbClient);
const sns = new SNSClient({});
const apiGateway = new ApiGatewayManagementApiClient({
    endpoint: process.env.WEBSOCKET_ENDPOINT
});

/**
 * Lambda function to process DynamoDB streams from OrdersTable
 * Handles order events and sends real-time notifications to merchants
 */
exports.handler = async (event) => {
    console.log('Order stream event received:', JSON.stringify(event, null, 2));
    
    const promises = event.Records.map(async (record) => {
        try {
            await processRecord(record);
        } catch (error) {
            console.error('Error processing record:', error);
            // Don't throw - we want to process other records
        }
    });
    
    await Promise.all(promises);
    
    return { statusCode: 200, body: 'Stream processed successfully' };
};

/**
 * Process individual DynamoDB stream record
 */
async function processRecord(record) {
    console.log('Processing record:', JSON.stringify(record, null, 2));
    
    const eventName = record.eventName;
    const dynamoRecord = record.dynamodb;
    
    switch (eventName) {
        case 'INSERT':
            await handleNewOrder(dynamoRecord.NewImage);
            break;
        case 'MODIFY':
            await handleOrderUpdate(dynamoRecord.NewImage, dynamoRecord.OldImage);
            break;
        case 'REMOVE':
            await handleOrderDeletion(dynamoRecord.OldImage);
            break;
        default:
            console.log('Unhandled event type:', eventName);
    }
}

/**
 * Handle new order creation
 */
async function handleNewOrder(newImage) {
    try {
        const order = unmarshallDynamoDBImage(newImage);
        console.log('New order created:', order.orderId);
        
        // Use storeId instead of businessId (actual field in WizzOrders table)
        const merchantId = order.storeId || order.businessId;
        
        // Send real-time notification to merchant
        await notifyMerchant(merchantId, {
            type: 'NEW_ORDER',
            orderId: order.orderId,
            order: order,
            timestamp: new Date().toISOString()
        });
        
        // Send push notification
        await sendPushNotification(merchantId, {
            title: 'طلب جديد!',
            body: `طلب جديد من ${order.customerName || 'عميل'}`,
            data: {
                orderId: order.orderId,
                type: 'NEW_ORDER'
            }
        });
        
        // Publish to SNS topic for additional integrations
        await publishOrderEvent({
            eventType: 'ORDER_CREATED',
            orderId: order.orderId,
            businessId: merchantId,
            order: order
        });
        
    } catch (error) {
        console.error('Error handling new order:', error);
    }
}

/**
 * Handle order status updates
 */
async function handleOrderUpdate(newImage, oldImage) {
    try {
        const newOrder = unmarshallDynamoDBImage(newImage);
        const oldOrder = unmarshallDynamoDBImage(oldImage);
        
        // Use storeId instead of businessId (actual field in WizzOrders table)
        const merchantId = newOrder.storeId || newOrder.businessId;
        
        // Check if status changed
        if (newOrder.status !== oldOrder.status) {
            console.log('Order status changed:', newOrder.orderId, oldOrder.status, '->', newOrder.status);
            
            // Notify merchant about status change
            await notifyMerchant(merchantId, {
                type: 'ORDER_STATUS_CHANGED',
                orderId: newOrder.orderId,
                oldStatus: oldOrder.status,
                newStatus: newOrder.status,
                order: newOrder,
                timestamp: new Date().toISOString()
            });
            
            // Send push notification for important status changes
            if (['confirmed', 'rejected', 'completed', 'cancelled'].includes(newOrder.status)) {
                await sendPushNotification(merchantId, {
                    title: 'تحديث الطلب',
                    body: `تم تحديث حالة الطلب ${newOrder.orderId} إلى ${getStatusInArabic(newOrder.status)}`,
                    data: {
                        orderId: newOrder.orderId,
                        type: 'ORDER_STATUS_UPDATE',
                        status: newOrder.status
                    }
                });
            }
        }
        
        // Check if estimated time changed
        if (newOrder.estimatedDeliveryTime !== oldOrder.estimatedDeliveryTime) {
            await notifyMerchant(merchantId, {
                type: 'ESTIMATED_TIME_UPDATED',
                orderId: newOrder.orderId,
                newEstimatedTime: newOrder.estimatedDeliveryTime,
                timestamp: new Date().toISOString()
            });
        }
        
    } catch (error) {
        console.error('Error handling order update:', error);
    }
}

/**
 * Handle order deletion
 */
async function handleOrderDeletion(oldImage) {
    try {
        const order = unmarshallDynamoDBImage(oldImage);
        console.log('Order deleted:', order.orderId);
        
        // Use storeId instead of businessId (actual field in WizzOrders table)
        const merchantId = order.storeId || order.businessId;
        
        await notifyMerchant(merchantId, {
            type: 'ORDER_DELETED',
            orderId: order.orderId,
            timestamp: new Date().toISOString()
        });
        
    } catch (error) {
        console.error('Error handling order deletion:', error);
    }
}

/**
 * Send real-time notification to merchant via WebSocket
 */
async function notifyMerchant(businessId, message) {
    try {
        // Get active connections for this business
        const connections = await getActiveConnections(businessId);
        
        if (connections.length === 0) {
            console.log('No active connections for business:', businessId);
            return;
        }
        
        const messagePayload = JSON.stringify(message);
        
        const promises = connections.map(async (connectionId) => {
            try {
                const command = new PostToConnectionCommand({
                    ConnectionId: connectionId,
                    Data: Buffer.from(messagePayload)
                });
                await apiGateway.send(command);
                
                console.log('Message sent to connection:', connectionId);
            } catch (error) {
                if (error.statusCode === 410 || error.$metadata?.httpStatusCode === 410) {
                    // Connection is stale, remove it
                    await removeConnection(connectionId);
                    console.log('Removed stale connection:', connectionId);
                } else {
                    console.error('Error sending message to connection:', connectionId, error);
                }
            }
        });
        
        await Promise.all(promises);
        
    } catch (error) {
        console.error('Error notifying merchant:', error);
    }
}

/**
 * Get active WebSocket connections for a business
 */
async function getActiveConnections(businessId) {
    try {
        // Query using GSI1 index with GSI1PK key
        // GSI1PK format: BUSINESS#<businessId>
        const command = new QueryCommand({
            TableName: process.env.CONNECTIONS_TABLE,
            IndexName: 'GSI1',
            KeyConditionExpression: 'GSI1PK = :gsi1pk',
            ExpressionAttributeValues: {
                ':gsi1pk': `BUSINESS#${businessId}`
            }
        });
        
        const result = await dynamodb.send(command);
        
        // Extract connectionId from each item
        // PK format is CONNECTION#<connectionId>
        if (result.Items && result.Items.length > 0) {
            return result.Items.map(item => {
                // Extract connectionId from PK (format: CONNECTION#<connectionId>)
                const connectionId = item.PK?.replace('CONNECTION#', '') || item.connectionId;
                console.log('Found connection:', connectionId, 'for business:', businessId);
                return connectionId;
            });
        }
        
        console.log('No active connections found for business:', businessId);
        return [];
        
    } catch (error) {
        console.error('Error getting active connections:', error);
        return [];
    }
}

/**
 * Remove stale connection from database
 */
async function removeConnection(connectionId) {
    try {
        // Use the correct PK/SK format for the connections table
        const command = new DeleteCommand({
            TableName: process.env.CONNECTIONS_TABLE,
            Key: {
                PK: `CONNECTION#${connectionId}`,
                SK: `CONNECTION#${connectionId}`
            }
        });
        await dynamodb.send(command);
        console.log('Successfully removed stale connection:', connectionId);
    } catch (error) {
        console.error('Error removing connection:', connectionId, error);
    }
}

/**
 * Send push notification to merchant
 */
async function sendPushNotification(businessId, notification) {
    try {
        // Get merchant's FCM token
        const command = new GetCommand({
            TableName: process.env.BUSINESSES_TABLE,
            Key: { businessId }
        });
        const merchant = await dynamodb.send(command);
        
        if (!merchant.Item || !merchant.Item.fcmToken) {
            console.log('No FCM token found for business:', businessId);
            return;
        }
        
        // Publish to SNS topic for push notifications
        const publishCommand = new PublishCommand({
            TopicArn: process.env.PUSH_NOTIFICATIONS_TOPIC,
            Message: JSON.stringify({
                businessId,
                fcmToken: merchant.Item.fcmToken,
                notification
            }),
            Subject: 'Merchant Push Notification'
        });
        await sns.send(publishCommand);
        
    } catch (error) {
        console.error('Error sending push notification:', error);
    }
}

/**
 * Publish order event to SNS for additional integrations
 */
async function publishOrderEvent(event) {
    try {
        const command = new PublishCommand({
            TopicArn: process.env.ORDER_EVENTS_TOPIC,
            Message: JSON.stringify(event),
            Subject: `Order Event: ${event.eventType}`
        });
        await sns.send(command);
        
    } catch (error) {
        console.error('Error publishing order event:', error);
    }
}

/**
 * Convert DynamoDB image to JavaScript object using AWS SDK v3
 */
function unmarshallDynamoDBImage(image) {
    return unmarshall(image);
}

/**
 * Convert DynamoDB value to JavaScript value (deprecated - using unmarshall)
 */
function unmarshallDynamoDBValue(value) {
    return unmarshall({ value }).value;
}

/**
 * Get status name in Arabic
 */
function getStatusInArabic(status) {
    const statusMap = {
        'pending': 'في الانتظار',
        'confirmed': 'مؤكد',
        'preparing': 'قيد التحضير',
        'ready': 'جاهز',
        'out_for_delivery': 'في الطريق',
        'delivered': 'تم التسليم',
        'completed': 'مكتمل',
        'rejected': 'مرفوض',
        'cancelled': 'ملغي'
    };
    
    return statusMap[status] || status;
}
