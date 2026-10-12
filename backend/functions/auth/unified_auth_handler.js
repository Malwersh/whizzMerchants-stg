const { CognitoIdentityProviderClient, AdminGetUserCommand, SignUpCommand, ConfirmSignUpCommand, InitiateAuthCommand, ResendConfirmationCodeCommand, GetUserCommand } = require('@aws-sdk/client-cognito-identity-provider');
const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { DynamoDBDocumentClient, PutCommand, QueryCommand, DeleteCommand, ScanCommand } = require('@aws-sdk/lib-dynamodb');

// Import WebSocket service for login tracking
const websocketService = require('./websocket_service');

const cognitoClient = new CognitoIdentityProviderClient({ region: 'us-east-1' });
const dynamoClient = new DynamoDBClient({ region: 'us-east-1' });
const dynamodb = DynamoDBDocumentClient.from(dynamoClient);

const headers = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'Content-Type,Authorization',
    'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS',
};

// Helper function to create response
function createResponse(statusCode, body) {
    return {
        statusCode,
        headers,
        body: JSON.stringify(body),
    };
}

// Helper function to find regionId by coordinates using API
async function findRegionByCoordinates(latitude, longitude) {
    try {
        console.log(`🗺️ البحث عن regionId للإحداثيات: ${latitude}, ${longitude}`);
        
        const wizzUserApiBaseUrl = process.env.WIZZUSER_API_BASE_URL;
        if (!wizzUserApiBaseUrl) {
            throw new Error('Missing required env var: WIZZUSER_API_BASE_URL');
        }

        const base = wizzUserApiBaseUrl.replace(/\/$/, '');
        const apiUrl = `${base}/api/regions/find-by-coordinates?latitude=${latitude}&longitude=${longitude}`;
        
        console.log(`📡 استدعاء API: ${apiUrl}`);
        
        const https = require('https');
        const url = require('url');
        
        // Make HTTP GET request
        const result = await new Promise((resolve, reject) => {
            const parsedUrl = url.parse(apiUrl);
            const options = {
                hostname: parsedUrl.hostname,
                path: parsedUrl.path,
                method: 'GET',
                timeout: 5000
            };
            
            const req = https.request(options, (res) => {
                let data = '';
                res.on('data', (chunk) => { data += chunk; });
                res.on('end', () => {
                    try {
                        const parsed = JSON.parse(data);
                        resolve(parsed);
                    } catch (e) {
                        reject(new Error('Invalid JSON response'));
                    }
                });
            });
            
            req.on('error', reject);
            req.on('timeout', () => {
                req.destroy();
                reject(new Error('Request timeout'));
            });
            
            req.end();
        });
        
        const resolvedRegionId = result.data?.region_id || result.data?.regionId;
        if (result.success && typeof resolvedRegionId === 'string' && resolvedRegionId.trim()) {
            const regionId = resolvedRegionId.trim();
            console.log(`✅ تم العثور على المنطقة: ${regionId}`);
            return regionId;
        } else {
            console.log(`⚠️ لم يتم العثور على منطقة للإحداثيات المحددة`);
            return null;
        }
    } catch (error) {
        console.error('❌ خطأ في البحث عن regionId:', error.message);
        console.log('⚠️ سيتم حفظ المطعم بدون regionId، يمكن إضافته لاحقاً');
        return null;
    }
}

