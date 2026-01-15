const { S3Client, PutObjectCommand } = require('@aws-sdk/client-s3');
const { CognitoIdentityProviderClient, GetUserCommand } = require('@aws-sdk/client-cognito-identity-provider');
const { v4: uuidv4 } = require('uuid');

// Initialize S3 client
const s3Client = new S3Client({ region: process.env.AWS_REGION || 'us-east-1' });
const COGNITO_REGION = process.env.COGNITO_REGION || 'us-east-1';

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

// Helper function to get user info from bearer token
async function getUserFromToken(event) {
    try {
        const authHeader = event.headers?.Authorization || event.headers?.authorization;
        if (!authHeader || !authHeader.startsWith('Bearer ')) {
            console.log("Authorization header is missing or invalid");
            return null;
        }

        const accessToken = authHeader.replace('Bearer ', '');

        // Verify the access token with Cognito to get user info
        const cognitoClient = new CognitoIdentityProviderClient({ region: COGNITO_REGION });
        const userResponse = await cognitoClient.send(new GetUserCommand({ AccessToken: accessToken }));
        
        const email = userResponse.UserAttributes.find(attr => attr.Name === 'email')?.Value;
        const userId = userResponse.UserAttributes.find(attr => attr.Name === 'sub')?.Value || userResponse.Username;
        
        console.log(`🔐 Authenticated user: ${email} (${userId})`);
        return { email, userId };
    } catch (error) {
        console.error('Authentication error:', error);
        return null;
    }
}

// Helper function to check if this is a registration upload
function isRegistrationUpload(event) {
    const registrationHeader = event.headers?.['X-Registration-Upload'] || event.headers?.['x-registration-upload'];
    return registrationHeader === 'true';
}

// Helper function to check if this is a product image upload (no auth needed)
function isProductImageUpload(event) {
    return event.path && event.path.includes('/upload/product-image');
}

// Helper function to upload image to S3
const uploadToS3 = async (imageBuffer, key, contentType = 'image/jpeg') => {
    const bucketName = process.env.BUSINESS_PHOTOS_BUCKET || 'order-receiver-business-photos-dev-1755170214';
    
    const params = {
        Bucket: bucketName,
        Key: key,
        Body: imageBuffer,
        ContentType: contentType
        // Removed ACL: 'public-read' as many buckets have ACLs disabled
    };
    
    console.log(`Uploading to S3: ${bucketName}/${key}`);
    const command = new PutObjectCommand(params);
    const result = await s3Client.send(command);
    console.log(`S3 upload successful`);
    
    // Construct the public URL
    const location = `https://${bucketName}.s3.amazonaws.com/${key}`;
    return location;
};

// Helper function to decode base64 image
const decodeBase64Image = (dataString) => {
    // Check if it's a data URL format
    const dataUrlMatches = dataString.match(/^data:([A-Za-z-+\/]+);base64,(.+)$/);
    if (dataUrlMatches && dataUrlMatches.length === 3) {
        return {
            type: dataUrlMatches[1],
            data: Buffer.from(dataUrlMatches[2], 'base64')
        };
    }
    
    // If not a data URL, treat as raw base64 (assume it's a PNG for now)
    try {
        const buffer = Buffer.from(dataString, 'base64');
        // Basic validation - check if it's a valid base64 and creates a buffer
        if (buffer.length > 0) {
            return {
                type: 'image/png', // Default to PNG for raw base64
                data: buffer
            };
        }
    } catch (error) {
        // Fall through to throw error
    }
    
    throw new Error('Invalid base64 image data - must be either data URL format or valid base64 string');
};

