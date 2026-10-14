const {merchantLifecycleClient,merchantHandler}=require('../shared/merchant-lifecycle');
const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { DynamoDBDocumentClient, GetCommand, PutCommand, UpdateCommand, QueryCommand, ScanCommand } = require('@aws-sdk/lib-dynamodb');
const { CognitoIdentityProviderClient, GetUserCommand } = require('@aws-sdk/client-cognito-identity-provider');
const jwt = require('jsonwebtoken');

// Initialize DynamoDB
const dynamoDbClient = new DynamoDBClient({ region: process.env.AWS_REGION || 'us-east-1' });
const lifecycleRawDb = DynamoDBDocumentClient.from(dynamoDbClient);
const dynamodb = merchantLifecycleClient(lifecycleRawDb);

// Table names from environment variables (same as other handlers)
const BUSINESSES_TABLE = process.env.BUSINESSES_TABLE || 'WhizzMerchants_Businesses';
const BUSINESS_WORKING_HOURS_TABLE = process.env.BUSINESS_WORKING_HOURS_TABLE || 'WhizzMerchants_BusinessWorkingHours';

// CORS headers
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Content-Type,Authorization',
  'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS'
};

/**
 * Location Settings Handler
 * Manages business location settings including GPS coordinates and address information
 */
exports.handler = async (event) => {
  console.log('📍 Location Settings Handler - Event:', {method:event.httpMethod,path:event.path});

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

    // Extract user information from access token (same approach as other handlers)
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
      // Validate access token with Cognito (same as unified_auth_handler)
      const cognitoClient = new CognitoIdentityProviderClient({ 
        region: process.env.COGNITO_REGION || 'us-east-1' 
      });
      const userResponse = await cognitoClient.send(new GetUserCommand({ 
        AccessToken: accessToken 
      }));
      
      // Get user ID from 'sub' attribute (same as auth handler)
      userId = userResponse.UserAttributes.find(attr => attr.Name === 'sub')?.Value || userResponse.Username;
      console.log(`🔐 Authenticated user from Cognito: ${userId}`);
      
    } catch (cognitoError) {
      console.error('❌ Cognito token validation failed:', cognitoError);
      // Fallback to JWT decode for development/testing
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

    // Get business ID from path parameters
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

    // Route to appropriate handler based on method and path
    if (method === 'GET' && path.includes('/location-settings')) {
      return await handleGetLocationSettings(businessId);
    } else if (method === 'PUT' && path.includes('/location-settings')) {
      const parsedBody = requestBody ? JSON.parse(requestBody) : {};
      return await handleUpdateLocationSettings(businessId, parsedBody);
    } else if (method === 'GET' && path.includes('/working-hours')) {
      return await handleGetWorkingHours(businessId);
    } else if (method === 'PUT' && path.includes('/working-hours')) {
      const parsedBody = requestBody ? JSON.parse(requestBody) : {};
      return await handleUpdateWorkingHours(businessId, parsedBody);
    } else {
      return {
        statusCode: 404,
        headers: corsHeaders,
        body: JSON.stringify({ message: 'Endpoint not found' })
      };
    }

  } catch (error) {
    console.error('❌ Location Settings Handler Error:', error);
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
    console.log(`🔍 DEBUG: Verifying business access`);
    console.log(`   📊 BUSINESSES_TABLE: ${BUSINESSES_TABLE}`);
    console.log(`   👤 User ID: ${userId}`);
    console.log(`   🏢 Business ID: ${businessId}`);

    const params = {
      TableName: BUSINESSES_TABLE,
      Key: { businessId: businessId }
    };
    console.log(`   🔑 Query params:`, JSON.stringify(params, null, 2));

    const result = await dynamodb.send(new GetCommand(params));
    console.log(`   📋 Query result:`, result.Item ? 'FOUND' : 'NOT FOUND');
    
    if (!result.Item) {
      console.log(`❌ Business ${businessId} not found in table ${BUSINESSES_TABLE}`);
      console.log(`   📊 Available fields: none (business not found)`);
      return false;
    }

    // Log all available fields in the business record
    const business = result.Item;
    console.log(`✅ Business found! Available fields:`, Object.keys(business));
    console.log(`   🔑 ownerId: "${business.ownerId}"`);
    console.log(`   🔑 cognitoUserId: "${business.cognitoUserId}"`);
    console.log(`   🔑 owner_id: "${business.owner_id}"`);
    console.log(`   🔑 cognito_user_id: "${business.cognito_user_id}"`);
    console.log(`   🔑 admin_users: ${JSON.stringify(business.admin_users)}`);
    console.log(`   🔑 staff_users: ${JSON.stringify(business.staff_users)}`);

    // Check if user is the owner or has access (same logic as business_profile_handler)
    const hasAccess = business.ownerId === userId ||
                      business.cognitoUserId === userId ||
                      business.admin_users?.includes(userId) ||
                      business.staff_users?.includes(userId);

    console.log(`🎯 Access check results:`);
    console.log(`   business.ownerId === userId: ${business.ownerId} === ${userId} = ${business.ownerId === userId}`);
    console.log(`   business.cognitoUserId === userId: ${business.cognitoUserId} === ${userId} = ${business.cognitoUserId === userId}`);
    console.log(`   admin_users includes userId: ${business.admin_users?.includes(userId) || false}`);
    console.log(`   staff_users includes userId: ${business.staff_users?.includes(userId) || false}`);
    console.log(`🔐 Final access result: ${hasAccess}`);

    return hasAccess;
  } catch (error) {
    console.error('❌ Error verifying business access:', error);
    return false;
  }
}

