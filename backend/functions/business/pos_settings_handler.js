const {merchantLifecycleClient,merchantHandler}=require('../shared/merchant-lifecycle');
const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { DynamoDBDocumentClient, GetCommand, UpdateCommand } = require('@aws-sdk/lib-dynamodb');
const { CognitoIdentityProviderClient, GetUserCommand } = require('@aws-sdk/client-cognito-identity-provider');
const jwt = require('jsonwebtoken');

// Initialize DynamoDB
const dynamoDbClient = new DynamoDBClient({ region: process.env.AWS_REGION || 'us-east-1' });
const lifecycleRawDb = DynamoDBDocumentClient.from(dynamoDbClient);
const dynamodb = merchantLifecycleClient(lifecycleRawDb);

// Table names from environment variables
const BUSINESSES_TABLE = process.env.BUSINESSES_TABLE || 'WhizzMerchants_Businesses';

// CORS headers
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Content-Type,Authorization',
  'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS'
};

const DEFAULT_POS_SETTINGS = {
  enabled: false,
  systemType: 'genericApi',
  apiEndpoint: '',
  apiKey: '',
  locationId: '',
  testMode: false,
  autoSendOrders: false,
  autoAcceptOrders: true,
  timeoutSeconds: 30
};

/**
 * POS Settings Handler
 * Manages external POS integration settings and tests connectivity.
 */
exports.handler = async (event) => {
  console.log('🛒 POS Settings Handler - Event:', {method:event.httpMethod,path:event.path});

  // Handle preflight CORS requests
  if (event.httpMethod === 'OPTIONS') {
    return {
      statusCode: 200,
      headers: corsHeaders,
      body: JSON.stringify({ message: 'CORS preflight successful' })
    };
  }

  try {
    // Handle Base64 encoded request body from API Gateway
    let requestBody = event.body;
    if (event.isBase64Encoded && requestBody) {
      try {
        requestBody = Buffer.from(requestBody, 'base64').toString('utf-8');
        console.log('📝 Decoded Base64 request body');
      } catch (decodeError) {
        console.error('❌ Failed to decode Base64 body:', decodeError);
      }
    }

    // Extract user information from access token
    const authHeader = event.headers.Authorization || event.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return {
        statusCode: 401,
        headers: corsHeaders,
        body: JSON.stringify({ message: 'Authorization token required' })
      };
    }

    const accessToken = authHeader.substring(7);
    let userId;

    try {
      const cognitoClient = new CognitoIdentityProviderClient({
        region: process.env.COGNITO_REGION || 'us-east-1'
      });
      const userResponse = await cognitoClient.send(new GetUserCommand({
        AccessToken: accessToken
      }));

      userId = userResponse.UserAttributes.find(attr => attr.Name === 'sub')?.Value || userResponse.Username;
      console.log(`🔐 Authenticated user from Cognito: ${userId}`);
    } catch (cognitoError) {
      console.error('❌ Cognito token validation failed:', cognitoError);
      try {
        const decodedToken = jwt.decode(accessToken);
        userId = decodedToken?.sub || decodedToken?.['cognito:username'];
        console.log('🔐 Fallback JWT decode userId:', userId);
      } catch (jwtError) {
        console.error('❌ JWT decode also failed:', jwtError);
        return {
          statusCode: 401,
          headers: corsHeaders,
          body: JSON.stringify({ message: 'Invalid authorization token' })
        };
      }
    }

    if (!userId) {
      return {
        statusCode: 401,
        headers: corsHeaders,
        body: JSON.stringify({ message: 'User ID not found in token' })
      };
    }

    const businessId = event.pathParameters?.businessId;
    if (!businessId) {
      return {
        statusCode: 400,
        headers: corsHeaders,
        body: JSON.stringify({ message: 'Business ID is required' })
      };
    }

    console.log(`👤 User ID: ${userId}, 🏢 Business ID: ${businessId}`);

    // Verify user has access to this business
    const hasAccess = await verifyBusinessAccess(userId, businessId);
    if (!hasAccess) {
      return {
        statusCode: 403,
        headers: corsHeaders,
        body: JSON.stringify({ message: 'Access denied to this business' })
      };
    }

    const method = event.httpMethod;
    const path = event.resource || event.path;

    if (method === 'GET' && path.includes('/pos-settings') && !path.includes('/test-connection')) {
      return await handleGetPosSettings(businessId);
    } else if (method === 'PUT' && path.includes('/pos-settings') && !path.includes('/test-connection')) {
      const parsedBody = requestBody ? JSON.parse(requestBody) : {};
      return await handleUpdatePosSettings(businessId, parsedBody);
    } else if (method === 'POST' && path.includes('/pos-settings/test-connection')) {
      const parsedBody = requestBody ? JSON.parse(requestBody) : {};
      return await handleTestConnection(parsedBody);
    } else {
      return {
        statusCode: 404,
        headers: corsHeaders,
        body: JSON.stringify({ message: 'Endpoint not found' })
      };
    }
  } catch (error) {
    console.error('❌ POS Settings Handler Error:', error);
    return {
      statusCode: 500,
      headers: corsHeaders,
      body: JSON.stringify({
        message: 'Internal server error',
        error: error.message
      })
    };
  }
};

/**
 * Verify user has access to the specified business
 */