exports.handler = async (event) => {
    console.log('Image Upload Handler - Event:', JSON.stringify(event, null, 2));

    const { httpMethod, path, headers, body } = event;

    // Handle CORS preflight requests
    if (httpMethod === 'OPTIONS') {
        return createResponse(204, {});
    }

    // Authenticate user using bearer token (unless it's a registration upload or product image upload)
    const isRegUpload = isRegistrationUpload(event);
    const isProductUpload = isProductImageUpload(event);
    let userInfo = null;
    let userEmail = 'anonymous-user';
    let userId = 'anonymous';

    if (!isRegUpload && !isProductUpload) {
        userInfo = await getUserFromToken(event);
        if (!userInfo) {
            console.log('❌ Authentication failed');
            return createResponse(401, {
                success: false,
                message: 'Unauthorized - Invalid or missing token'
            });
        }
        userEmail = userInfo.email;
        userId = userInfo.userId;
    } else if (isRegUpload) {
        console.log('🔓 Registration upload detected - bypassing authentication');
        userEmail = 'registration-user';
        userId = 'registration';
    } else if (isProductUpload) {
        console.log('🔓 Product image upload detected - bypassing authentication');
        userEmail = 'product-user';
        userId = 'product';
    }

    // Handle Base64 encoded request body
    let requestBody = body;
    if (event.isBase64Encoded && requestBody) {
        try {
            requestBody = Buffer.from(requestBody, 'base64').toString('utf-8');
            console.log('📝 Decoded Base64 request body');
        } catch (decodeError) {
            console.error('❌ Failed to decode Base64 body:', decodeError);
        }
    }

    try {
        // Handle image uploads
        if (httpMethod === 'POST' && path.includes('/upload/')) {
            
            // Determine upload type based on path
            let uploadType = 'product-image'; // default
            let folderName = 'product-images';
            
            if (path.includes('/upload/business-photo')) {
                uploadType = 'business-photo';
                folderName = 'business-photos';
            } else if (path.includes('/upload/product-image')) {
                uploadType = 'product-image';
                folderName = 'product-images';
            } else if (path.includes('/upload/business-license')) {
                uploadType = 'business-license';
                folderName = 'business-documents';
            } else if (path.includes('/upload/owner-identity')) {
                uploadType = 'owner-identity';
                folderName = 'business-documents';
            } else if (path.includes('/upload/health-certificate')) {
                uploadType = 'health-certificate';
                folderName = 'business-documents';
            } else if (path.includes('/upload/owner-photo')) {
                uploadType = 'owner-photo';
                folderName = 'business-documents';
            }
            
            console.log(`Upload type detected: ${uploadType}, folder: ${folderName}`);
            
            if (!requestBody) {
                return createResponse(400, {
                    success: false,
                    message: 'No image data provided'
                });
            }

            let imageData;
            let parsedBody;

            try {
                parsedBody = JSON.parse(requestBody);
                
                // Handle different body formats
                if (parsedBody.image) {
                    imageData = parsedBody.image;
                } else if (parsedBody.imageData) {
                    imageData = parsedBody.imageData;
                } else if (typeof parsedBody === 'string' && parsedBody.startsWith('data:')) {
                    imageData = parsedBody;
                } else {
                    throw new Error('No image data found in request body');
                }
            } catch (parseError) {
                // If JSON parsing fails, assume the body is the image data directly
                if (typeof requestBody === 'string' && requestBody.startsWith('data:')) {
                    imageData = requestBody;
                } else {
                    return createResponse(400, {
                        success: false,
                        message: 'Invalid request body format. Expected JSON with image data or direct base64.'
                    });
                }
            }

            // Decode base64 image
            let decodedImage;
            try {
                decodedImage = decodeBase64Image(imageData);
            } catch (decodeError) {
                console.error('Failed to decode base64 image:', decodeError);
                return createResponse(400, {
                    success: false,
                    message: 'Invalid image format. Please provide a valid base64 encoded image.'
                });
            }

            // Generate unique filename with proper extension and user context
            const imageId = uuidv4();
            const fileExtension = decodedImage.type.includes('png') ? 'png' : 'jpg';
            const fileName = `${folderName}/${userId}/${imageId}.${fileExtension}`;

            try {
                // Upload to S3
                const imageUrl = await uploadToS3(decodedImage.data, fileName, decodedImage.type);
                
                console.log(`${uploadType} uploaded successfully for user ${userId}:`, imageUrl);
                
                return createResponse(200, {
                    success: true,
                    message: `${uploadType.replace('-', ' ')} uploaded successfully`,
                    imageUrl: imageUrl
                });
                
            } catch (uploadError) {
                console.error('S3 upload error:', uploadError);
                return createResponse(500, {
                    success: false,
                    message: 'Failed to upload image to storage',
                    error: uploadError.message
                });
            }
        }

        // Handle other endpoints
        return createResponse(404, {
            success: false,
            message: 'Endpoint not found'
        });

    } catch (error) {
        console.error('Image upload handler error:', error);
        return createResponse(500, {
            success: false,
            message: 'Internal server error',
            error: error.message
        });
    }
};
