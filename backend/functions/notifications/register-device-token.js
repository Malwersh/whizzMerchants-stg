/**
 * Register Device Token Lambda
 * Stores FCM/APNs device tokens for push notifications
 */

const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { DynamoDBDocumentClient, QueryCommand, UpdateCommand } = require('@aws-sdk/lib-dynamodb');

const client = new DynamoDBClient({ region: process.env.AWS_REGION || 'us-east-1' });
const docClient = DynamoDBDocumentClient.from(client);

const TABLE_NAME = process.env.DEVICE_TOKENS_TABLE || 'WhizzMerchants_DeviceTokens';

function getHeader(event, name) {
  const headers = event.headers || {};
  const target = String(name || '').toLowerCase();
  for (const [k, v] of Object.entries(headers)) {
    if (String(k).toLowerCase() === target) return v;
  }
  return undefined;
}

function normalizeBaseUrl(baseUrl) {
  const v = String(baseUrl || '').trim();
  if (!v) return '';
  return v.replace(/\/$/, '');
}

async function forwardToCentralNotifications({ authorization, token, platform, deviceId, appVersion }) {
  const baseUrl = normalizeBaseUrl(process.env.CENTRAL_PUSH_API_BASE_URL);
  if (!baseUrl) throw new Error('Missing CENTRAL_PUSH_API_BASE_URL');

  const url = `${baseUrl}/push/tokens/register`;
  const payload = {
    token,
    platform,
    app: 'merchant',
    ...(deviceId ? { deviceId } : {}),
    ...(appVersion ? { appVersion } : {}),
  };

  const resp = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': authorization,
    },
    body: JSON.stringify(payload),
  });

  const text = await resp.text();
  let parsed;
  try {
    parsed = text ? JSON.parse(text) : null;
  } catch (_) {
    parsed = { raw: text };
  }

  return { status: resp.status, ok: resp.ok, body: parsed };
}

/**
 * @param {Object} event - API Gateway event
 * @returns {Object} - API Gateway response
 */
exports.handler = async (event) => {
  console.log('📱 Register Device Token - Event:', JSON.stringify(event, null, 2));

  const headers = {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'Content-Type,Authorization',
    'Access-Control-Allow-Methods': 'POST,OPTIONS'
  };

  // Handle OPTIONS for CORS
  if (event.httpMethod === 'OPTIONS') {
    return { statusCode: 200, headers, body: '' };
  }

  try {
    // Require merchant auth and unify token storage with Central Notifications.
    const authorization = String(getHeader(event, 'authorization') || '').trim();
    if (!authorization) {
      return {
        statusCode: 401,
        headers,
        body: JSON.stringify({ error: 'Missing Authorization header' })
      };
    }

    // Extract merchantId from path parameters
    const merchantId = event.pathParameters?.merchantId;
    if (!merchantId) {
      return {
        statusCode: 400,
        headers,
        body: JSON.stringify({ error: 'merchantId is required' })
      };
    }

    // Parse request body
    const body = JSON.parse(event.body || '{}');
    const { deviceToken, platform, deviceId, appVersion, isActive = true } = body;

    // Validate required fields
    if (!deviceToken || !platform) {
      return {
        statusCode: 400,
        headers,
        body: JSON.stringify({ 
          error: 'deviceToken and platform are required',
          received: { deviceToken: !!deviceToken, platform: !!platform }
        })
      };
    }

    if (!['ios', 'android'].includes(String(platform).toLowerCase())) {
      return {
        statusCode: 400,
        headers,
        body: JSON.stringify({ error: 'platform must be ios or android' })
      };
    }

    const resp = await forwardToCentralNotifications({
      authorization,
      token: String(deviceToken).trim(),
      platform: String(platform).toLowerCase(),
      deviceId: deviceId ? String(deviceId).trim() : undefined,
      appVersion: appVersion ? String(appVersion).trim() : undefined,
    });

    if (!resp.ok) {
      return {
        statusCode: resp.status,
        headers,
        body: JSON.stringify({
          success: false,
          error: 'Central Notifications token registration failed',
          details: resp.body,
        })
      };
    }

    return {
      statusCode: 200,
      headers,
      body: JSON.stringify({
        success: true,
        message: 'Device token registered successfully (centralized)',
        merchantId,
        central: resp.body
      })
    };

  } catch (error) {
    console.error('❌ Error registering device token:', error);
    return {
      statusCode: 500,
      headers,
      body: JSON.stringify({
        error: 'Failed to register device token',
        message: error.message
      })
    };
  }
};