async function verifyBusinessAccess(userId, businessId) {
  try {
    console.log(`🔍 DEBUG: Verifying business access for POS settings`);

    const params = {
      TableName: BUSINESSES_TABLE,
      Key: { businessId: businessId }
    };

    const result = await dynamodb.send(new GetCommand(params));

    if (!result.Item) {
      console.log(`❌ Business ${businessId} not found in table ${BUSINESSES_TABLE}`);
      return false;
    }

    const business = result.Item;
    console.log(`✅ Business found! Available fields:`, Object.keys(business));

    const hasAccess = business.ownerId === userId ||
                      business.cognitoUserId === userId ||
                      business.admin_users?.includes(userId) ||
                      business.staff_users?.includes(userId);

    console.log(`🔐 Final access result: ${hasAccess}`);
    return hasAccess;
  } catch (error) {
    console.error('❌ Error verifying business access:', error);
    return false;
  }
}

/**
 * Get POS settings for a business
 */
async function handleGetPosSettings(businessId) {
  try {
    const result = await dynamodb.send(new GetCommand({
      TableName: BUSINESSES_TABLE,
      Key: { businessId: businessId },
      ProjectionExpression: 'posSettings'
    }));

    const settings = result.Item?.posSettings || DEFAULT_POS_SETTINGS;
    const merged = { ...DEFAULT_POS_SETTINGS, ...settings };

    console.log('🛒 Retrieved POS settings:', merged);

    return {
      statusCode: 200,
      headers: corsHeaders,
      body: JSON.stringify(merged)
    };
  } catch (error) {
    console.error('❌ Error getting POS settings:', error);
    return {
      statusCode: 500,
      headers: corsHeaders,
      body: JSON.stringify({
        success: false,
        message: 'Failed to retrieve POS settings',
        error: error.message
      })
    };
  }
}

/**
 * Update POS settings for a business
 */
async function handleUpdatePosSettings(businessId, requestBody) {
  try {
    if (!requestBody || Object.keys(requestBody).length === 0) {
      return {
        statusCode: 400,
        headers: corsHeaders,
        body: JSON.stringify({
          success: false,
          message: 'Request body is required'
        })
      };
    }

    const settings = { ...DEFAULT_POS_SETTINGS, ...requestBody };

    // Validate required fields when POS integration is enabled
    if (settings.enabled) {
      if (!settings.apiEndpoint || settings.apiEndpoint.trim() === '') {
        return {
          statusCode: 400,
          headers: corsHeaders,
          body: JSON.stringify({
            success: false,
            message: 'API endpoint is required when POS integration is enabled'
          })
        };
      }
      if (!settings.apiKey || settings.apiKey.trim() === '') {
        return {
          statusCode: 400,
          headers: corsHeaders,
          body: JSON.stringify({
            success: false,
            message: 'API key is required when POS integration is enabled'
          })
        };
      }
    }

    // Sanitize timeout
    let timeout = parseInt(settings.timeoutSeconds, 10);
    if (isNaN(timeout) || timeout < 10) timeout = 10;
    if (timeout > 120) timeout = 120;
    settings.timeoutSeconds = timeout;

    const params = {
      TableName: BUSINESSES_TABLE,
      Key: { businessId: businessId },
      UpdateExpression: 'SET posSettings = :posSettings, updatedAt = :updatedAt',
      ExpressionAttributeValues: {
        ':posSettings': settings,
        ':updatedAt': new Date().toISOString()
      },
      ReturnValues: 'ALL_NEW'
    };

    const result = await dynamodb.send(new UpdateCommand(params));

    console.log('✅ POS settings updated successfully');

    return {
      statusCode: 200,
      headers: corsHeaders,
      body: JSON.stringify({
        success: true,
        message: 'POS settings updated successfully',
        settings: result.Attributes.posSettings
      })
    };
  } catch (error) {
    console.error('❌ Error updating POS settings:', error);
    return {
      statusCode: 500,
      headers: corsHeaders,
      body: JSON.stringify({
        success: false,
        message: 'Failed to update POS settings',
        error: error.message
      })
    };
  }
}

/**
 * Test connectivity to the configured POS endpoint
 */
async function handleTestConnection(testConfig) {
  try {
    const { apiEndpoint, apiKey, locationId, systemType } = testConfig || {};

    if (!apiEndpoint || apiEndpoint.trim() === '') {
      return {
        statusCode: 400,
        headers: corsHeaders,
        body: JSON.stringify({
          success: false,
          message: 'API endpoint is required for connection test'
        })
      };
    }

    const headers = {
      'Content-Type': 'application/json'
    };
    if (apiKey && apiKey.trim() !== '') {
      headers['Authorization'] = `Bearer ${apiKey.trim()}`;
    }
    if (locationId && locationId.trim() !== '') {
      headers['X-Location-Id'] = locationId.trim();
    }
    if (systemType) {
      headers['X-POS-System'] = systemType;
    }

    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 15000);

    const response = await fetch(apiEndpoint.trim(), {
      method: 'POST',
      headers,
      body: JSON.stringify({
        event: 'pos.test',
        systemType: systemType || 'genericApi',
        locationId: locationId || '',
        timestamp: new Date().toISOString()
      }),
      signal: controller.signal
    });

    clearTimeout(timeout);

    if (response.status >= 200 && response.status < 300) {
      return {
        statusCode: 200,
        headers: corsHeaders,
        body: JSON.stringify({
          success: true,
          message: 'Connection test successful'
        })
      };
    }

    let responseText = '';
    try {
      responseText = await response.text();
    } catch (e) {
      // ignore
    }

    return {
      statusCode: 200,
      headers: corsHeaders,
      body: JSON.stringify({
        success: false,
        message: `Connection test failed with HTTP ${response.status}: ${responseText || response.statusText}`
      })
    };
  } catch (error) {
    console.error('❌ Error testing POS connection:', error);
    return {
      statusCode: 200,
      headers: corsHeaders,
      body: JSON.stringify({
        success: false,
        message: `Connection test failed: ${error.message || error}`
      })
    };
  }
}

module.exports.handler=merchantHandler(module.exports.handler,{db:lifecycleRawDb});