/**
 * Get location settings for a business
 */
async function handleGetLocationSettings(businessId) {
  try {
    const params = {
      TableName: BUSINESSES_TABLE,
      Key: { businessId: businessId },
      ProjectionExpression: 'latitude, longitude, address, city, district, street, country, address_components'
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
    
    // Extract location settings with individual address components
    const settings = {
      latitude: business.latitude || null,
      longitude: business.longitude || null,
      address: business.address || null,
      city: business.city || null,
      district: business.district || null,
      street: business.street || null,
      country: business.country || null
    };

    // Handle address_components if they exist
    if (business.address_components) {
      try {
        // Handle both DynamoDB format and regular format
        if (typeof business.address_components === 'object') {
          Object.keys(business.address_components).forEach(key => {
            const value = business.address_components[key];
            // Handle DynamoDB typed format like {S: "value"}
            if (value && typeof value === 'object' && value.S) {
              settings[key] = value.S;
            } else if (typeof value === 'string') {
              settings[key] = value;
            }
          });
        }
      } catch (error) {
        console.warn('⚠️ Error parsing address_components:', error);
      }
    }

    console.log('📍 Retrieved location settings:', settings);

    return {
      statusCode: 200,
      headers: corsHeaders,
      body: JSON.stringify({
        success: true,
        settings: settings
      })
    };

  } catch (error) {
    console.error('❌ Error getting location settings:', error);
    return {
      statusCode: 500,
      headers: corsHeaders,
      body: JSON.stringify({
        success: false,
        message: 'Failed to retrieve location settings',
        error: error.message
      })
    };
  }
}

/**
 * Update location settings for a business
 */
async function handleUpdateLocationSettings(businessId, requestBody) {
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

    // requestBody is already parsed by the main handler, no need to JSON.parse again
    const settings = requestBody;
    console.log('📍 Updating location settings:', settings);

    // Validate location data
    if (settings.latitude !== null && settings.latitude !== undefined) {
      const lat = parseFloat(settings.latitude);
      if (isNaN(lat) || lat < -90 || lat > 90) {
        return {
          statusCode: 400,
          headers: corsHeaders,
          body: JSON.stringify({
            success: false,
            message: 'Invalid latitude. Must be between -90 and 90 degrees.'
          })
        };
      }
      settings.latitude = lat;
    }

    if (settings.longitude !== null && settings.longitude !== undefined) {
      const lng = parseFloat(settings.longitude);
      if (isNaN(lng) || lng < -180 || lng > 180) {
        return {
          statusCode: 400,
          headers: corsHeaders,
          body: JSON.stringify({
            success: false,
            message: 'Invalid longitude. Must be between -180 and 180 degrees.'
          })
        };
      }
      settings.longitude = lng;
    }

    // Build update expression dynamically
    let updateExpression = 'SET updatedAt = :updatedAt';
    const expressionAttributeValues = {
      ':updatedAt': new Date().toISOString()
    };

    // Add each field if provided
    const locationFields = ['latitude', 'longitude', 'address', 'city', 'district', 'street', 'country'];
    locationFields.forEach(field => {
      if (settings[field] !== undefined) {
        updateExpression += `, ${field} = :${field}`;
        expressionAttributeValues[`:${field}`] = settings[field];
      }
    });

    // Also store address_components for compatibility
    if (settings.address_components) {
      updateExpression += ', address_components = :address_components';
      expressionAttributeValues[':address_components'] = settings.address_components;
    }

    const params = {
      TableName: BUSINESSES_TABLE,
      Key: { businessId: businessId },
      UpdateExpression: updateExpression,
      ExpressionAttributeValues: expressionAttributeValues,
      ReturnValues: 'ALL_NEW'
    };

    const result = await dynamodb.send(new UpdateCommand(params));

    console.log('✅ Location settings updated successfully');

    return {
      statusCode: 200,
      headers: corsHeaders,
      body: JSON.stringify({
        success: true,
        message: 'Location settings updated successfully',
        settings: {
          latitude: result.Attributes.latitude,
          longitude: result.Attributes.longitude,
          address: result.Attributes.address,
          city: result.Attributes.city,
          district: result.Attributes.district,
          street: result.Attributes.street,
          country: result.Attributes.country
        }
      })
    };

  } catch (error) {
    console.error('❌ Error updating location settings:', error);
    return {
      statusCode: 500,
      headers: corsHeaders,
      body: JSON.stringify({
        success: false,
        message: 'Failed to update location settings',
        error: error.message
      })
    };
  }
}

