/**
 * Central Platform Integration Service
 * Handles communication with the Central Platform for driver assignment
 */

const { LambdaClient, InvokeCommand } = require("@aws-sdk/client-lambda");
const { DynamoDBClient } = require("@aws-sdk/client-dynamodb");
const { DynamoDBDocumentClient, GetCommand, UpdateCommand } = require("@aws-sdk/lib-dynamodb");

// Initialize clients
const lambdaClient = new LambdaClient({ region: "us-east-1" });
const dynamoDBClient = new DynamoDBClient({ region: "us-east-1" });
const dynamoDB = DynamoDBDocumentClient.from(dynamoDBClient);
const {ScanCommand} = require("@aws-sdk/client-dynamodb");

// Central Platform configuration - FIXED to use Wave Dispatch
const CENTRAL_PLATFORM_CONFIG = {
    DRIVER_ASSIGNMENT_FUNCTION: 'WaveDispatchOrchestrator',  // ✅ Fixed: Use Wave Dispatch instead of old system
    WAVE_DISPATCH_FUNCTION: 'WaveDispatchOrchestrator',
    FALLBACK_FUNCTION: 'WhizzCentral-OrderStatusTrigger-prod',  // Keep as fallback
    REGION: 'us-east-1'
};

// WebSocket endpoints for notifications
const WEBSOCKET_ENDPOINTS = {
    USER_APP: process.env.USER_WEBSOCKET_ENDPOINT,
    BUSINESS_APP: process.env.BUSINESS_WEBSOCKET_ENDPOINT
};

/**
 * Trigger driver assignment when order status changes to preparing/ready
 */
async function triggerDriverAssignment(orderId, orderStatus, orderData = null) {
    console.log(`🚚 Triggering driver assignment for order ${orderId} with status: ${orderStatus}`);
    
    try {
        // Only trigger for specific statuses - FIXED: Added 'ready' status 
        const eligibleStatuses = ['preparing', 'ready_for_pickup', 'ready', 'confirmed'];
        if (!eligibleStatuses.includes(orderStatus)) {
            console.log(`📋 Status ${orderStatus} doesn't require driver assignment`);
            return { success: true, skipped: true };
        }

        // Get full order data if not provided
        const order = orderData || await getOrderDetails(orderId);
        if (!order) {
            throw new Error(`Order ${orderId} not found`);
        }

        // Check if order already has a driver
        if (order.driverId) {
            console.log(`📋 Order ${orderId} already has driver ${order.driverId} assigned`);
            return { success: true, skipped: true, reason: 'Driver already assigned' };
        }

        // ⭐ جلب بيانات المطعم من WhizzMerchants_Businesses
        const businessId = order.businessId || order.storeId;
        const businessData = await getBusinessLocation(businessId);
        
        console.log(`🏪 Business data for ${businessId}:`, businessData);

        // Prepare payload for Wave Dispatch System - FIXED format
        const payload = {
            orderId: orderId,
            orderDetails: {
                orderId: orderId,
                status: orderStatus,
                restaurant: {
                    name: order.businessName || order.storeName || businessData?.name || 'مطعم',
                    lat: businessData?.latitude || order.businessLocation?.lat || order.storeLocation?.lat,
                    lng: businessData?.longitude || order.businessLocation?.lng || order.storeLocation?.lng,
                    address: businessData?.address || order.businessLocation?.address || order.storeLocation?.address,
                    region_id: businessData?.regionId || order.businessLocation?.region_id,
                    parent_district_id: businessData?.parent_district_id || order.businessLocation?.parent_district_id,
                    governorate_id: businessData?.governorate_id || order.businessLocation?.governorate_id
                },
                deliveryAddress: {
                    lat: order.deliveryAddress?.lat,
                    lng: order.deliveryAddress?.lng,
                    fullAddress: order.deliveryAddress?.fullAddress || order.deliveryAddress?.address
                },
                customerName: order.customerName || 'عميل',
                customerPhone: order.customerPhone,
                total: order.totalAmount || order.total,
                city: order.city || 'najaf', // Default to najaf where we have the feature flag
                businessId: businessId,
                estimatedPreparationTime: order.estimatedPreparationTime
            },
            triggeredBy: 'business_app',
            timestamp: new Date().toISOString()
        };

        // Try Wave Dispatch first, fallback to old system if needed
        try {
            console.log(`🌊 Attempting Wave Dispatch for order ${orderId}`);
            
            const waveInvokeCommand = new InvokeCommand({
                FunctionName: CENTRAL_PLATFORM_CONFIG.WAVE_DISPATCH_FUNCTION,
                Payload: JSON.stringify(payload),
                InvocationType: 'Event' // Async invocation
            });

            const result = await lambdaClient.send(waveInvokeCommand);
            
            console.log(`✅ Successfully triggered Wave Dispatch for order ${orderId}`);
            console.log(`📤 Wave Dispatch payload:`, JSON.stringify(payload, null, 2));

            return {
                success: true,
                triggered: true,
                method: 'wave_dispatch',
                centralPlatformResponse: result.StatusCode === 202 ? 'Accepted' : 'Unknown',
                timestamp: new Date().toISOString()
            };

        } catch (waveError) {
            console.warn(`⚠️ Wave Dispatch failed for order ${orderId}, trying fallback:`, waveError.message);
            
            // Fallback to old system with original payload format
            const fallbackPayload = {
                orderId: orderId,
                newStatus: orderStatus,
                orderData: {
                    ...order,
                    businessId: order.businessId || order.storeId,
                    restaurantLocation: order.businessLocation || order.storeLocation,
                    deliveryAddress: order.deliveryAddress,
                    totalAmount: order.totalAmount,
                    estimatedPreparationTime: order.estimatedPreparationTime
                },
                triggeredBy: 'business_app_fallback',
                timestamp: new Date().toISOString()
            };

            const fallbackInvokeCommand = new InvokeCommand({
                FunctionName: CENTRAL_PLATFORM_CONFIG.FALLBACK_FUNCTION,
                Payload: JSON.stringify(fallbackPayload),
                InvocationType: 'Event'
            });

            const fallbackResult = await lambdaClient.send(fallbackInvokeCommand);
            
            console.log(`✅ Successfully triggered fallback assignment for order ${orderId}`);

            return {
                success: true,
                triggered: true,
                method: 'fallback_fcfs',
                centralPlatformResponse: fallbackResult.StatusCode === 202 ? 'Accepted' : 'Unknown',
                timestamp: new Date().toISOString()
            };
        }

    } catch (error) {
        console.error(`❌ Error triggering driver assignment for order ${orderId}:`, error);
        
        return {
            success: false,
            error: error.message,
            timestamp: new Date().toISOString()
        };
    }
}

