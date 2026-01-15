#!/usr/bin/env node

/**
 * Test Push Notification System
 * 
 * This script tests the push notification flow end-to-end:
 * 1. Checks if device tokens exist in DynamoDB
 * 2. Simulates a new order notification
 * 3. Verifies the notification was processed
 * 
 * Usage:
 *   node test_push_notifications.js <businessId>
 * 
 * Example:
 *   node test_push_notifications.js STORE-123456
 */

const AWS = require('aws-sdk');
const PushNotificationService = require('./push_notification_service');

const AWS_REGION = process.env.AWS_REGION || 'us-east-1';
const DEVICE_TOKENS_TABLE = process.env.DEVICE_TOKENS_TABLE;
const LAMBDA_FUNCTION_NAME = process.env.LAMBDA_FUNCTION_NAME;

if (!DEVICE_TOKENS_TABLE) {
    console.error('❌ Missing required env var: DEVICE_TOKENS_TABLE');
    process.exit(1);
}

// Configure AWS
AWS.config.update({ region: AWS_REGION });

// Also set environment variable for push notification service
process.env.AWS_REGION = AWS_REGION;

const dynamodb = new AWS.DynamoDB.DocumentClient();


/**
 * Main test function
 */
async function runTest() {
    try {
        console.log('\n🧪 ========================================');
        console.log('🧪 PUSH NOTIFICATION SYSTEM TEST');
        console.log('🧪 ========================================\n');

        // Get businessId from command line
        const businessId = process.argv[2];
        
        if (!businessId) {
            console.error('❌ Error: Please provide a businessId');
            console.log('\nUsage: node test_push_notifications.js <businessId>');
            console.log('Example: node test_push_notifications.js STORE-123456\n');
            process.exit(1);
        }

        console.log(`📱 Testing push notifications for business: ${businessId}\n`);

        // Step 1: Check device tokens
        console.log('Step 1: Checking device tokens in DynamoDB...');
        const tokens = await checkDeviceTokens(businessId);
        
        if (!tokens || tokens.length === 0) {
            console.error(`\n❌ No device tokens found for business: ${businessId}`);
            console.log('\n💡 To register a device token, use the merchant app to login');
            console.log('   or manually insert a token into the DeviceTokens table.\n');
            process.exit(1);
        }

        console.log(`✅ Found ${tokens.length} device token(s):`);
        tokens.forEach((token, index) => {
            console.log(`   ${index + 1}. Platform: ${token.platform}, Device: ${token.deviceId || 'unknown'}`);
            console.log(`      Token: ${token.deviceToken.substring(0, 20)}...`);
            console.log(`      Active: ${token.isActive}, Registered: ${token.registeredAt}`);
        });

        // Step 2: Send test notification
        console.log('\n\nStep 2: Sending test order notification...');
        
        const testOrderData = {
            orderId: `TEST-${Date.now()}`,
            orderNumber: `#TEST-${Math.floor(Math.random() * 10000)}`,
            customerName: 'Ahmed Al-Najafi',
            totalAmount: 25000 // 25,000 IQD
        };

        console.log('📦 Test order data:');
        console.log(`   Order ID: ${testOrderData.orderId}`);
        console.log(`   Order Number: ${testOrderData.orderNumber}`);
        console.log(`   Customer: ${testOrderData.customerName}`);
        console.log(`   Total: ${testOrderData.totalAmount} IQD`);

        console.log('\n📤 Sending notification...\n');

        await PushNotificationService.sendOrderNotification(businessId, testOrderData);

        console.log('\n✅ Notification process completed!');
        console.log('\n💡 Check the CloudWatch logs for detailed notification flow:');
        console.log('   https://console.aws.amazon.com/cloudwatch/');
        if (LAMBDA_FUNCTION_NAME) {
            console.log(`   Log group: /aws/lambda/${LAMBDA_FUNCTION_NAME}`);
        } else {
            console.log('   (set env var LAMBDA_FUNCTION_NAME to print the log group name)');
        }

        // Step 3: Summary
        console.log('\n\n🎉 ========================================');
        console.log('🎉 TEST COMPLETED SUCCESSFULLY');
        console.log('🎉 ========================================\n');

        console.log('Next steps:');
        console.log('1. Check CloudWatch logs to verify notification flow');
        console.log('2. Check merchant device to see if notification arrived');
        console.log('3. If using iOS, verify APNS credentials are configured');
        console.log('4. If using Android, verify FCM server key is configured\n');

    } catch (error) {
        console.error('\n❌ Test failed with error:', error);
        console.error('Error details:', error.stack);
        process.exit(1);
    }
}

/**
 * Check device tokens for a business
 */
async function checkDeviceTokens(businessId) {
    try {
        const params = {
            TableName: DEVICE_TOKENS_TABLE,
            IndexName: 'MerchantDeviceIndex',
            KeyConditionExpression: 'merchantId = :merchantId',
            ExpressionAttributeValues: {
                ':merchantId': businessId
            }
        };

        const result = await dynamodb.query(params).promise();
        return result.Items || [];

    } catch (error) {
        console.error('❌ Error querying device tokens:', error.message);
        
        // If GSI doesn't work, try scan
        console.log('⚠️ Falling back to table scan...');
        
        const scanParams = {
            TableName: DEVICE_TOKENS_TABLE,
            FilterExpression: 'merchantId = :merchantId',
            ExpressionAttributeValues: {
                ':merchantId': businessId
            }
        };

        const scanResult = await dynamodb.scan(scanParams).promise();
        return scanResult.Items || [];
    }
}

// Run the test
runTest();