module.exports.handler = async (event) => {
    console.log('Received event in Auth Handler:', JSON.stringify(event, null, 2));
    const { httpMethod, path } = event;

    if (httpMethod === 'OPTIONS') {
        return createResponse(204, {});
    }

    try {
        // Handle health check
        if (path === '/auth/health') {
            return createResponse(200, {
                success: true,
                message: 'Auth service is healthy',
                timestamp: new Date().toISOString(),
                version: '1.1.0' // Added version to force deployment
            });
        }

        // Handle get user by email for password reset validation
        if (path === '/auth/get-user-by-email' && httpMethod === 'POST') {
            const body = JSON.parse(event.body || '{}');
            const { email } = body;

            if (!email) {
                return createResponse(400, {
                    success: false,
                    message: 'Email is required'
                });
            }

            try {
                // Check if user exists in Cognito without sending emails
                const params = {
                    UserPoolId: process.env.COGNITO_USER_POOL_ID,
                    Username: email
                };

                const command = new AdminGetUserCommand(params);
                const userResponse = await cognitoClient.send(command);

                // User exists, check status
                const userStatus = userResponse.UserStatus;
                const isConfirmed = userStatus === 'CONFIRMED';

                return createResponse(200, {
                    success: true,
                    user: {
                        email: email,
                        status: isConfirmed ? 'confirmed' : 'unconfirmed',
                        userStatus: userStatus
                    },
                    message: isConfirmed
                        ? 'User found and confirmed'
                        : 'User found but not confirmed'
                });

            } catch (cognitoError) {
                if (cognitoError.code === 'UserNotFoundException') {
                    return createResponse(200, {
                        success: false,
                        message: 'User does not exist',
                        error: 'USER_NOT_FOUND'
                    });
                } else {
                    console.error('Cognito error:', cognitoError);
                    return createResponse(500, {
                        success: false,
                        message: 'Error checking user status',
                        error: cognitoError.message
                    });
                }
            }
        }

        // Handle registration with business data
        if (path === '/auth/register-with-business' && httpMethod === 'POST') {
            const body = JSON.parse(event.body || '{}');
            const { 
                email, 
                password, 
                businessName, 
                firstName, 
                lastName, 
                businessType, 
                phoneNumber, 
                address, 
                businessPhotoUrl,
                licenseUrl,
                identityUrl,
                healthCertificateUrl,
                ownerPhotoUrl
            } = body;

            // Phone-only auth: phone is the Cognito username; email is optional contact info.
            if (!phoneNumber || !businessName || !firstName || !lastName) {
                return createResponse(400, {
                    success: false,
                    message: 'Phone number, business name, first name, and last name are required'
                });
            }

            try {
                // Format phone number to international format for Cognito
                let formattedPhoneNumber = '+1234567890'; // Default fallback
                if (phoneNumber) {
                    // Remove any spaces, dashes, or other formatting
                    const cleanPhone = phoneNumber.replace(/[\s\-\(\)]/g, '');
                    
                    if (cleanPhone.startsWith('+')) {
                        // Already international format
                        formattedPhoneNumber = cleanPhone;
                    } else if (cleanPhone.startsWith('07') && cleanPhone.length === 11) {
                        // Iraqi mobile format: 07XXXXXXXXX -> +9647XXXXXXXXX
                        formattedPhoneNumber = '+964' + cleanPhone.substring(1);
                    } else if (cleanPhone.startsWith('964') && cleanPhone.length === 14) {
                        // Iraq format without +: 964XXXXXXXXXXX -> +964XXXXXXXXXXX
                        formattedPhoneNumber = '+' + cleanPhone;
                    } else if (cleanPhone.startsWith('0') && cleanPhone.length >= 10) {
                        // Generic format starting with 0: assume Iraq
                        formattedPhoneNumber = '+964' + cleanPhone.substring(1);
                    } else if (cleanPhone.length >= 10) {
                        // Assume it's missing country code, add Iraq
                        formattedPhoneNumber = '+964' + cleanPhone;
                    }
                }
                
                console.log('Phone number formatting:', phoneNumber, '->', formattedPhoneNumber);

                if (!/^\+9647\d{9}$/.test(formattedPhoneNumber)) {
                    return createResponse(400, {
                        success: false,
                        message: 'Please enter a valid Iraqi mobile number (07XXXXXXXXX)'
                    });
                }

                // Create user in Cognito. SignUp requires a password, but the pool only allows
                // CUSTOM_AUTH (OTP), so a random unusable password is set and never stored.
                const cleanEmail = email ? email.toLowerCase().trim() : null;
                const userAttributes = [
                    { Name: 'phone_number', Value: formattedPhoneNumber },
                    { Name: 'given_name', Value: firstName },
                    { Name: 'family_name', Value: lastName },
                    { Name: 'name', Value: `${firstName} ${lastName}` },
                ];
                if (cleanEmail) userAttributes.push({ Name: 'email', Value: cleanEmail });

                const signUpParams = {
                    ClientId: process.env.COGNITO_CLIENT_ID,
                    Username: formattedPhoneNumber,
                    Password: require('crypto').randomBytes(24).toString('base64') + 'aA1!',
                    UserAttributes: userAttributes,
                };

                const signUpCommand = new SignUpCommand(signUpParams);
                const signUpResponse = await cognitoClient.send(signUpCommand);
                console.log('User created in Cognito:', signUpResponse.UserSub);

                // Generate unique IDs
                const businessId = `business_${Date.now()}_${Math.random().toString(36).substring(2, 15)}`;
                const ownerId = signUpResponse.UserSub;
                const currentTime = new Date().toISOString();

                // 🆕 Automatically find regionId if coordinates are provided
                let regionId = null;
                if (address?.latitude && address?.longitude) {
                    console.log('🔍 محاولة تحديد regionId تلقائياً من الإحداثيات...');
                    regionId = await findRegionByCoordinates(address.latitude, address.longitude);
                    if (regionId) {
                        console.log(`✅ تم تعيين regionId تلقائياً: ${regionId}`);
                    } else {
                        console.log('⚠️ لم يتم العثور على regionId، سيتم حفظ المطعم بدون regionId');
                    }
                }

                // Create business entry in DynamoDB
                // NOTE: email is omitted (not null) when absent — the email-index GSI
                // rejects NULL-typed key attributes.
                const businessData = {
                    businessId: businessId,
                    businessName: businessName,
                    businessType: businessType || 'restaurant',
                    ...(cleanEmail ? { email: cleanEmail } : {}),
                    ownerName: `${firstName} ${lastName}`,
                    phoneNumber: formattedPhoneNumber,
                    ownerId: ownerId,
                    cognitoUserId: signUpResponse.UserSub,
                    status: 'pending', // Pending approval
                    isActive: true,
                    createdAt: currentTime,
                    updatedAt: currentTime,
                    businessPhotoUrl: businessPhotoUrl || null,
                    licenseUrl: licenseUrl || null,
                    identityUrl: identityUrl || null,
                    healthCertificateUrl: healthCertificateUrl || null,
                    ownerPhotoUrl: ownerPhotoUrl || null,
                    address: address || {},
                    city: address?.city || '',
                    country: address?.country || 'Iraq',
                    district: address?.district || '',
                    street: address?.street || '',
                    regionId: regionId // 🆕 Add regionId automatically
                };

                // Save business to DynamoDB
                const businessCommand = new PutCommand({
                    TableName: process.env.BUSINESSES_TABLE || 'WhizzMerchants_Businesses',
                    Item: businessData
                });

                await dynamodb.send(businessCommand);
                console.log('Business created in DynamoDB:', businessId);

                // Create user entry in DynamoDB (if using separate users table)
                const userData = {
                    userId: signUpResponse.UserSub,
                    ...(cleanEmail ? { email: cleanEmail } : {}),
                    firstName: firstName,
                    lastName: lastName,
                    fullName: `${firstName} ${lastName}`,
                    phoneNumber: formattedPhoneNumber,
                    userType: 'business_owner',
                    cognitoUserId: signUpResponse.UserSub,
                    primaryBusinessId: businessId,
                    status: 'pending_verification',
                    isActive: true,
                    createdAt: currentTime,
                    updatedAt: currentTime
                };

                // Save user to DynamoDB (if users table exists)
                try {
                    const userCommand = new PutCommand({
                        TableName: process.env.USERS_TABLE || 'WhizzMerchants_Users',
                        Item: userData
                    });
                    await dynamodb.send(userCommand);
                    console.log('User created in DynamoDB:', signUpResponse.UserSub);
                } catch (userError) {
                    console.log('Users table not found or error saving user:', userError.message);
                    // Continue anyway - business is the main entity
                }

                return createResponse(200, {
                    success: true,
                    message: 'Registration successful. Sign in with the code sent to your phone.',
                    user_sub: signUpResponse.UserSub,
                    business_id: businessId,
                    code_delivery_details: signUpResponse.CodeDeliveryDetails,
                    business_data: {
                        businessId: businessId,
                        businessName: businessName,
                        status: 'pending'
                    }
                });

            } catch (cognitoError) {
                console.error('Cognito registration error:', cognitoError);
                if ((cognitoError.name === 'UsernameExistsException' || cognitoError.code === 'UsernameExistsException')) {
                    return createResponse(400, {
                        success: false,
                        message: 'An account with this phone number already exists. Please sign in instead.'
                    });
                }
                return createResponse(500, {
                    success: false,
                    message: 'Registration failed',
                    error: cognitoError.message
                });
            }
        }

        // Handle email verification
        if (path === '/auth/confirm' && httpMethod === 'POST') {
            const body = JSON.parse(event.body || '{}');
            const { email, verificationCode } = body;

            if (!email || !verificationCode) {
                return createResponse(400, {
                    success: false,
                    message: 'Email and verification code are required'
                });
            }

            try {
                const confirmParams = {
                    ClientId: process.env.COGNITO_CLIENT_ID,
                    Username: email,
                    ConfirmationCode: verificationCode
                };

                const confirmCommand = new ConfirmSignUpCommand(confirmParams);
                await cognitoClient.send(confirmCommand);
                console.log('User confirmed successfully:', email);

                return createResponse(200, {
                    success: true,
                    message: 'Email verification successful! Your account is now active.',
                    user: { email: email },
                    business: null // Business data would be populated from DynamoDB here
                });

            } catch (cognitoError) {
                console.error('Cognito confirmation error:', cognitoError);
                if (cognitoError.code === 'CodeMismatchException') {
                    return createResponse(400, {
                        success: false,
                        message: 'Invalid verification code. Please check the code and try again.'
                    });
                }
                if (cognitoError.code === 'ExpiredCodeException') {
                    return createResponse(400, {
                        success: false,
                        message: 'Verification code has expired. Please request a new code.'
                    });
                }
                return createResponse(500, {
                    success: false,
                    message: 'Email verification failed',
                    error: cognitoError.message
                });
            }
        }

        // Handle resend verification code
        if (path === '/auth/resend-code' && httpMethod === 'POST') {
            const body = JSON.parse(event.body || '{}');
            const { email } = body;

            if (!email) {
                return createResponse(400, {
                    success: false,
                    message: 'Email is required'
                });
            }

            try {
                const resendParams = {
                    ClientId: process.env.COGNITO_CLIENT_ID,
                    Username: email
                };

                const resendCommand = new ResendConfirmationCodeCommand(resendParams);
                const resendResponse = await cognitoClient.send(resendCommand);
                console.log('Verification code resent to:', email);

                return createResponse(200, {
                    success: true,
                    message: 'Verification code resent successfully. Please check your email.',
                    code_delivery_details: resendResponse.CodeDeliveryDetails
                });

            } catch (cognitoError) {
                console.error('Cognito resend error:', cognitoError);
                if (cognitoError.code === 'UserNotFoundException') {
                    return createResponse(400, {
                        success: false,
                        message: 'No account found with this email address.'
                    });
                }
                return createResponse(500, {
                    success: false,
                    message: 'Failed to resend verification code',
                    error: cognitoError.message
                });
            }
        }

        // Handle login/signin
        if (path === '/auth/signin' && httpMethod === 'POST') {
            const body = JSON.parse(event.body || '{}');
            const { email, password } = body;

            if (!email || !password) {
                return createResponse(400, {
                    success: false,
                    message: 'Email and password are required'
                });
            }

            try {
                const authParams = {
                    ClientId: process.env.COGNITO_CLIENT_ID,
                    AuthFlow: 'USER_PASSWORD_AUTH',
                    AuthParameters: {
                        USERNAME: email,
                        PASSWORD: password
                    }
                };

                const authCommand = new InitiateAuthCommand(authParams);
                const authResponse = await cognitoClient.send(authCommand);

                if (authResponse.AuthenticationResult) {
                    const tokens = authResponse.AuthenticationResult;

                    // Get user info from Cognito
                    const getUserParams = {
                        UserPoolId: process.env.COGNITO_USER_POOL_ID,
                        Username: email
                    };

                    const getUserCommand = new AdminGetUserCommand(getUserParams);
                    const userResponse = await cognitoClient.send(getUserCommand);

                    // Extract user attributes
                    const userAttributes = {};
                    userResponse.UserAttributes?.forEach(attr => {
                        userAttributes[attr.Name] = attr.Value;
                    });

                    const user = {
                        email: email,
                        userId: userResponse.Username,
                        sub: userAttributes['sub'],
                        firstName: userAttributes['given_name'],
                        lastName: userAttributes['family_name'],
                        phoneNumber: userAttributes['phone_number'],
                        email_verified: userAttributes['email_verified'] === 'true'
                    };

                    // Query real business data from DynamoDB
                    let businesses = [];
                    try {
                        const businessQueryParams = {
                            TableName: process.env.BUSINESSES_TABLE || 'WhizzMerchants_Businesses',
                            IndexName: 'email-index',
                            KeyConditionExpression: 'email = :email',
                            ExpressionAttributeValues: {
                                ':email': email.toLowerCase().trim()
                            }
                        };

                        const businessResult = await dynamodb.send(new QueryCommand(businessQueryParams));

                        if (businessResult.Items && businessResult.Items.length > 0) {
                            businesses = businessResult.Items.map(business => ({
                                businessId: business.businessId,
                                name: business.businessName || business.name,
                                email: business.email,
                                ownerId: business.ownerId,
                                cognitoUserId: business.cognitoUserId,
                                status: business.status || 'approved',
                                businessType: business.businessType || 'restaurant',
                                address: business.address,
                                phoneNumber: business.phoneNumber || business.phone,
                                city: business.city,
                                district: business.district,
                                country: business.country
                            }));
                            console.log(`✅ Found ${businesses.length} businesses for user: ${email}`);
                            
                            // Check if any business has pending status
                            const hasPendingBusiness = businesses.some(business => business.status === 'pending');
                            if (hasPendingBusiness) {
                                console.log(`⚠️ User ${email} has pending business status - blocking login`);
                                return createResponse(200, {
                                    success: false,
                                    message: 'Your account is currently under review. Please wait for approval before accessing your account.',
                                    accountStatus: 'pending',
                                    businesses: businesses
                                });
                            }
                        } else {
                            console.log(`⚠️ No businesses found for user: ${email}`);
                            // Create a fallback business entry if none exists
                            businesses = [{
                                businessId: `business_${user.userId}`,
                                name: `Business for ${user.firstName} ${user.lastName}`,
                                email: email,
                                ownerId: user.userId,
                                cognitoUserId: user.sub,
                                status: 'approved',
                                businessType: 'restaurant',
                                address: 'Default Address',
                                phoneNumber: user.phoneNumber || '+1234567890'
                            }];
                        }
                    } catch (businessError) {
                        console.error('Error querying businesses:', businessError);
                        // Create a fallback business entry if query fails
                        businesses = [{
                            businessId: `business_${user.userId}`,
                            name: `Business for ${user.firstName} ${user.lastName}`,
                            email: email,
                            ownerId: user.userId,
                            cognitoUserId: user.sub,
                            status: 'approved',
                            businessType: 'restaurant',
                            address: 'Default Address',
                            phoneNumber: user.phoneNumber || '+1234567890'
                        }];
                    }

                    // ✅ CREATE WEBSOCKET CONNECTION FOR LOGIN TRACKING
                    // This creates a REAL WebSocket connection entry in the shared WebSocket connections table
                    // matching the customer app structure for consistent order assignment
                    if (businesses && businesses.length > 0) {
                        const primaryBusiness = businesses[0];
                        try {
                            console.log(`📡 Creating WebSocket connection for merchant login: ${primaryBusiness.businessId}`);
                            await websocketService.handleUserLogin(
                                primaryBusiness.businessId,
                                user.sub, // Use Cognito sub as userId
                                email,
                                {
                                    platform: 'ios',
                                    appVersion: '1.0.0',
                                    source: 'merchant_login'
                                }
                            );
                            console.log(`✅ WebSocket connection created for merchant: ${email}`);
                        } catch (wsError) {
                            // Don't fail login if WebSocket creation fails
                            console.error('⚠️ Failed to create WebSocket connection on login:', wsError);
                            console.error('   Login will proceed, but connection tracking may be missing');
                        }
                    }

                    return createResponse(200, {
                        success: true,
                        message: 'Sign in successful',
                        user: user,
                        businesses: businesses,
                        // Tokens with Flutter-compatible naming
                        access_token: tokens.AccessToken,
                        id_token: tokens.IdToken,
                        refresh_token: tokens.RefreshToken,
                        expires_in: tokens.ExpiresIn,
                        token_type: tokens.TokenType,
                        // Legacy format for backward compatibility
                        data: {
                            AccessToken: tokens.AccessToken,
                            IdToken: tokens.IdToken,
                            RefreshToken: tokens.RefreshToken,
                            ExpiresIn: tokens.ExpiresIn,
                            TokenType: tokens.TokenType
                        }
                    });
                } else {
                    return createResponse(401, {
                        success: false,
                        message: 'Authentication failed'
                    });
                }

            } catch (cognitoError) {
                console.error('Cognito signin error:', cognitoError);

                if (cognitoError.name === 'NotAuthorizedException') {
                    return createResponse(401, {
                        success: false,
                        message: 'Invalid email or password'
                    });
                }
                if (cognitoError.name === 'UserNotConfirmedException') {
                    return createResponse(400, {
                        success: false,
                        message: 'User is not confirmed. Please verify your email first.'
                    });
                }
                if (cognitoError.name === 'UserNotFoundException') {
                    return createResponse(401, {
                        success: false,
                        message: 'Invalid email or password'
                    });
                }

                return createResponse(500, {
                    success: false,
                    message: 'Authentication service error',
                    error: cognitoError.message
                });
            }
        }

        // Handle login tracking - LIGHTWEIGHT (No WebSocket connection creation)
        // WebSocket connection will be created by the app's realtime service
        if (path === '/auth/track-login' && httpMethod === 'POST') {
            const body = JSON.parse(event.body || '{}');
            const { businessId, userId, email } = body;

            if (!businessId || !userId || !email) {
                return createResponse(400, {
                    success: false,
                    message: 'BusinessId, userId, and email are required'
                });
            }

            try {
                // ✅ FIXED: Only log the login event, don't create WebSocket connection
                // The app's realtime_order_service will create the actual WebSocket connection
                console.log(`✅ Login tracked for business: ${businessId}, user: ${userId}, email: ${email}`);
                console.log(`   Timestamp: ${new Date().toISOString()}`);
                console.log(`   Note: WebSocket connection will be created by app's realtime service`);

                return createResponse(200, {
                    success: true,
                    message: 'Login tracked successfully',
                    businessId: businessId,
                    userId: userId,
                    email: email,
                    timestamp: new Date().toISOString(),
                    note: 'WebSocket connection will be established by the app'
                });

            } catch (error) {
                console.error('Error tracking login:', error);
                return createResponse(500, {
                    success: false,
                    message: 'Failed to track login',
                    error: error.message
                });
            }
        }

        // Handle logout tracking using WebSocket service
        if (path === '/auth/track-logout' && httpMethod === 'POST') {
            const body = JSON.parse(event.body || '{}');
            const { businessId, userId } = body;

            if (!businessId || !userId) {
                return createResponse(400, {
                    success: false,
                    message: 'BusinessId and userId are required'
                });
            }

            try {
                // Use local WebSocket service for professional logout handling
                const WebSocketService = require('./websocket_service');
                
                const result = await WebSocketService.handleUserLogout(businessId, userId);

                console.log(`✅ Professional logout tracking processed for business: ${businessId}, user: ${userId}`);

                return createResponse(200, {
                    success: true,
                    message: `Successfully processed logout tracking`,
                    ...result
                });

            } catch (error) {
                console.error('Error processing logout tracking:', error);
                return createResponse(500, {
                    success: false,
                    message: 'Failed to process logout tracking',
                    error: error.message
                });
            }
        }

        // Handle getting user businesses (used by business provider)
        if (path === '/auth/user-businesses' && httpMethod === 'GET') {
            console.log('🏢 Getting user businesses from access token...');
            
            const authHeader = event.headers?.Authorization || event.headers?.authorization;
            
            if (!authHeader || !authHeader.startsWith('Bearer ')) {
                return createResponse(401, {
                    success: false,
                    message: 'Authorization header is missing or invalid'
                });
            }

            const bearerToken = authHeader.replace('Bearer ', '');

            try {
                // The API Gateway Cognito authorizer has already verified the token.
                // Read user info from the verified claims when available; otherwise
                // decode the JWT payload directly. This works for both ID tokens
                // (sent by the app) and access tokens, avoiding Cognito GetUser
                // which only accepts access tokens.
                let claims = event.requestContext?.authorizer?.claims;
                if (!claims) {
                    try {
                        const payload = bearerToken.split('.')[1];
                        const decoded = Buffer.from(
                            payload.replace(/-/g, '+').replace(/_/g, '/'),
                            'base64'
                        ).toString('utf8');
                        claims = JSON.parse(decoded);
                    } catch (decodeErr) {
                        console.error('❌ Failed to decode token payload:', decodeErr);
                        return createResponse(401, {
                            success: false,
                            message: 'Invalid or expired access token'
                        });
                    }
                }

                const email = claims.email;
                const userId = claims.sub || claims['cognito:username'] || claims.username;
                const firstName = claims.given_name;
                const lastName = claims.family_name;
                const phoneNumber = claims.phone_number;

                console.log(`🔐 Authenticated user: ${email || phoneNumber} (${userId})`);

                // Query businesses for this user - ENHANCED DEBUGGING
                let businesses = [];
                console.log(`🔍 DEBUG: Querying businesses for user: ${email}`);
                console.log(`🔍 DEBUG: User ID: ${userId}`);
                console.log(`🔍 DEBUG: Table: ${process.env.BUSINESSES_TABLE || 'WhizzMerchants_Businesses'}`);
                
                try {
                    // Phone-only users may have no email: only use email-index when an email exists.
                    let businessResult = { Items: [] };
                    if (email) {
                        const businessQueryParams = {
                            TableName: process.env.BUSINESSES_TABLE || 'WhizzMerchants_Businesses',
                            IndexName: 'email-index',
                            KeyConditionExpression: 'email = :email',
                            ExpressionAttributeValues: {
                                ':email': email.toLowerCase().trim()
                            }
                        };
                        businessResult = await dynamodb.send(new QueryCommand(businessQueryParams));
                    }
                    console.log(`🔍 DEBUG: Email query result: Found ${businessResult.Items?.length || 0} businesses`);
                    
                    if (businessResult.Items && businessResult.Items.length > 0) {
                        businesses = businessResult.Items.map(business => ({
                            businessId: business.businessId,
                            businessName: business.businessName || business.name,
                            email: business.email,
                            ownerId: business.ownerId,
                            cognitoUserId: business.cognitoUserId,
                            status: business.status || 'approved',
                            businessType: business.businessType || 'restaurant',
                            address: business.address,
                            phoneNumber: business.phoneNumber || business.phone,
                            city: business.city,
                            district: business.district,
                            country: business.country
                        }));
                        console.log(`✅ Found ${businesses.length} businesses for user: ${email}`);
                        console.log(`📋 Business IDs: ${businesses.map(b => b.businessId).join(', ')}`);
                    } else {
                        console.log(`⚠️ No businesses found with email-index query for: ${email}`);
                        
                        // Try alternative approach: scan by cognitoUserId
                        console.log(`🔄 Trying alternative query by cognitoUserId: ${userId}`);
                        const altParams = {
                            TableName: process.env.BUSINESSES_TABLE || 'WhizzMerchants_Businesses',
                            FilterExpression: 'cognitoUserId = :userId OR ownerId = :userId' + (phoneNumber ? ' OR phoneNumber = :phone OR phone = :phone' : ''),
                            ExpressionAttributeValues: phoneNumber
                                ? { ':userId': userId, ':phone': phoneNumber }
                                : { ':userId': userId }
                        };
                        
                        const altResult = await dynamodb.send(new ScanCommand(altParams));
                        console.log(`🔍 Alternative scan result: Found ${altResult.Items?.length || 0} businesses`);
                        
                        if (altResult.Items && altResult.Items.length > 0) {
                            businesses = altResult.Items.map(business => ({
                                businessId: business.businessId,
                                businessName: business.businessName || business.name,
                                email: business.email,
                                ownerId: business.ownerId,
                                cognitoUserId: business.cognitoUserId,
                                status: business.status || 'approved',
                                businessType: business.businessType || 'restaurant',
                                address: business.address,
                                phoneNumber: business.phoneNumber || business.phone,
                                city: business.city,
                                district: business.district,
                                country: business.country
                            }));
                            console.log(`✅ Found ${businesses.length} businesses via cognitoUserId`);
                            console.log(`📋 Business IDs: ${businesses.map(b => b.businessId).join(', ')}`);
                        } else {
                            console.error(`❌ NO BUSINESSES FOUND for user ${userId} (${email})`);
                            console.error(`❌ This should not happen for registered business users`);
                            // Return empty array instead of creating fake business
                            businesses = [];
                        }
                    }
                } catch (businessError) {
                    console.error('❌ Error querying businesses:', businessError);
                    // Return empty array on error instead of creating fake business
                    businesses = [];
                }

                console.log(`✅ Returning ${businesses.length} businesses for user ${email}`);
                
                if (businesses.length === 0) {
                    return createResponse(404, {
                        success: false,
                        message: 'No businesses found for this user',
                        debug: {
                            email: email,
                            userId: userId,
                            queryAttempts: ['email-index', 'cognitoUserId scan']
                        }
                    });
                }

                return createResponse(200, {
                    success: true,
                    businesses: businesses,
                    debug: {
                        email: email,
                        userId: userId,
                        found: businesses.length
                    }
                });

            } catch (cognitoError) {
                console.error('Error verifying access token:', cognitoError);
                
                if (cognitoError.name === 'NotAuthorizedException') {
                    return createResponse(401, {
                        success: false,
                        message: 'Invalid or expired access token'
                    });
                }
                
                return createResponse(500, {
                    success: false,
                    message: 'Authentication service error',
                    error: cognitoError.message
                });
            }
        }

        // For other endpoints not yet implemented
        return createResponse(501, {
            success: false,
            message: 'Auth endpoint not implemented yet',
            path: path
        });
    } catch (error) {
        console.error('Unhandled error in auth handler:', error);
        return createResponse(500, {
            success: false,
            message: 'Internal server error',
            error: error.message
        });
    }
};