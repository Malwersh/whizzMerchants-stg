const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { DynamoDBDocumentClient, GetCommand, DeleteCommand, QueryCommand } = require('@aws-sdk/lib-dynamodb');
const { 
  CognitoIdentityProviderClient, 
  GetUserCommand, 
  AdminDeleteUserCommand,
  InitiateAuthCommand,
  AdminInitiateAuthCommand
} = require('@aws-sdk/client-cognito-identity-provider');
const jwt = require('jsonwebtoken');

// Initialize DynamoDB
const dynamoDbClient = new DynamoDBClient({ region: process.env.AWS_REGION || 'us-east-1' });
const dynamodb = DynamoDBDocumentClient.from(dynamoDbClient);

// Initialize Cognito
const cognitoClient = new CognitoIdentityProviderClient({ 
  region: process.env.COGNITO_REGION || 'us-east-1' 
});

// Table names from environment variables
const BUSINESSES_TABLE = process.env.BUSINESSES_TABLE || 'WhizzMerchants_Businesses';
const USERS_TABLE = process.env.USERS_TABLE || 'WhizzMerchants_Users';
const PRODUCTS_TABLE = process.env.PRODUCTS_TABLE || 'WhizzMerchants_Products';
const CATEGORIES_TABLE = process.env.CATEGORIES_TABLE || 'WhizzMerchants_Categories';
const DISCOUNTS_TABLE = process.env.DISCOUNTS_TABLE || 'WhizzMerchants_Discounts';
const BUSINESS_SETTINGS_TABLE = process.env.BUSINESS_SETTINGS_TABLE || 'WhizzMerchants_BusinessSettings';
const BUSINESS_WORKING_HOURS_TABLE = process.env.BUSINESS_WORKING_HOURS_TABLE || 'WhizzMerchants_BusinessWorkingHours';
const COGNITO_USER_POOL_ID = process.env.COGNITO_USER_POOL_ID;

// CORS headers
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Content-Type,Authorization',
  'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS'
};

/**
 * Delete Business Handler
 * Permanently deletes a business account and all associated data
 * This includes:
 * - Business profile
 * - Products
 * - Categories
 * - Discounts
 * - Settings
 * - Working hours
 * - Cognito user account (optional)
 */
exports.handler = async (event) => {
  console.log('🗑️ Delete Business Event:', JSON.stringify(event, null, 2));

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

    // Parse request body for password verification
    let password = null;
    if (event.body) {
      try {
        const body = JSON.parse(event.body);
        password = body.password;
      } catch (e) {
        console.log('⚠️ No password provided in body, will skip password verification');
      }
    }

    console.log(`👤 User ID: ${userId}, 🏢 Business ID to delete: ${businessId}`);

    // Verify user has access to this business (must be owner)
    const business = await getBusinessById(businessId);
    if (!business) {
      return {
        statusCode: 404,
        headers: corsHeaders,
        body: JSON.stringify({ message: 'Business not found' })
      };
    }

    // Check if user is the owner
    const isOwner = business.ownerId === userId || business.cognitoUserId === userId;
    if (!isOwner) {
      return {
        statusCode: 403,
        headers: corsHeaders,
        body: JSON.stringify({ 
          message: 'Only the business owner can delete this account' 
        })
      };
    }

    // If password is provided, verify it with Cognito
    if (password) {
      console.log('🔐 Verifying password before deletion...');
      const passwordValid = await verifyUserPassword(userId, password);
      if (!passwordValid) {
        console.log('❌ Invalid password provided');
        return {
          statusCode: 401,
          headers: corsHeaders,
          body: JSON.stringify({ message: 'Invalid password' })
        };
      }
      console.log('✅ Password verified successfully');
    }

    console.log('✅ User verified as business owner, proceeding with deletion...');

    // Delete all associated data
    const deletionResults = await deleteAllBusinessData(businessId, userId);

    console.log('✅ Business deletion completed:', deletionResults);

    return {
      statusCode: 200,
      headers: corsHeaders,
      body: JSON.stringify({ 
        message: 'Business account deleted successfully',
        deletedItems: deletionResults
      })
    };

  } catch (error) {
    console.error('❌ Delete Business Handler Error:', error);
    return {
      statusCode: 500,
      headers: corsHeaders,
      body: JSON.stringify({ 
        message: 'Failed to delete business account',
        error: error.message 
      })
    };
  }
};

/**
 * Delete all business-related data
 */
