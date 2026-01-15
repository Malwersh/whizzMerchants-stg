const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { DynamoDBDocumentClient, GetCommand, UpdateCommand, QueryCommand } = require('@aws-sdk/lib-dynamodb');
const { CognitoIdentityProviderClient, GetUserCommand } = require('@aws-sdk/client-cognito-identity-provider');
const jwt = require('jsonwebtoken');

// Initialize DynamoDB
const dynamoDbClient = new DynamoDBClient({ region: process.env.AWS_REGION || 'us-east-1' });
const dynamodb = DynamoDBDocumentClient.from(dynamoDbClient);

// Table names from environment variables
const BUSINESSES_TABLE = process.env.BUSINESSES_TABLE || 'order-receiver-businesses-dev';
const USERS_TABLE = process.env.USERS_TABLE || 'order-receiver-users-dev';

// CORS headers
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Content-Type,Authorization',
  'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS'
};

/**
 * Business Profile Handler
 * Handles updating business profile information including:
 * - Business name, owner name, phone, description
 * - Business photo URL, website
 * - Address and contact information
 */
exports.handler = async (event) => {
  console.log('📋 Business Profile Event:', JSON.stringify(event, null, 2));

  // Handle CORS preflight requests
  if (event.httpMethod === 'OPTIONS') {
    return {
      statusCode: 200,
      headers: corsHeaders,
      body: ''
    };
  }

  try {
    // Extract user ID from the access token
    const userId = await getUserIdFromToken(event);
    if (!userId) {
      return {
        statusCode: 401,
        headers: corsHeaders,
        body: JSON.stringify({ message: 'Unauthorized' })
      };
    }

    // Extract business ID from path parameters
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
    const requestBody = event.body;

    // Route to appropriate handler based on method
    if (method === 'GET') {
      return await handleGetBusinessProfile(businessId);
    } else if (method === 'PUT') {
      return await handleUpdateBusinessProfile(businessId, requestBody);
    } else {
      return {
        statusCode: 404,
        headers: corsHeaders,
        body: JSON.stringify({ message: 'Endpoint not found' })
      };
    }

  } catch (error) {
    console.error('❌ Business Profile Handler Error:', error);
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
 * Extract user ID from access token
 */
async function getUserIdFromToken(event) {
  try {
    const authHeader = event.headers?.Authorization || event.headers?.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      console.log('❌ No valid authorization header found');
      return null;
    }

    const accessToken = authHeader.replace('Bearer ', '');

    // Try to get user info from Cognito first
    try {
      const cognitoClient = new CognitoIdentityProviderClient({ 
        region: process.env.COGNITO_REGION || 'us-east-1' 
      });
      const userResponse = await cognitoClient.send(new GetUserCommand({ 
        AccessToken: accessToken 
      }));
      
      const email = userResponse.UserAttributes.find(attr => attr.Name === 'email')?.Value;
      if (email) {
        // Look up user ID by email in our users table
        const userRecord = await getUserByEmail(email);
        return userRecord?.userId || userResponse.Username;
      }
    } catch (cognitoError) {
      console.log('⚠️ Cognito lookup failed, trying JWT decode:', cognitoError.message);
    }

    // Fallback to JWT decode (for development/testing)
    try {
      const decoded = jwt.decode(accessToken);
      return decoded?.sub || decoded?.['cognito:username'] || decoded?.username;
    } catch (jwtError) {
      console.error('❌ JWT decode failed:', jwtError);
      return null;
    }
  } catch (error) {
    console.error('❌ Error extracting user ID:', error);
    return null;
  }
}

/**
 * Get user record by email
 */
async function getUserByEmail(email) {
  try {
    const params = {
      TableName: USERS_TABLE,
      FilterExpression: 'email = :email',
      ExpressionAttributeValues: {
        ':email': email.toLowerCase().trim()
      }
    };

    const result = await dynamodb.send(new QueryCommand(params));
    return result.Items && result.Items.length > 0 ? result.Items[0] : null;
  } catch (error) {
    console.error('❌ Error getting user by email:', error);
    return null;
  }
}

/**
 * Verify user has access to the specified business
 */
async function verifyBusinessAccess(userId, businessId) {
  try {
    const params = {
      TableName: BUSINESSES_TABLE,
      Key: { businessId: businessId }
    };

    const result = await dynamodb.send(new GetCommand(params));
    
    if (!result.Item) {
      console.log(`❌ Business ${businessId} not found`);
      return false;
    }

    // Check if user is the owner or has access
    const business = result.Item;
    const hasAccess = business.ownerId === userId || 
                     business.cognitoUserId === userId ||
                     business.admin_users?.includes(userId) ||
                     business.staff_users?.includes(userId);

    console.log(`🔐 Business access check for ${userId}: ${hasAccess}`);
    return hasAccess;
  } catch (error) {
    console.error('❌ Error verifying business access:', error);
    return false;
  }
}

/**
 * Get business profile information
 */
async function handleGetBusinessProfile(businessId) {
  try {
    const params = {
      TableName: BUSINESSES_TABLE,
      Key: { businessId: businessId }
    };

    const result = await dynamodb.send(new GetCommand(params));
    
    if (!result.Item) {
      return {
        statusCode: 404,
        headers: corsHeaders,
        body: JSON.stringify({
          success: false,
          message: 'Business not found'
        })
      };
    }

    const business = result.Item;

    // Return business profile data
    const profileData = {
      businessId: business.businessId,
      businessName: business.businessName || business.name,
      ownerName: business.ownerName,
      email: business.email,
      phoneNumber: business.phoneNumber || business.phone,
      businessType: business.businessType,
      description: business.description,
      website: business.website,
      businessPhotoUrl: business.businessPhotoUrl,
      address: business.address,
      city: business.city,
      district: business.district,
      country: business.country,
      street: business.street,
      latitude: business.latitude,
      longitude: business.longitude,
      status: business.status,
      createdAt: business.createdAt,
      updatedAt: business.updatedAt
    };

    return {
      statusCode: 200,
      headers: corsHeaders,
      body: JSON.stringify({
        success: true,
        profile: profileData
      })
    };

  } catch (error) {
    console.error('❌ Error getting business profile:', error);
    return {
      statusCode: 500,
      headers: corsHeaders,
      body: JSON.stringify({
        success: false,
        message: 'Failed to retrieve business profile',
        error: error.message
      })
    };
  }
}

/**
 * Update business profile information
 */
async function handleUpdateBusinessProfile(businessId, requestBody) {
  try {
    if (!requestBody) {
      return {
        statusCode: 400,
        headers: corsHeaders,
        body: JSON.stringify({
          success: false,
          message: 'Request body is required'
        })
      };
    }

    const updates = JSON.parse(requestBody);
    console.log('📝 Updating business profile:', JSON.stringify(updates, null, 2));

    // Build update expression dynamically based on provided fields
    const updateExpressions = [];
    const expressionAttributeNames = {};
    const expressionAttributeValues = {};

    // Allowed fields for update
    const allowedFields = {
      businessName: 'businessName',
      name: 'businessName',
      ownerName: 'ownerName',
      phoneNumber: 'phoneNumber',
      phone: 'phoneNumber',
      description: 'description',
      website: 'website',
      businessPhotoUrl: 'businessPhotoUrl',
      address: 'address',
      city: 'city',
      district: 'district',
      country: 'country',
      street: 'street',
      latitude: 'latitude',
      longitude: 'longitude'
    };

    // Process each field in the update request
    Object.keys(updates).forEach(key => {
      const dbField = allowedFields[key];
      if (dbField && updates[key] !== undefined) {
        const attributeName = `#${dbField}`;
        const attributeValue = `:${dbField}`;
        
        updateExpressions.push(`${attributeName} = ${attributeValue}`);
        expressionAttributeNames[attributeName] = dbField;
        expressionAttributeValues[attributeValue] = updates[key];
      }
    });

    // Always update the updatedAt timestamp
    updateExpressions.push('#updatedAt = :updatedAt');
    expressionAttributeNames['#updatedAt'] = 'updatedAt';
    expressionAttributeValues[':updatedAt'] = new Date().toISOString();

    if (updateExpressions.length === 1) { // Only updatedAt
      return {
        statusCode: 400,
        headers: corsHeaders,
        body: JSON.stringify({
          success: false,
          message: 'No valid fields provided for update'
        })
      };
    }

    // Perform the update
    const params = {
      TableName: BUSINESSES_TABLE,
      Key: { businessId: businessId },
      UpdateExpression: `SET ${updateExpressions.join(', ')}`,
      ExpressionAttributeNames: expressionAttributeNames,
      ExpressionAttributeValues: expressionAttributeValues,
      ReturnValues: 'ALL_NEW'
    };

    console.log('🔄 DynamoDB update params:', JSON.stringify(params, null, 2));

    const result = await dynamodb.send(new UpdateCommand(params));

    return {
      statusCode: 200,
      headers: corsHeaders,
      body: JSON.stringify({
        success: true,
        message: 'Business profile updated successfully',
        profile: result.Attributes
      })
    };

  } catch (error) {
    console.error('❌ Error updating business profile:', error);
    return {
      statusCode: 500,
      headers: corsHeaders,
      body: JSON.stringify({
        success: false,
        message: 'Failed to update business profile',
        error: error.message
      })
    };
  }
}