/**
 * Get working hours for a business
 */
async function handleGetWorkingHours(businessId) {
  try {
    console.log('🕒 Getting working hours for business:', businessId);

    // Query the separate working hours table
    const weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    
    console.log('📅 Querying working hours for weekdays:', weekdays.join(', '));
    
    const results = await Promise.all(
      weekdays.map(async (day) => {
        try {
          const result = await dynamodb.send(new GetCommand({
            TableName: BUSINESS_WORKING_HOURS_TABLE,
            Key: { 
              businessId: businessId, 
              weekday: day 
            }
          }));
          
          console.log(`📋 ${day}: ${result.Item ? 'Found data' : 'No data'}`);
          return result;
        } catch (error) {
          console.error(`❌ Error querying ${day}:`, error);
          return { Item: null }; // Return empty result on error
        }
      })
    );
    
    // Build working hours object
    const workingHours = {};
    weekdays.forEach((day, idx) => {
      const item = results[idx].Item;
      const lowerDay = day.toLowerCase();
      
      if (item) {
        // 🔥 Check if day is explicitly marked as closed or has "closed"/"none" hours
        const isClosed = item.isClosed || 
                        item.opening === 'closed' || item.closing === 'closed' ||
                        item.opening === 'none' || item.closing === 'none' || 
                        (!item.opening && !item.closing);
        workingHours[lowerDay] = {
          isOpen: !isClosed && item.opening && item.closing && 
                 item.opening !== 'closed' && item.closing !== 'closed' &&
                 item.opening !== 'none' && item.closing !== 'none',
          isClosed: isClosed,
          openTime: isClosed ? 'closed' : (item.opening || '09:00'),
          closeTime: isClosed ? 'closed' : (item.closing || '21:00')
        };
      } else {
        // Default to closed if no data exists
        workingHours[lowerDay] = {
          isOpen: false,
          isClosed: true,
          openTime: 'closed',
          closeTime: 'closed'
        };
      }
    });
    
    console.log('✅ Successfully retrieved working hours for business:', businessId);
    console.log('📊 Working hours data:', JSON.stringify(workingHours, null, 2));
    
    return {
      statusCode: 200,
      headers: corsHeaders,
      body: JSON.stringify({
        success: true,
        workingHours: workingHours
      })
    };

  } catch (error) {
    console.error('❌ Error getting working hours:', error);
    return {
      statusCode: 500,
      headers: corsHeaders,
      body: JSON.stringify({
        success: false,
        message: 'Failed to retrieve working hours',
        error: error.message
      })
    };
  }
}

/**
 * Get default working hours structure
 */
function getDefaultWorkingHours() {
  return {
    Monday: { opening: null, closing: null, isOpen: false },
    Tuesday: { opening: null, closing: null, isOpen: false },
    Wednesday: { opening: null, closing: null, isOpen: false },
    Thursday: { opening: null, closing: null, isOpen: false },
    Friday: { opening: null, closing: null, isOpen: false },
    Saturday: { opening: null, closing: null, isOpen: false },
    Sunday: { opening: null, closing: null, isOpen: false }
  };
}

/**
 * Update working hours for a business
 */