/**
 * Get order details from database
 */
async function getOrderDetails(orderId) {
    try {
        const command = new GetCommand({
            TableName: process.env.ORDERS_TABLE || 'WhizzMerchants_Orders',
            Key: {
                PK: `ORDER#${orderId}`,
                SK: `ORDER#${orderId}`
            }
        });

        const result = await dynamoDB.send(command);
        return result.Item;

    } catch (error) {
        console.error(`❌ Error getting order details for ${orderId}:`, error);
        return null;
    }
}

/**
 * ⭐ جلب بيانات موقع المطعم من WhizzMerchants_Businesses
 */
async function getBusinessLocation(businessId) {
    try {
        console.log(`🔍 Fetching business location for: ${businessId}`);
        
        const scanCommand = new ScanCommand({
            TableName: 'WhizzMerchants_Businesses',
            FilterExpression: 'businessId = :businessId',
            ExpressionAttributeValues: {
                ':businessId': {S: businessId}
            }
        });

        const result = await dynamoDBClient.send(scanCommand);
        
        if (!result.Items || result.Items.length === 0) {
            console.warn(`⚠️ Business ${businessId} not found in WhizzMerchants_Businesses`);
            return null;
        }

        const business = result.Items[0];
        
        // استخراج البيانات من DynamoDB format
        const locationData = {
            businessId: business.businessId?.S,
            name: business.businessName?.S || business.name?.S,
            latitude: business.latitude?.N ? parseFloat(business.latitude.N) : null,
            longitude: business.longitude?.N ? parseFloat(business.longitude.N) : null,
            regionId: business.regionId?.S,
            parent_district_id: business.parent_district_id?.S,
            governorate_id: business.governorate_id?.S,
            address: business.address?.S
        };

        console.log(`✅ Found business location:`, locationData);
        return locationData;

    } catch (error) {
        console.error(`❌ Error fetching business location for ${businessId}:`, error);
        return null;
    }
}

