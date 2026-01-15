/**
 * ========================================
 * PUSH NOTIFICATION SERVICE (ISOLATED)
 * ========================================
 * 
 * A standalone, self-contained push notification system that:
 * - Does NOT interfere with order processing
 * - Handles all errors gracefully
 * - Logs everything for debugging
 * - Works with both iOS (APNS) and Android (FCM)
 * - Uses the new WhizzMerchants_DeviceTokens table
 * - Supports legacy endpoints for backward compatibility
 * 
 * Usage:
 *   const PushService = require('./push_notification_service');
 *   await PushService.sendOrderNotification(businessId, orderData);
 */

const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { DynamoDBDocumentClient, ScanCommand, UpdateCommand } = require('@aws-sdk/lib-dynamodb');
const { SNSClient, PublishCommand, CreatePlatformEndpointCommand } = require('@aws-sdk/client-sns');

// Initialize AWS clients
const dynamoDbClient = new DynamoDBClient({ region: process.env.AWS_REGION || 'us-east-1' });
const dynamodb = DynamoDBDocumentClient.from(dynamoDbClient);
const sns = new SNSClient({ region: process.env.AWS_REGION || 'us-east-1' });

// Configuration
const CONFIG = {
    DEVICE_TOKENS_TABLE: process.env.DEVICE_TOKENS_TABLE || 'WhizzMerchants_DeviceTokens',
    LEGACY_ENDPOINTS_TABLE: process.env.MERCHANT_ENDPOINTS_TABLE || 'order-receiver-merchant-endpoints-dev',
    SNS_FCM_ARN: process.env.SNS_FCM_ARN,
    SNS_APNS_ARN: process.env.SNS_APNS_ARN,
    APNS_BUNDLE_ID: process.env.APNS_BUNDLE_ID || 'com.hadhir.business',
    ENABLE_LEGACY_SUPPORT: process.env.ENABLE_LEGACY_PUSH_SUPPORT !== 'false', // Default: enabled
    MAX_RETRY_ATTEMPTS: 2,
    TIMEOUT_MS: 5000 // Don't wait forever for push notifications
};

/**
 * Main entry point: Send order notification to merchant
 * This is fire-and-forget - failures won't affect the caller
 */
async function sendOrderNotification(businessId, orderData) {
    const startTime = Date.now();
    
    try {
        console.log('🔔 [PUSH-SERVICE] Starting notification for business:', businessId);
        
        // Prepare notification payload
        const notification = {
            title: 'طلب جديد! 🔔',
            body: `طلب من ${orderData.customerName} - ${orderData.totalAmount} IQD`,
            data: {
                type: 'new_order',
                orderId: orderData.orderId,
                orderNumber: orderData.orderNumber,
                businessId: businessId,
                timestamp: new Date().toISOString()
            }
        };

        // Get all device tokens for this business
        const devices = await getActiveDevices(businessId);
        
        if (devices.length === 0) {
            console.log('📱 [PUSH-SERVICE] No active devices found for business:', businessId);
            return { success: true, sent: 0, message: 'No devices to notify' };
        }

        console.log(`📱 [PUSH-SERVICE] Found ${devices.length} active device(s)`);

        // Send to all devices (parallel, non-blocking)
        const results = await Promise.allSettled(
            devices.map(device => sendToDevice(device, notification))
        );

        // Count successes and failures
        const successful = results.filter(r => r.status === 'fulfilled' && r.value === true).length;
        const failed = results.filter(r => r.status === 'rejected' || r.value === false).length;

        const duration = Date.now() - startTime;
        console.log(`✅ [PUSH-SERVICE] Completed in ${duration}ms - Success: ${successful}, Failed: ${failed}`);

        return {
            success: true,
            sent: successful,
            failed: failed,
            duration: duration
        };

    } catch (error) {
        const duration = Date.now() - startTime;
        console.error(`❌ [PUSH-SERVICE] Failed after ${duration}ms:`, error.message);
        
        // Never throw - this is fire-and-forget
        return {
            success: false,
            error: error.message,
            duration: duration
        };
    }
}

