const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { DynamoDBDocumentClient, GetCommand, QueryCommand, ScanCommand } = require('@aws-sdk/lib-dynamodb');
const { CognitoIdentityProviderClient, GetUserCommand } = require('@aws-sdk/client-cognito-identity-provider');

// Initialize DynamoDB
const dynamoDbClient = new DynamoDBClient({ region: process.env.AWS_REGION || 'us-east-1' });
const dynamodb = DynamoDBDocumentClient.from(dynamoDbClient);

// Table names from environment variables
const BUSINESSES_TABLE = process.env.BUSINESSES_TABLE || 'WhizzMerchants_Businesses';
const USERS_TABLE = process.env.USERS_TABLE || 'WhizzMerchants_Users';

// CORS headers
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Content-Type,Authorization',
  'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS'
};

/**
 * Business Details Handler
 * Fetches complete business information including all details from the businesses table
 */
exports.handler = async (event) => {
  console.log('📋 Business Details Event:', {method:event.httpMethod,path:event.path});

  // Handle CORS preflight requests
  if (event.httpMethod === 'OPTIONS') {
    return {
      statusCode: 200,
      headers: corsHeaders,
      body: ''
    };
  }

  try {
    // Extract user info from the access token
    const userInfo = await getUserInfoFromToken(event);
    if (!userInfo) {
      return {
        statusCode: 401,
        headers: corsHeaders,
        body: JSON.stringify({ message: 'Unauthorized' })
      };
    }

    console.log(`👤 User Email: ${userInfo.email}, Cognito User ID: ${userInfo.cognitoUserId}`);

    const method = event.httpMethod;

    // Route to appropriate handler based on method
    if (method === 'GET') {
      return await handleGetBusinessDetails(userInfo,event);
    } else {
      return {
        statusCode: 404,
        headers: corsHeaders,
        body: JSON.stringify({ message: 'Endpoint not found' })
      };
    }

  } catch (error) {
    if(error.status)return {statusCode:error.status,headers:corsHeaders,body:JSON.stringify({success:false,code:error.message})};
    console.error('❌ Business Details Handler Error:', error);
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
 * Extract user info from access token
 */
async function getUserInfoFromToken(event) {
  try {
    const authHeader = event.headers?.Authorization || event.headers?.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      console.log('❌ No valid authorization header found');
      return null;
    }

    const accessToken = authHeader.replace('Bearer ', '');

    // Get user info from Cognito
    const cognitoClient = new CognitoIdentityProviderClient({ 
      region: process.env.COGNITO_REGION || 'us-east-1' 
    });
    const userResponse = await cognitoClient.send(new GetUserCommand({ 
      AccessToken: accessToken 
    }));
    
    const email = userResponse.UserAttributes.find(attr => attr.Name === 'email')?.Value;
    const cognitoUserId = userResponse.Username; // This is the cognitoUserId in our tables
    
    // Email is optional for phone-only merchants; cognitoUserId is the real link.
    if (cognitoUserId) {
      console.log(`✅ Found cognitoUserId: ${cognitoUserId}`);
      return {
        email: email ? email.toLowerCase().trim() : null,
        cognitoUserId: cognitoUserId
      };
    }

    console.log('❌ No email or cognitoUserId found in Cognito user attributes');
    return null;
  } catch (error) {
    console.error('❌ Error extracting user info:', error);
    return null;
  }
}

/**
 * Get complete business details for the authenticated user
 */
async function handleGetBusinessDetails(userInfo,event={}) {
  try {
    const ids=[event.pathParameters?.businessId,event.queryStringParameters?.businessId].filter(v=>v!==undefined);
    if(ids.some(v=>typeof v!=='string'||!v.trim()||v.length>150))throw Object.assign(Error('INVALID_BRANCH_SCOPE'),{status:400});
    if(new Set(ids).size>1)throw Object.assign(Error('BRANCH_SCOPE_CONFLICT'),{status:403});
    const own=b=>b&&b.ownerId===userInfo.cognitoUserId&&b.cognitoUserId===userInfo.cognitoUserId&&!b.deletionRequestId;
    let business;
    if(ids.length){
      const r=await dynamodb.send(new GetCommand({TableName:BUSINESSES_TABLE,Key:{businessId:ids[0]},ConsistentRead:true}));
      if(!own(r.Item))throw Object.assign(Error('BUSINESS_UNAVAILABLE'),{status:404});
      business=r.Item;
    } else {
      let cursor;const owned=[];
      do {
        const r=await dynamodb.send(new ScanCommand({TableName:BUSINESSES_TABLE,ConsistentRead:true,ExclusiveStartKey:cursor,FilterExpression:'ownerId=:sub AND cognitoUserId=:sub',ExpressionAttributeValues:{':sub':userInfo.cognitoUserId}}));
        owned.push(...(r.Items||[]).filter(own));cursor=r.LastEvaluatedKey;
      } while(cursor&&owned.length<2);
      if(owned.length>1)throw Object.assign(Error('BRANCH_SELECTION_REQUIRED'),{status:409});
      if(!owned.length)throw Object.assign(Error('BUSINESS_UNAVAILABLE'),{status:404});
      business=owned[0];
    }
    console.log(`✅ Found business: ${business.businessName || business.name} (ID: ${business.businessId})`);

    // Get user details from the users table using cognitoUserId
    let userDetails = null;
    try {
      const userParams = {
        TableName: USERS_TABLE,
        FilterExpression: 'cognitoUserId = :cognitoUserId',
        ExpressionAttributeValues: {
          ':cognitoUserId': userInfo.cognitoUserId
        }
      };

      const userResult = await dynamodb.send(new ScanCommand(userParams));
      if (userResult.Items && userResult.Items.length > 0) {
        userDetails = userResult.Items[0];
        console.log(`✅ Found user details for cognitoUserId: ${userInfo.cognitoUserId}`);
      }
    } catch (userError) {
      console.log(`⚠️ Could not fetch user details: ${userError.message}`);
    }

    // Format the complete business data
    const completeBusinessData = {
      // Business identifiers
      id: business.businessId,
      businessId: business.businessId,
      
      // Basic business information
      name: business.businessName || business.name,
      businessName: business.businessName || business.name,
      email: business.email,
      phoneNumber: business.phoneNumber,
      ownerName: business.ownerName,
      businessType: business.businessType,
      
      // Business details
      description: business.description || null,
      website: business.website || null,
      businessPhotoUrl: business.businessPhotoUrl || null,
      
      // Location information
      address: business.address,
      city: business.city,
      district: business.district,
      country: business.country,
      street: business.street,
      latitude: business.latitude,
      longitude: business.longitude,
      
      // Status and metadata
      status: business.status,
      isActive: business.isActive,
      createdAt: business.createdAt,
      updatedAt: business.updatedAt,
      
      // User information (if available)
      userDetails: userDetails ? {
        userId: userDetails.userId,
        firstName: userDetails.firstName,
        lastName: userDetails.lastName,
        phoneNumber: userDetails.phoneNumber,
        emailVerified: userDetails.emailVerified,
        isActive: userDetails.isActive
      } : null
    };

    console.log(`📊 Returning complete business data for: ${completeBusinessData.name}`);

    return {
      statusCode: 200,
      headers: corsHeaders,
      body: JSON.stringify({
        success: true,
        business: completeBusinessData
      })
    };

  } catch (error) {
    if(error.status)throw error;
    console.error('❌ Error getting business details:', error);
    return {
      statusCode: 500,
      headers: corsHeaders,
      body: JSON.stringify({
        success: false,
        message: 'Failed to retrieve business details',
        error: error.message
      })
    };
  }
}