/**
 * Update order with driver assignment status
 */
async function updateOrderAssignmentStatus(orderId, assignmentData) {
    try {
        const updateCommand = new UpdateCommand({
            TableName: process.env.ORDERS_TABLE || 'WhizzMerchants_Orders',
            Key: {
                PK: `ORDER#${orderId}`,
                SK: `ORDER#${orderId}`
            },
            UpdateExpression: `SET 
                driverAssignmentTriggered = :triggered,
                driverAssignmentAt = :timestamp,
                centralPlatformNotified = :notified
            `,
            ExpressionAttributeValues: {
                ':triggered': true,
                ':timestamp': new Date().toISOString(),
                ':notified': assignmentData.success
            }
        });

        await dynamoDB.send(updateCommand);
        console.log(`✅ Updated order ${orderId} with assignment status`);

    } catch (error) {
        console.error(`❌ Error updating assignment status for order ${orderId}:`, error);
    }
}

/**
 * Main function to handle order status change and trigger driver assignment
 */
async function handleOrderStatusChangeForDriverAssignment(orderId, newStatus, orderData = null) {
    console.log(`🔄 Processing order status change: ${orderId} -> ${newStatus}`);
    
    try {
        // Trigger driver assignment
        const assignmentResult = await triggerDriverAssignment(orderId, newStatus, orderData);
        
        // Update order with assignment status
        if (assignmentResult.triggered) {
            await updateOrderAssignmentStatus(orderId, assignmentResult);
        }

        return assignmentResult;

    } catch (error) {
        console.error(`❌ Error handling order status change for driver assignment:`, error);
        return {
            success: false,
            error: error.message
        };
    }
}

/**
 * Send WebSocket notification to Business App
 */
async function notifyBusinessApp(businessId, message) {
    try {
        console.log(`📤 Sending notification to business ${businessId}`);

        const sendFunctionName = process.env.BUSINESS_WEBSOCKET_SEND_FUNCTION_NAME;
        if (!sendFunctionName) {
            console.warn('⚠️ BUSINESS_WEBSOCKET_SEND_FUNCTION_NAME not set; skipping business notification');
            return;
        }

        if (!WEBSOCKET_ENDPOINTS.BUSINESS_APP) {
            console.warn('⚠️ BUSINESS_WEBSOCKET_ENDPOINT not set; skipping business notification');
            return;
        }
        
        // Use the business WebSocket service to send notification
        const payload = {
            action: 'notify_business',
            businessId: businessId,
            notification: message,
            timestamp: new Date().toISOString()
        };

        const lambdaCommand = new InvokeCommand({
            FunctionName: sendFunctionName,
            Payload: JSON.stringify(payload),
            InvocationType: 'Event' // Async
        });

        await lambdaClient.send(lambdaCommand);
        console.log(`✅ Business notification sent for order ${message.orderId}`);
        
    } catch (error) {
        console.error(`❌ Error notifying business app:`, error);
    }
}

/**
 * Send WebSocket notification to User App
 */
async function notifyUserApp(userId, message) {
    try {
        console.log(`📤 Sending notification to user ${userId}`);

        const sendFunctionName = process.env.USER_WEBSOCKET_SEND_FUNCTION_NAME;
        if (!sendFunctionName) {
            console.warn('⚠️ USER_WEBSOCKET_SEND_FUNCTION_NAME not set; skipping user notification');
            return;
        }

        if (!WEBSOCKET_ENDPOINTS.USER_APP) {
            console.warn('⚠️ USER_WEBSOCKET_ENDPOINT not set; skipping user notification');
            return;
        }
        
        // Use the user WebSocket service to send notification
        const payload = {
            orderId: message.orderId,
            updateData: message,
            websocketEndpoint: WEBSOCKET_ENDPOINTS.USER_APP
        };

        const lambdaCommand = new InvokeCommand({
            FunctionName: sendFunctionName,
            Payload: JSON.stringify(payload),
            InvocationType: 'Event' // Async
        });

        await lambdaClient.send(lambdaCommand);
        console.log(`✅ User notification sent for order ${message.orderId}`);
        
    } catch (error) {
        console.error(`❌ Error notifying user app:`, error);
    }
}

