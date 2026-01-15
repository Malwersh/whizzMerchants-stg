#!/usr/bin/env node

/**
 * Test Script for Push Notification Service
 * 
 * Usage:
 *   node test_push_service.js <businessId>
 *   node test_push_service.js business_1756336745961_ywix4oy9aa
 */

// Set environment variables
process.env.AWS_REGION = 'us-east-1';
process.env.DEVICE_TOKENS_TABLE = 'WhizzMerchants_DeviceTokens';
process.env.MERCHANT_ENDPOINTS_TABLE = 'order-receiver-merchant-endpoints-dev';

// Import the service
const PushService = require('./push_notification_service');

// Get business ID from command line
const businessId = process.argv[2] || 'business_1756336745961_ywix4oy9aa';

console.log('🧪 Testing Push Notification Service');
console.log('=====================================');
console.log('Business ID:', businessId);
console.log('');

// Test notification
async function runTest() {
    try {
        console.log('📤 Sending test notification...');
        
        const result = await PushService.sendTestNotification(businessId, 'Test from push service');
        
        console.log('');
        console.log('✅ Test completed!');
        console.log('Result:', JSON.stringify(result, null, 2));
        
        process.exit(0);
        
    } catch (error) {
        console.error('');
        console.error('❌ Test failed:', error);
        process.exit(1);
    }
}

// Run the test
runTest();
