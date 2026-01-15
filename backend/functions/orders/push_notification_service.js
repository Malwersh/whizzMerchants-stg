/**
 * Isolated Push Notification Service
 * 
 * This service handles push notifications for merchant orders using a fire-and-forget
 * pattern. It NEVER throws errors that could interfere with order processing.
 * 
 * Features:
 * - Queries WhizzMerchants_DeviceTokens table for active device tokens
 * - Sends APNS notifications for iOS devices
 * - Sends FCM notifications for Android devices
 * - Comprehensive error handling and logging
 * - Never blocks order processing
 */

const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { DynamoDBDocumentClient, QueryCommand } = require('@aws-sdk/lib-dynamodb');
const https = require('https');

const dynamoDbClient = new DynamoDBClient({ region: process.env.AWS_REGION || 'us-east-1' });
const dynamodb = DynamoDBDocumentClient.from(dynamoDbClient);

class PushNotificationService {
  /**
   * Send push notification to all merchant devices
   * Fire-and-forget pattern - never throws errors
   * 
   * @param {string} merchantId - The merchant business ID
   * @param {object} orderData - Order notification data
   */
  static async sendOrderNotification(merchantId, orderData) {
    try {
      console.log(`📱 Starting push notification for merchant: ${merchantId}`);
      
      // Get all active device tokens for this merchant
      const tokens = await this._getDeviceTokens(merchantId);
      
      if (!tokens || tokens.length === 0) {
        console.log(`⚠️ No active device tokens found for merchant: ${merchantId}`);
        return;
      }
      
      console.log(`📱 Found ${tokens.length} active device token(s) for merchant: ${merchantId}`);
      
      // Send notifications to all devices (fire-and-forget)
      const notificationPromises = tokens.map(token => {
        if (token.platform === 'ios') {
          return this._sendAPNS(token, orderData);
        } else if (token.platform === 'android') {
          return this._sendFCM(token, orderData);
        } else {
          console.warn(`⚠️ Unknown platform: ${token.platform} for token: ${token.tokenId}`);
          return Promise.resolve();
        }
      });
      
      // Wait for all notifications to complete (but don't throw on failure)
      await Promise.allSettled(notificationPromises);
      
      console.log(`✅ Push notification process completed for merchant: ${merchantId}`);
      
    } catch (error) {
      // NEVER throw - just log the error
      console.error('⚠️ Push notification failed (non-fatal):', error);
      console.error('Error details:', {
        merchantId,
        orderData: orderData ? {
          orderId: orderData.orderId,
          customerName: orderData.customerName
        } : 'undefined',
        errorMessage: error.message,
        errorStack: error.stack
      });
    }
  }
  
  /**
   * Get all active device tokens for a merchant from DynamoDB
   * @private
   */
  static async _getDeviceTokens(merchantId) {
    try {
      const tableName = process.env.DEVICE_TOKENS_TABLE || 'WhizzMerchants_DeviceTokens';
      
      console.log(`🔍 Querying device tokens from table: ${tableName}`);
      console.log(`🔍 Merchant ID: ${merchantId}`);
      
      const params = {
        TableName: tableName,
        IndexName: 'MerchantDeviceIndex', // Correct GSI name from DynamoDB
        KeyConditionExpression: 'merchantId = :merchantId',
        FilterExpression: 'isActive = :isActive',
        ExpressionAttributeValues: {
          ':merchantId': merchantId,
          ':isActive': true
        }
      };
      
      const result = await dynamodb.send(new QueryCommand(params));
      
      console.log(`✅ Query returned ${result.Items ? result.Items.length : 0} token(s)`);
      
      return result.Items || [];
      
    } catch (error) {
      console.error('❌ Error querying device tokens:', error);
      console.error('Error details:', {
        merchantId,
        tableName: process.env.DEVICE_TOKENS_TABLE,
        errorMessage: error.message
      });
      return [];
    }
  }
  
  /**
   * Send APNS notification for iOS devices
   * @private
   */
  static async _sendAPNS(tokenData, orderData) {
    try {
      console.log(`📱 Sending APNS notification to device: ${tokenData.deviceId}`);
      
      // TODO: Implement actual APNS sending
      // For now, just log the notification
      const notification = {
        aps: {
          alert: {
            title: 'طلب جديد',
            body: `طلب جديد من ${orderData.customerName || 'عميل'} - ${orderData.totalAmount || 0} د.ع`
          },
          sound: 'default',
          badge: 1
        },
        orderId: orderData.orderId,
        type: 'NEW_ORDER'
      };
      
      console.log('📱 APNS Notification payload:', JSON.stringify(notification, null, 2));
      console.log('📱 Device token:', tokenData.deviceToken);
      
      // Note: Actual APNS implementation would use apn package or AWS SNS
      // For production, implement proper APNS with certificates/keys
      
      console.log(`✅ APNS notification logged for device: ${tokenData.deviceId}`);
      
    } catch (error) {
      console.error('❌ Error sending APNS notification:', error);
      console.error('Error details:', {
        deviceId: tokenData.deviceId,
        errorMessage: error.message
      });
      // Don't throw - just log
    }
  }
  
  /**
   * Send FCM notification for Android devices
   * @private
   */
  static async _sendFCM(tokenData, orderData) {
    try {
      console.log(`📱 Sending FCM notification to device: ${tokenData.deviceId}`);
      
      // TODO: Implement actual FCM sending
      // For now, just log the notification
      const notification = {
        notification: {
          title: 'طلب جديد',
          body: `طلب جديد من ${orderData.customerName || 'عميل'} - ${orderData.totalAmount || 0} د.ع`
        },
        data: {
          orderId: orderData.orderId,
          type: 'NEW_ORDER',
          totalAmount: String(orderData.totalAmount || 0),
          customerName: orderData.customerName || ''
        },
        token: tokenData.deviceToken
      };
      
      console.log('📱 FCM Notification payload:', JSON.stringify(notification, null, 2));
      
      // Note: Actual FCM implementation would use firebase-admin or HTTP API
      // For production, implement proper FCM with server key
      
      console.log(`✅ FCM notification logged for device: ${tokenData.deviceId}`);
      
    } catch (error) {
      console.error('❌ Error sending FCM notification:', error);
      console.error('Error details:', {
        deviceId: tokenData.deviceId,
        errorMessage: error.message
      });
      // Don't throw - just log
    }
  }
}

module.exports = PushNotificationService;