/**
 * Update order with driver information after successful assignment
 */
async function updateOrderWithDriverInfo(order, assignmentResult) {
    try {
        const updateCommand = new UpdateCommand({
            TableName: process.env.ORDERS_TABLE || 'WhizzMerchants_Orders',
            Key: {
                PK: `ORDER#${order.orderId || order.id}`,
                SK: `ORDER#${order.orderId || order.id}`
            },
            UpdateExpression: `SET 
                driverId = :driverId,
                driverName = :driverName,
                driverAssignedAt = :assignedAt,
                estimatedPickupTime = :pickupTime,
                #status = :status
            `,
            ExpressionAttributeNames: {
                '#status': 'status'
            },
            ExpressionAttributeValues: {
                ':driverId': assignmentResult.driverId,
                ':driverName': assignmentResult.driverName,
                ':assignedAt': new Date().toISOString(),
                ':pickupTime': assignmentResult.estimatedPickupTime,
                ':status': 'driver_assigned'
            }
        });

        await dynamoDB.send(updateCommand);
        console.log(`✅ Updated order ${order.orderId} with driver info`);
        
    } catch (error) {
        console.error(`❌ Error updating order with driver info:`, error);
    }
}

/**
 * Send driver assignment notifications back to business and user apps
 * This function sends WebSocket notifications about driver assignment results
 */
async function sendDriverAssignmentNotifications(assignmentResult, order) {
    console.log('📡 Sending driver assignment notifications...');
    
    try {
        const notifications = [];
        
        if (assignmentResult.success) {
            // Success notifications
            const driverAssignedMessage = {
                type: 'DRIVER_ASSIGNED',
                orderId: order.orderId || order.id,
                driverId: assignmentResult.driverId,
                driverName: assignmentResult.driverName,
                estimatedPickupTime: assignmentResult.estimatedPickupTime,
                assignedAt: new Date().toISOString(),
                message: `تم تعيين السائق ${assignmentResult.driverName || 'السائق'} لطلبك`
            };
            
            // Notify business app via WebSocket
            notifications.push(
                notifyBusinessApp(order.businessId || order.storeId, {
                    ...driverAssignedMessage,
                    message: `تم تعيين السائق ${assignmentResult.driverName || 'السائق'} للطلب ${order.orderId}`
                })
            );
            
            // Notify user app via WebSocket
            notifications.push(
                notifyUserApp(order.userId, driverAssignedMessage)
            );
            
            // Update order status to include driver info
            notifications.push(
                updateOrderWithDriverInfo(order, assignmentResult)
            );
            
        } else {
            // Failure notifications
            const assignmentFailedMessage = {
                type: 'DRIVER_ASSIGNMENT_FAILED',
                orderId: order.orderId || order.id,
                reason: assignmentResult.reason || 'No available drivers',
                failedAt: new Date().toISOString(),
                message: 'لم نتمكن من العثور على سائق متاح في الوقت الحالي'
            };
            
            // Notify business app
            notifications.push(
                notifyBusinessApp(order.businessId || order.storeId, {
                    ...assignmentFailedMessage,
                    message: `فشل في تعيين سائق للطلب ${order.orderId}: ${assignmentResult.reason || 'لا يوجد سائقين متاحين'}`
                })
            );
            
            // Notify user app (optional, as this might worry customers)
            // notifications.push(notifyUserApp(order.userId, assignmentFailedMessage));
        }
        
        // Execute all notifications
        const results = await Promise.allSettled(notifications);
        
        console.log('✅ Driver assignment notifications sent:', {
            success: assignmentResult.success,
            notificationsSent: results.length,
            successfulNotifications: results.filter(r => r.status === 'fulfilled').length
        });
        
    } catch (error) {
        console.error('❌ Error sending driver assignment notifications:', error);
    }
}

module.exports = {
    triggerDriverAssignment,
    handleOrderStatusChangeForDriverAssignment,
    updateOrderAssignmentStatus,
    getOrderDetails,
    sendDriverAssignmentNotifications,
    notifyBusinessApp,
    notifyUserApp,
    updateOrderWithDriverInfo
};