/**
 * Get all active devices for a business
 */
async function getActiveDevices(businessId) {
    const devices = [];

    try {
        // STEP 1: Get devices from new production table
        const newDevices = await getDevicesFromNewTable(businessId);
        devices.push(...newDevices);
        console.log(`📱 [PUSH-SERVICE] Found ${newDevices.length} device(s) in new table`);

        // STEP 2: Get devices from legacy table (if enabled)
        if (CONFIG.ENABLE_LEGACY_SUPPORT) {
            const legacyDevices = await getDevicesFromLegacyTable(businessId);
            devices.push(...legacyDevices);
            console.log(`📱 [PUSH-SERVICE] Found ${legacyDevices.length} legacy device(s)`);
        }

    } catch (error) {
        console.error('❌ [PUSH-SERVICE] Error fetching devices:', error.message);
    }

    return devices;
}

/**
 * Get devices from new WhizzMerchants_DeviceTokens table
 */
async function getDevicesFromNewTable(businessId) {
    try {
        const params = {
            TableName: CONFIG.DEVICE_TOKENS_TABLE,
            FilterExpression: 'merchantId = :merchantId AND isActive = :active',
            ExpressionAttributeValues: {
                ':merchantId': businessId,
                ':active': true
            }
        };

        const result = await dynamodb.send(new ScanCommand(params));
        
        return (result.Items || []).map(item => ({
            deviceToken: item.deviceToken,
            platform: item.platform,
            deviceId: item.deviceId,
            merchantId: item.merchantId,
            tokenId: item.tokenId,
            source: 'new_table'
        }));

    } catch (error) {
        console.error('❌ [PUSH-SERVICE] Error querying new table:', error.message);
        return [];
    }
}

/**
 * Get devices from legacy table (backward compatibility)
 */
async function getDevicesFromLegacyTable(businessId) {
    try {
        const params = {
            TableName: CONFIG.LEGACY_ENDPOINTS_TABLE,
            FilterExpression: 'merchantId = :merchantId AND endpointType = :type AND isActive = :active',
            ExpressionAttributeValues: {
                ':merchantId': businessId,
                ':type': 'mobile_push',
                ':active': true
            }
        };

        const result = await dynamodb.send(new ScanCommand(params));
        
        return (result.Items || []).map(item => ({
            deviceToken: item.deviceToken,
            platform: item.platform,
            merchantId: item.merchantId,
            source: 'legacy_table'
        }));

    } catch (error) {
        console.error('❌ [PUSH-SERVICE] Error querying legacy table:', error.message);
        return [];
    }
}

/**
 * Send notification to a single device
 */
async function sendToDevice(device, notification) {
    const { deviceToken, platform, deviceId, source } = device;
    
    try {
        console.log(`📤 [PUSH-SERVICE] Sending to ${platform} device (${source}):`, deviceId || deviceToken.substring(0, 20));

        // Set timeout to prevent hanging
        const sendPromise = platform === 'ios'
            ? sendAPNS(deviceToken, notification)
            : sendFCM(deviceToken, notification);

        const timeoutPromise = new Promise((_, reject) =>
            setTimeout(() => reject(new Error('Timeout')), CONFIG.TIMEOUT_MS)
        );

        await Promise.race([sendPromise, timeoutPromise]);

        console.log(`✅ [PUSH-SERVICE] Sent successfully to ${platform} device`);
        return true;

    } catch (error) {
        console.error(`❌ [PUSH-SERVICE] Failed to send to ${platform} device:`, error.message);
        
        // Mark device as inactive if endpoint is disabled
        if (error.code === 'EndpointDisabled' || error.statusCode === 410) {
            await markDeviceInactive(device);
        }
        
        return false;
    }
}

/**
 * Send FCM notification (Android)
 */