async function handleUpdateWorkingHours(businessId, requestBody) {
  try {
    console.log('🕒 Working hours update requested for business:', businessId);
    console.log('📄 Request body:', JSON.stringify(requestBody, null, 2));

    const { workingHours } = requestBody;

    if (!workingHours) {
      console.log('❌ Missing workingHours in request body');
      return {
        statusCode: 400,
        headers: corsHeaders,
        body: JSON.stringify({
          success: false,
          message: 'Working hours data is required'
        })
      };
    }

    console.log('📋 Working hours data received:', JSON.stringify(workingHours, null, 2));

    // Validate working hours format
    if (typeof workingHours !== 'object' || workingHours === null) {
      console.log('❌ Working hours is not an object:', typeof workingHours, workingHours);
      return {
        statusCode: 400,
        headers: corsHeaders,
        body: JSON.stringify({
          success: false,
          message: 'Working hours must be an object'
        })
      };
    }

    // Validate time format for each day to catch format issues early
    for (const [day, dayData] of Object.entries(workingHours)) {
      if (dayData && typeof dayData === 'object') {
        const openTime = dayData.openTime || dayData.opening;
        const closeTime = dayData.closeTime || dayData.closing;
        
        if (dayData.isOpen && openTime && closeTime) {
          // Validate time format (HH:MM)
          const timeRegex = /^([01]?[0-9]|2[0-3]):[0-5][0-9]$/;
          if (!timeRegex.test(openTime)) {
            console.log(`❌ Invalid opening time format for ${day}: ${openTime}`);
            return {
              statusCode: 400,
              headers: corsHeaders,
              body: JSON.stringify({
                success: false,
                message: `Invalid opening time format for ${day}: ${openTime}. Expected HH:MM format.`
              })
            };
          }
          if (!timeRegex.test(closeTime)) {
            console.log(`❌ Invalid closing time format for ${day}: ${closeTime}`);
            return {
              statusCode: 400,
              headers: corsHeaders,
              body: JSON.stringify({
                success: false,
                message: `Invalid closing time format for ${day}: ${closeTime}. Expected HH:MM format.`
              })
            };
          }
        }
      }
    }

    console.log('✅ Working hours validation passed, proceeding with save');

    // Save each day to the separate working hours table
    const weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    
    const updatePromises = weekdays.map(async (day) => {
      // Get data for this day from request (handle both cases: 'monday' and 'Monday')
      const lowerDay = day.toLowerCase();
      const dayData = workingHours[lowerDay] || workingHours[day] || {};
      
      // Enhanced logic for closed days
      let opening = null;
      let closing = null;
      let isClosed = false;
      
      if (dayData.isOpen === false || dayData.isClosed === true) {
        // 🔥 Day is explicitly marked as closed - store "closed" instead of null
        opening = 'closed';
        closing = 'closed';
        isClosed = true;
        console.log(`🚫 ${day}: Day is closed`);
      } else if (dayData.isOpen === true && dayData.openTime && dayData.closeTime && 
                 dayData.openTime !== 'closed' && dayData.closeTime !== 'closed' &&
                 dayData.openTime !== 'none' && dayData.closeTime !== 'none') {
        // Day is open with specified hours (not "closed" or "none")
        opening = dayData.openTime || dayData.opening;
        closing = dayData.closeTime || dayData.closing;
        isClosed = false;
        console.log(`✅ ${day}: Open from ${opening} to ${closing}`);
      } else {
        // 🔥 Default to closed if no clear indication or if hours are "closed"/"none"
        opening = 'closed';
        closing = 'closed';
        isClosed = true;
        console.log(`⚠️  ${day}: No clear hours provided or hours are "closed"/"none", defaulting to closed`);
      }
      
      console.log(`📝 Saving ${day}: isClosed=${isClosed}, opening="${opening}", closing="${closing}"`);
      
      try {
        const result = await dynamodb.send(new PutCommand({
          TableName: BUSINESS_WORKING_HOURS_TABLE,
          Item: {
            businessId: businessId,
            weekday: day,
            opening: opening,
            closing: closing,
            isClosed: isClosed,
            updatedAt: new Date().toISOString()
          }
        }));
        
        console.log(`✅ Updated ${day} for business ${businessId}`);
        return result;
      } catch (error) {
        console.error(`❌ Error updating ${day} for business ${businessId}:`, error);
        throw error;
      }
    });
    
    await Promise.all(updatePromises);
    
    console.log(`✅ Successfully updated all working hours for business ${businessId}`);
    
    return {
      statusCode: 200,
      headers: corsHeaders,
      body: JSON.stringify({
        success: true,
        message: 'Working hours updated successfully'
      })
    };

  } catch (error) {
    console.error('❌ Error updating working hours:', error);
    return {
      statusCode: 500,
      headers: corsHeaders,
      body: JSON.stringify({
        success: false,
        message: 'Failed to update working hours',
        error: error.message
      })
    };
  }
}

module.exports.handler=merchantHandler(module.exports.handler,{db:lifecycleRawDb});
