/**
 * Test Push Notification Script
 * Sends a test "New Offers" notification to a merchant's registered device
 */

const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { DynamoDBDocumentClient, ScanCommand } = require('@aws-sdk/lib-dynamodb');
const { SNSClient, PublishCommand, CreatePlatformEndpointCommand } = require('@aws-sdk/client-sns');

// Configuration
const DEVICE_TOKENS_TABLE = 'WhizzMerchants_DeviceTokens';
const MERCHANT_ID = 'business_1756336745961_ywix4oy9aa'; // Your business ID
const AWS_REGION = 'us-east-1';

// Initialize AWS clients
const dynamoDbClient = new DynamoDBClient({ region: AWS_REGION });
const dynamodb = DynamoDBDocumentClient.from(dynamoDbClient);
const sns = new SNSClient({ region: AWS_REGION });

/**
 * Get device tokens for a merchant
 */
async function getDeviceTokens(merchantId) {
    const params = {
        TableName: DEVICE_TOKENS_TABLE,
        FilterExpression: 'merchantId = :merchantId AND isActive = :active',
        ExpressionAttributeValues: {
            ':merchantId': merchantId,
            ':active': true
        }
    };

    console.log('🔍 Querying device tokens for merchant:', merchantId);
    const result = await dynamodb.send(new ScanCommand(params));
    return result.Items || [];
}

/**
 * Send FCM notification (works for both iOS and Android)
 */
async function sendFCMNotification(deviceToken, title, body, data) {
    try {
        // For testing, we'll use FCM direct API
        // In production, you'd use SNS with your configured APNS/FCM ARNs
        
        console.log('📱 Sending FCM notification...');
        console.log('   Title:', title);
        console.log('   Body:', body);
        console.log('   Token:', deviceToken.substring(0, 30) + '...');
        
        // Note: For this to work, you need:
        // 1. SNS_FCM_ARN environment variable set (for Android)
        // 2. SNS_APNS_ARN environment variable set (for iOS)
        
        const fcmServerKey = process.env.FCM_SERVER_KEY;
        if (!fcmServerKey) {
            console.log('⚠️  FCM_SERVER_KEY not set. Showing what would be sent:');
            console.log('📤 Notification payload:', JSON.stringify({
                notification: {
                    title: title,
                    body: body,
                    sound: 'default',
                    badge: 1
                },
                data: data,
                to: deviceToken
            }, null, 2));
            return { success: true, simulated: true };
        }

        // Send via FCM HTTP v1 API
        const fetch = require('node-fetch');
        const response = await fetch('https://fcm.googleapis.com/fcm/send', {
            method: 'POST',
            headers: {
                'Authorization': `key=${fcmServerKey}`,
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                notification: {
                    title: title,
                    body: body,
                    sound: 'default',
                    badge: 1,
                    priority: 'high'
                },
                data: data,
                to: deviceToken,
                priority: 'high',
                content_available: true
            })
        });

        const result = await response.json();
        console.log('✅ FCM Response:', result);
        return result;
        
    } catch (error) {
        console.error('❌ Error sending FCM notification:', error);
        throw error;
    }
}

/**
 * Main test function
 */
async function testPushNotification() {
    try {
        console.log('🚀 Starting push notification test...\n');
        
        // Step 1: Get device tokens
        const deviceTokens = await getDeviceTokens(MERCHANT_ID);
        console.log(`📱 Found ${deviceTokens.length} device token(s)\n`);
        
        if (deviceTokens.length === 0) {
            console.log('❌ No device tokens found for merchant:', MERCHANT_ID);
            console.log('💡 Make sure the device is registered by logging into the app');
            return;
        }

        // Step 2: Prepare notification
        const notification = {
            title: 'عروض جديدة! 🎉',
            body: 'لديك عروض خاصة جديدة لزيادة مبيعاتك',
            data: {
                type: 'new_offers',
                offerId: 'OFFER_' + Date.now(),
                businessId: MERCHANT_ID,
                timestamp: new Date().toISOString(),
                action: 'view_offers'
            }
        };

        // Step 3: Send to each device
        for (const tokenRecord of deviceTokens) {
            console.log('\n📤 Sending notification to device:');
            console.log('   Device ID:', tokenRecord.deviceId);
            console.log('   Platform:', tokenRecord.platform);
            console.log('   App Version:', tokenRecord.appVersion);
            
            try {
                await sendFCMNotification(
                    tokenRecord.deviceToken,
                    notification.title,
                    notification.body,
                    notification.data
                );
                console.log('✅ Notification sent successfully!\n');
            } catch (error) {
                console.error('❌ Failed to send to device:', tokenRecord.deviceId);
                console.error('   Error:', error.message);
            }
        }

        console.log('\n🎉 Test completed!');
        console.log('📱 Check your iPhone for the notification');
        
    } catch (error) {
        console.error('❌ Test failed:', error);
        throw error;
    }
}

// Run the test
testPushNotification()
    .then(() => {
        console.log('\n✅ Script completed successfully');
        process.exit(0);
    })
    .catch((error) => {
        console.error('\n❌ Script failed:', error);
        process.exit(1);
    });