async function sendFCM(deviceToken, notification) {
    if (!CONFIG.SNS_FCM_ARN) {
        console.log('⚠️ [PUSH-SERVICE] FCM ARN not configured, skipping Android notification');
        return;
    }

    const payload = {
        GCM: JSON.stringify({
            notification: {
                title: notification.title,
                body: notification.body,
                sound: 'new_order.wav',
                click_action: 'FLUTTER_NOTIFICATION_CLICK',
                channel_id: 'new_orders'
            },
            data: notification.data,
            priority: 'high',
            content_available: true
        })
    };

    const endpointArn = await createSNSEndpoint(deviceToken, 'android', CONFIG.SNS_FCM_ARN);
    
    await sns.send(new PublishCommand({
        TargetArn: endpointArn,
        Message: JSON.stringify(payload),
        MessageStructure: 'json'
    }));
}

/**
 * Send APNS notification (iOS)
 */
async function sendAPNS(deviceToken, notification) {
    if (!CONFIG.SNS_APNS_ARN) {
        console.log('⚠️ [PUSH-SERVICE] APNS ARN not configured, skipping iOS notification');
        return;
    }

    const payload = {
        APNS: JSON.stringify({
            aps: {
                alert: {
                    title: notification.title,
                    body: notification.body
                },
                sound: 'new_order.wav',
                badge: 1,
                'content-available': 1
            },
            data: notification.data
        })
    };

    const endpointArn = await createSNSEndpoint(deviceToken, 'ios', CONFIG.SNS_APNS_ARN);
    
    await sns.send(new PublishCommand({
        TargetArn: endpointArn,
        Message: JSON.stringify(payload),
        MessageStructure: 'json',
        MessageAttributes: {
            'AWS.SNS.MOBILE.APNS.TOPIC': {
                DataType: 'String',
                StringValue: CONFIG.APNS_BUNDLE_ID
            }
        }
    }));
}

/**
 * Create SNS platform endpoint
 */
async function createSNSEndpoint(deviceToken, platform, platformArn) {
    try {
        const result = await sns.send(new CreatePlatformEndpointCommand({
            PlatformApplicationArn: platformArn,
            Token: deviceToken
        }));
        
        return result.EndpointArn;

    } catch (error) {
        // If endpoint already exists, construct ARN
        if (error.code === 'InvalidParameter') {
            const arnParts = platformArn.split(':');
            return `${arnParts.slice(0, -1).join(':')}:endpoint/${platform}/${arnParts[arnParts.length - 1]}/${deviceToken}`;
        }
        throw error;
    }
}

/**
 * Mark device as inactive when push fails
 */
async function markDeviceInactive(device) {
    try {
        if (device.source === 'new_table' && device.tokenId) {
            await dynamodb.send(new UpdateCommand({
                TableName: CONFIG.DEVICE_TOKENS_TABLE,
                Key: { tokenId: device.tokenId },
                UpdateExpression: 'SET isActive = :inactive, updatedAt = :timestamp',
                ExpressionAttributeValues: {
                    ':inactive': false,
                    ':timestamp': new Date().toISOString()
                }
            }));
            console.log('📱 [PUSH-SERVICE] Marked device as inactive:', device.tokenId);
        } else if (device.source === 'legacy_table') {
            await dynamodb.send(new UpdateCommand({
                TableName: CONFIG.LEGACY_ENDPOINTS_TABLE,
                Key: {
                    merchantId: device.merchantId,
                    endpointType: 'mobile_push'
                },
                UpdateExpression: 'SET isActive = :inactive',
                ExpressionAttributeValues: {
                    ':inactive': false
                }
            }));
            console.log('📱 [PUSH-SERVICE] Marked legacy device as inactive');
        }
    } catch (error) {
        console.error('❌ [PUSH-SERVICE] Failed to mark device inactive:', error.message);
    }
}

/**
 * Send a test notification (for debugging)
 */
async function sendTestNotification(businessId, message = 'Test notification') {
    return sendOrderNotification(businessId, {
        customerName: 'Test Customer',
        totalAmount: 0,
        orderId: 'test-' + Date.now(),
        orderNumber: 'TEST-' + Date.now()
    });
}

// Export public API
module.exports = {
    sendOrderNotification,
    sendTestNotification,
    CONFIG // Export for testing/debugging
};