async function deleteAllBusinessData(businessId, userId) {
  const results = {
    products: 0,
    categories: 0,
    discounts: 0,
    settings: 0,
    workingHours: 0,
    business: false,
    user: false,
    cognitoUser: false
  };

  try {
    // 1. Delete all products
    console.log('🗑️ Deleting products...');
    const products = await queryItemsByBusinessId(PRODUCTS_TABLE, businessId);
    for (const product of products) {
      await dynamodb.send(new DeleteCommand({
        TableName: PRODUCTS_TABLE,
        Key: { productId: product.productId }
      }));
      results.products++;
    }
    console.log(`✅ Deleted ${results.products} products`);

    // 2. Skip category deletion - Categories are shared across all merchants
    console.log('⏭️  Skipping categories (shared resource)...');
    results.categories = 0; // Categories are not deleted as they're shared

    // 3. Delete all discounts
    console.log('🗑️ Deleting discounts...');
    const discounts = await queryItemsByBusinessId(DISCOUNTS_TABLE, businessId);
    for (const discount of discounts) {
      await dynamodb.send(new DeleteCommand({
        TableName: DISCOUNTS_TABLE,
        Key: { discountId: discount.discountId }
      }));
      results.discounts++;
    }
    console.log(`✅ Deleted ${results.discounts} discounts`);

    // 4. Delete business settings
    console.log('🗑️ Deleting business settings...');
    try {
      await dynamodb.send(new DeleteCommand({
        TableName: BUSINESS_SETTINGS_TABLE,
        Key: { businessId: businessId }
      }));
      results.settings = 1;
      console.log('✅ Deleted business settings');
    } catch (error) {
      console.log('⚠️ No settings to delete or error:', error.message);
    }

    // 5. Delete working hours
    console.log('🗑️ Deleting working hours...');
    try {
      await dynamodb.send(new DeleteCommand({
        TableName: BUSINESS_WORKING_HOURS_TABLE,
        Key: { businessId: businessId }
      }));
      results.workingHours = 1;
      console.log('✅ Deleted working hours');
    } catch (error) {
      console.log('⚠️ No working hours to delete or error:', error.message);
    }

    // 6. Delete the business itself
    console.log('🗑️ Deleting business profile...');
    await dynamodb.send(new DeleteCommand({
      TableName: BUSINESSES_TABLE,
      Key: { businessId: businessId }
    }));
    results.business = true;
    console.log('✅ Deleted business profile');

    // 7. Delete user record from users table
    console.log('🗑️ Deleting user record...');
    try {
      await dynamodb.send(new DeleteCommand({
        TableName: USERS_TABLE,
        Key: { userId: userId }
      }));
      results.user = true;
      console.log('✅ Deleted user record');
    } catch (error) {
      console.log('⚠️ Error deleting user record:', error.message);
    }

    // 8. Delete Cognito user (optional - comment out if you want to keep Cognito user)
    console.log('🗑️ Deleting Cognito user...');
    try {
      if (COGNITO_USER_POOL_ID) {
        await cognitoClient.send(new AdminDeleteUserCommand({
          UserPoolId: COGNITO_USER_POOL_ID,
          Username: userId
        }));
        results.cognitoUser = true;
        console.log('✅ Deleted Cognito user');
      }
    } catch (error) {
      console.log('⚠️ Error deleting Cognito user (user may need to be deleted manually):', error.message);
    }

  } catch (error) {
    console.error('❌ Error during deletion process:', error);
    throw error;
  }

  return results;
}

/**
 * Query items by businessId
 */
async function queryItemsByBusinessId(tableName, businessId) {
  try {
    const params = {
      TableName: tableName,
      FilterExpression: 'businessId = :businessId',
      ExpressionAttributeValues: {
        ':businessId': businessId
      }
    };

    const result = await dynamodb.send(new QueryCommand(params));
    return result.Items || [];
  } catch (error) {
    console.error(`❌ Error querying ${tableName}:`, error);
    return [];
  }
}

/**
 * Get business by ID
 */
async function getBusinessById(businessId) {
  try {
    const params = {
      TableName: BUSINESSES_TABLE,
      Key: { businessId: businessId }
    };

    const result = await dynamodb.send(new GetCommand(params));
    return result.Item || null;
  } catch (error) {
    console.error('❌ Error getting business:', error);
    return null;
  }
}

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
      const userResponse = await cognitoClient.send(new GetUserCommand({ 
        AccessToken: accessToken 
      }));
      
      return userResponse.Username;
    } catch (cognitoError) {
      console.log('⚠️ Cognito lookup failed, trying JWT decode:', cognitoError.message);
    }

    // Fallback to JWT decode
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
 * Verify user password by attempting authentication with Cognito
 * This re-authenticates the user to ensure they know their password before deletion
 */
async function verifyUserPassword(username, password) {
  try {
    // Get user details to find their email
    const userParams = {
      TableName: USERS_TABLE,
      Key: { userId: username }
    };
    
    const userResult = await dynamodb.send(new GetCommand(userParams));
    const user = userResult.Item;
    
    if (!user || !user.email) {
      console.log('❌ User not found or no email');
      return false;
    }

    // Try to authenticate with Cognito using the email and password
    // If successful, password is correct
    const authParams = {
      AuthFlow: 'USER_PASSWORD_AUTH',
      ClientId: process.env.COGNITO_CLIENT_ID,
      AuthParameters: {
        USERNAME: user.email,
        PASSWORD: password
      }
    };

    try {
      const authResponse = await cognitoClient.send(new InitiateAuthCommand(authParams));
      // If we get here without error, password is valid
      console.log('✅ Password verification successful');
      return true;
    } catch (authError) {
      console.log('❌ Password verification failed:', authError.name);
      // NotAuthorizedException means wrong password
      // UserNotFoundException means user doesn't exist
      return false;
    }
  } catch (error) {
    console.error('❌ Error verifying password:', error);
    return false;
  }
}
