const {merchantLifecycleClient,merchantHandler}=require('../shared/merchant-lifecycle');
const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { DynamoDBDocumentClient, GetCommand, PutCommand, UpdateCommand, QueryCommand, ScanCommand, BatchGetCommand } = require('@aws-sdk/lib-dynamodb');
const { SNSClient, PublishCommand, CreatePlatformEndpointCommand } = require('@aws-sdk/client-sns');
const { ApiGatewayManagementApiClient, PostToConnectionCommand } = require('@aws-sdk/client-apigatewaymanagementapi');

const { sendMerchantOrderPush } = require('./central_push_service');
const { triggerDriverAssignment } = require('./central-platform-integration');
const { forwardAcceptedOrder } = require('./pos_forwarding_service');

// Environment variables
const ORDERS_TABLE = process.env.ORDERS_TABLE;
const MERCHANT_ENDPOINTS_TABLE = process.env.MERCHANT_ENDPOINTS_TABLE || 'order-receiver-merchant-endpoints-dev';
const DEVICE_TOKENS_TABLE = process.env.DEVICE_TOKENS_TABLE || 'WhizzMerchants_DeviceTokens';
const WEBSOCKET_CONNECTIONS_TABLE = process.env.WEBSOCKET_CONNECTIONS_TABLE;
const TIMEOUT_LOGS_TABLE = process.env.TIMEOUT_LOGS_TABLE;
const CENTRAL_PLATFORM_WEBHOOK_URL = process.env.CENTRAL_PLATFORM_WEBHOOK_URL; // Added env var for central notifications
const METRICS_NAMESPACE = process.env.METRICS_NAMESPACE || 'WhizzMerchants'; // Metrics namespace
const { CloudWatchClient, PutMetricDataCommand } = require('@aws-sdk/client-cloudwatch');
const cloudwatch = new CloudWatchClient({ region: process.env.AWS_REGION || 'us-east-1' });

// Initialize AWS clients
const dynamoDbClient = new DynamoDBClient({ region: process.env.AWS_REGION || 'us-east-1' });
const lifecycleRawDb=DynamoDBDocumentClient.from(dynamoDbClient);
const dynamodb=merchantLifecycleClient(lifecycleRawDb);
const sns = new SNSClient({ region: process.env.AWS_REGION || 'us-east-1' });

async function getBusinessOwnerId(businessId) {
    if (!businessId) return null;
    try {
        const resp = await dynamodb.send(
            new GetCommand({
                TableName: process.env.BUSINESSES_TABLE || 'WhizzMerchants_Businesses',
                Key: { businessId },
                ProjectionExpression: 'ownerId'
            })
        );

        const ownerId = resp?.Item?.ownerId;
        return ownerId ? String(ownerId) : null;
    } catch (e) {
        console.error('❌ Failed to resolve business ownerId:', e?.message || String(e));
        return null;
    }
}

/**
 * Create consistent HTTP response
 */
function createResponse(statusCode, body) {
    return {
        statusCode,
        headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Staff-Session,X-Api-Key,X-Amz-Security-Token',
            'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS'
        },
        body: JSON.stringify(body)
    };
}

// Helper: resolve businessId regardless of whether order uses storeId or businessId
function resolveBusinessId(order) {
    return order?.businessId || order?.storeId || order?.merchantId; // merchantId last resort
}

// Helper: resolve customerId (userId/customerId)
function resolveCustomerId(order) {
    return order?.customerId || order?.userId;
}

function financialOrderAssignment(order) {
    return order.financialAcceptance ? {offerId:order.financialAcceptance.offerId,attempt:order.assignmentAttemptCounter,returnId:order.returnCaseId||null,returnStatus:order.returnStatus||null} : null;
}

// Helper: normalize order shape for frontend (adds id alias + businessId)
function normalizeOrderForFrontend(order) {
    if (!order) return order;
    const businessId = resolveBusinessId(order);
    const id = order.orderId || order.id;
    const {financialSnapshot,commercialPricing,financialAcceptance,...view}=order;
    return { ...view, financialAssignment:financialOrderAssignment(order),id, orderId: id, businessId };
}

/**
 * Check if business is accepting orders by checking the acceptingOrders field
 * This is the primary and only source of truth for order acceptance
 */
async function isBusinessOnline(businessId) {
    try {
        // Check the acceptingOrders field in the businesses table
        const businessParams = {
            TableName: process.env.BUSINESSES_TABLE || 'WhizzMerchants_Businesses',
            Key: {
                businessId: businessId
            },
            ProjectionExpression: 'acceptingOrders, lastStatusUpdate'
        };

        const businessResult = await dynamodb.send(new GetCommand(businessParams));
        const business = businessResult.Item;

        if (!business) {
            console.log(`Business ${businessId} not found in businesses table`);
            return false;
        }

        const isAcceptingOrders = business.acceptingOrders ?? false;
        console.log(`Business ${businessId} accepting orders: ${isAcceptingOrders} (lastStatusUpdate: ${business.lastStatusUpdate})`);

        return isAcceptingOrders;
    } catch (error) {
        console.error('Error checking business accepting orders status:', error);
        // In case of error, default to offline to prevent order acceptance
        return false;
    }
}

/**
 * Merchant Order Handler - Handles merchant-specific order operations
 * Following the ecosystem architecture plan
 */
exports.handler = async (event) => {
    if(event.httpMethod==='OPTIONS')return createResponse(204,{});
    console.log('Merchant Order Handler - Event:', {method:event.httpMethod,path:event.path});

    const { httpMethod, path, pathParameters, headers, body } = event;

    // Handle Base64 encoded request body
    let requestBody = body;
    if (event.isBase64Encoded && requestBody) {
        try {
            requestBody = Buffer.from(requestBody, 'base64').toString('utf-8');
            console.log('🔍 Decoded Base64 body:', requestBody);
        } catch (decodeError) {
            console.error('Failed to decode Base64 body:', decodeError);
            return createResponse(400, { success: false, message: 'Invalid Base64 request body' });
        }
    }

    console.log('🔍 Final request body:', requestBody);

    try {
        // Route based on endpoint (updated for new path structure)
        if (httpMethod === 'GET' && path.includes('/merchant/orders/') && pathParameters?.businessId) {
            return await handleGetOrdersForBusiness(pathParameters.businessId, event.queryStringParameters);
        }

        if (httpMethod === 'PUT' && path.includes('/merchant/order/') && path.includes('/confirm')) {
            const orderId = pathParameters?.orderId;
            return await handleAcceptOrder(orderId, JSON.parse(requestBody || '{}'));
        }

        if (httpMethod === 'PUT' && path.includes('/merchant/order/') && path.includes('/reject')) {
            const orderId = pathParameters?.orderId;
            return await handleRejectOrder(orderId, JSON.parse(requestBody || '{}'));
        }

        if (httpMethod === 'PUT' && path.includes('/merchant/order/') && path.includes('/status')) {
            const orderId = pathParameters?.orderId;
            return await handleUpdateOrderStatus(orderId, JSON.parse(requestBody || '{}'));
        }

        if (httpMethod === 'POST' && path.includes('/merchants/') && path.includes('/device-token')) {
            const merchantId = pathParameters?.merchantId;
            return await handleRegisterDeviceToken(merchantId, JSON.parse(requestBody || '{}'));
        }

        if (httpMethod === 'POST' && path.includes('/merchant/order/') && path.includes('/timeout-log')) {
            const orderId = pathParameters?.orderId;
            return await handleTimeoutLog(orderId, JSON.parse(requestBody || '{}'));
        }

        if (httpMethod === 'POST' && path.includes('/webhooks/orders')) {
            // Receive orders from Central Platform
            console.log('🔍 Webhook body before parsing:', requestBody);

            if (!requestBody || requestBody.trim() === '') {
                return createResponse(400, { success: false, message: 'Empty request body' });
            }

            let orderData;
            try {
                orderData = JSON.parse(requestBody);
            } catch (parseError) {
                console.error('JSON parse error:', parseError);
                console.error('Body that failed to parse:', requestBody);
                return createResponse(400, { success: false, message: 'Invalid JSON in request body' });
            }

            return await handleIncomingOrder(orderData);
        }

        // Add cancellation endpoints
        if (httpMethod === 'PUT' && path.includes('/merchant/order/') && path.includes('/cancel-by-user')) {
            const orderId = pathParameters?.orderId;
            return await handleCancelOrderByUser(orderId, JSON.parse(requestBody || '{}'));
        }

        if (httpMethod === 'PUT' && path.includes('/merchant/order/') && path.includes('/cancel-by-store')) {
            const orderId = pathParameters?.orderId;
            return await handleCancelOrderByStore(orderId, JSON.parse(requestBody || '{}'));
        }

        if (httpMethod === 'PUT' && path.includes('/merchant/order/') && path.includes('/cancel-by-system')) {
            const orderId = pathParameters?.orderId;
            return await handleCancelOrderBySystem(orderId, JSON.parse(requestBody || '{}'));
        }

        return createResponse(404, { success: false, message: 'Endpoint not found' });

    } catch (error) {
        console.error('Error in merchant order handler:', error);
        return createResponse(500, { success: false, message: 'Internal server error' });
    }
};

/**
 * Get orders for a specific business/merchant using GSI_StoreStatus
 * Fixed: Handle empty status fields and correct price display (no micro-currency conversion needed)
 */
async function handleGetOrdersForBusiness(businessId, queryParams) {
    try {
        const status = queryParams?.status; // Don't default to pending - return ALL if no status specified
        const limit = queryParams?.limit ? parseInt(queryParams.limit) : 50;
        const offset = queryParams?.offset ? parseInt(queryParams.offset) : 0; // New: pagination offset

        console.log(`🔍 Getting orders for business: ${businessId}, status: ${status || 'ALL'}`);
        
        // If no status is specified, query for all common statuses
        if (!status) {
            console.log(`🔍 No status filter specified - querying for all active order statuses`);
        }

        // Handle special status cases for expired/cancelled orders
        let statusesToQuery = [];
        if (!status) {
            // If no status specified, get all common active order statuses
            statusesToQuery = ['pending', 'confirmed', 'preparing', 'ready', 'ready_for_pickup', 'assigned', 'heading_to_store', 'arrived_at_store', 'picked_up', 'heading_to_customer', 'arrived_at_customer', 'returning', 'return_arrived', 'on_the_way', 'delivered'];
        } else if (status === 'expired' || status === 'cancelled') {
            // For expired/cancelled, query all cancellation types
            statusesToQuery = ['cancelled', 'canceled_by_user', 'canceled_by_store', 'canceled_by_system', 'expired'];
        } else if (status === 'completed' || status === 'delivered') {
            // For completed orders
            statusesToQuery = ['delivered', 'completed'];
        } else {
            // Single status query
            statusesToQuery = [status];
        }

        console.log(`🔍 Querying orders for business: ${businessId}, statuses: ${statusesToQuery.join(', ')}`);

        // Query buckets in parallel with timeout protection to prevent Lambda timeout
        const buckets = ['b0', 'b1', 'b2', 'b3', 'b4', 'b5', 'b6', 'b7', 'b8', 'b9'];  // All 10 buckets
        const allOrders = [];
        
        // Parallel query execution with Promise.allSettled for resilience
        const queryPromises = [];
        
        for (const statusToQuery of statusesToQuery) {
            for (const bucket of buckets) {
                const queryPromise = (async () => {
                    const dbQueryParams = {
                        TableName: ORDERS_TABLE,
                        IndexName: 'GSI_StoreStatus',
                        KeyConditionExpression: '#storeStatus = :storeStatusValue',
                        ExpressionAttributeNames: {
                            '#storeStatus': 'storeStatus'
                        },
                        ExpressionAttributeValues: {
                            ':storeStatusValue': `${businessId}#${statusToQuery}#${bucket}`
                        },
                        ScanIndexForward: false,
                        Limit: 20 // Limit per bucket to prevent large scans
                    };

                    try {
                        const result = await dynamodb.send(new QueryCommand(dbQueryParams));
                        if (result.Items && result.Items.length > 0) {
                            console.log(`📦 Found ${result.Items.length} orders with status ${statusToQuery} in bucket ${bucket}`);
                            return result.Items;
                        }
                        return [];
                    } catch (error) {
                        console.error(`Error querying status ${statusToQuery} in bucket ${bucket}:`, error);
                        return [];
                    }
                })();
                
                queryPromises.push(queryPromise);
            }
        }
        
        // Execute all queries in parallel with 10s timeout
        const queryResults = await Promise.race([
            Promise.allSettled(queryPromises),
            new Promise((_, reject) => setTimeout(() => reject(new Error('Query timeout')), 10000))
        ]).catch(error => {
            console.error('Query batch timeout or error:', error);
            return [];
        });
        
        // Collect results from successful queries
        if (Array.isArray(queryResults)) {
            for (const result of queryResults) {
                if (result.status === 'fulfilled' && Array.isArray(result.value)) {
                    allOrders.push(...result.value);
                }
            }
        }

        // Sort all orders by createdAt descending and apply limit
        allOrders.sort((a, b) => {
            const aDate = new Date(a.createdAt || a.updatedAt || 0).getTime();
            const bDate = new Date(b.createdAt || b.updatedAt || 0).getTime();
            return bDate - aDate; // newest first
        });
        const normalizedLimit = Math.min(limit, 200); // cap
        const limitedOrders = allOrders.slice(offset, offset + normalizedLimit);
        const nextOffset = (offset + limitedOrders.length) < allOrders.length ? (offset + limitedOrders.length) : null;

        console.log(`📦 Total orders: ${allOrders.length}, returning from offset ${offset} limit ${normalizedLimit}, nextOffset: ${nextOffset}`);

        // 🚗 Fetch full order data from base table to get driver info (GSI doesn't include driver fields)
        if (limitedOrders.length > 0) {
            try {
                console.log(`🔍 Fetching full order data for ${limitedOrders.length} orders to get driver info...`);
                
                // BatchGetItem in chunks of 100 (AWS limit)
                const chunkSize = 100;
                const fullOrders = [];
                
                for (let i = 0; i < limitedOrders.length; i += chunkSize) {
                    const chunk = limitedOrders.slice(i, i + chunkSize);
                    const keys = chunk.map(order => ({
                        PK: `ORDER#${order.orderId}`,
                        SK: 'META'
                    }));
                    
                    const batchGetParams = {
                        RequestItems: {
                            [ORDERS_TABLE]: {
                                Keys: keys
                            }
                        }
                    };
                    
                    const batchResult = await dynamodb.send(new BatchGetCommand(batchGetParams));
                    if (batchResult.Responses && batchResult.Responses[ORDERS_TABLE]) {
                        fullOrders.push(...batchResult.Responses[ORDERS_TABLE]);
                    }
                }
                
                // Merge full data back into limitedOrders (preserve GSI fields, add missing fields)
                for (let i = 0; i < limitedOrders.length; i++) {
                    const fullOrder = fullOrders.find(fo => fo.orderId === limitedOrders[i].orderId);
                    if (fullOrder) {
                        // ⭐ Use REAL status from full order, not GSI storeStatus
                        // GSI storeStatus doesn't update when driver changes status!
                        limitedOrders[i] = {
                            ...limitedOrders[i],
                            status: fullOrder.status || limitedOrders[i].status,  // 🔥 الحالة الحقيقية
                            driverId: fullOrder.driverId || limitedOrders[i].driverId,
                            driverName: fullOrder.driverName || limitedOrders[i].driverName,
                            driverPhone: fullOrder.driverPhone || limitedOrders[i].driverPhone,
                            vehicleType: fullOrder.vehicleType || limitedOrders[i].vehicleType,
                            vehiclePlate: fullOrder.vehiclePlate || fullOrder.licenseNumber || limitedOrders[i].vehiclePlate,
                            driverAssignedAt: fullOrder.driverAssignedAt || fullOrder.assignedAt || limitedOrders[i].driverAssignedAt,
                            pickedUpAt: fullOrder.pickedUpAt || limitedOrders[i].pickedUpAt,
                            startHeadingToStoreAt: fullOrder.startHeadingToStoreAt || limitedOrders[i].startHeadingToStoreAt,
                            arrivedAtStoreAt: fullOrder.arrivedAtStoreAt || limitedOrders[i].arrivedAtStoreAt
                        };
                        console.log(`✅ Merged data for order ${limitedOrders[i].orderId}: status=${fullOrder.status}, driver=${fullOrder.driverName || 'N/A'}`);
                    }
                }
            } catch (batchError) {
                console.error('⚠️ Error fetching full order data:', batchError);
                // Continue without driver info - non-critical
            }
        }

        if (!limitedOrders || limitedOrders.length === 0) {
            console.log('📭 No orders found for this business and status criteria');
            const statusMessage = status ? status : 'any status';
            return createResponse(200, {
                success: true,
                orders: [],
                count: 0,
                offset,
                nextOffset: null,
                totalAvailable: allOrders.length,
                message: `No orders found for business ${businessId} with ${statusMessage}`
            });
        }

        // Transform orders for display - Use only total field for pricing and status field for order status
        const transformedOrders = limitedOrders.map(order => {
            console.log('📄 Processing order:', order.orderId, 'status:', order.status);
            
            // Use status field directly (no fallbacks or extraction from other fields)
            let orderStatus = order.status || 'unknown';
            
            // Normalize status for display - map different status types correctly
            let displayStatus = orderStatus;
            if (['canceled_by_user', 'canceled_by_store', 'canceled_by_system', 'cancelled'].includes(orderStatus)) {
                displayStatus = 'cancelled'; // Unified display for all cancellation types
            } else if (orderStatus === 'expired') {
                displayStatus = 'expired'; // Keep expired as expired (not cancelled)
            } else if (orderStatus === 'completed') {
                displayStatus = 'delivered'; // Map completed to delivered for consistent display
            } else if (orderStatus === 'rejected') {
                // Keep rejected distinct; front-end may map separately
                displayStatus = 'rejected';
            }
            
            // Extract pricing data from the correct database structure
            const pricing = order.pricing || {};
            const totalAmount = pricing.total != null ? Number(pricing.total) / 1000 : Number(order.totalAmount ?? order.total ?? 0);
            const deliveryFee = pricing.deliveryFee != null ? Number(pricing.deliveryFee) / 1000 : Number(order.deliveryFee ?? order.delivery_fee ?? 0);
            
            // ⚡ DEBUG: Log the raw pricing data from database
            console.log('🔍 Raw order data from DB:', {
                orderId: order.orderId,
                rawPricing: order.pricing,
                rawTotal: pricing.total,
                totalType: typeof pricing.total,
                rawDeliveryFee: pricing.deliveryFee,
                processedTotalAmount: totalAmount,
                processedDeliveryFee: deliveryFee
            });
            
            // Use the correct order number from the database - prioritize orderNumber field
            let orderNumber;
            if (order.orderNumber) {
                orderNumber = order.orderNumber; // This contains proper order number like "ORD1759012750025"
            } else if (order.orderNumber_gsi) {
                orderNumber = order.orderNumber_gsi; // Fallback to orderNumber_gsi  
            } else if (order.PK) {
                // Last resort: extract short ID from PK (first 8 characters after ORDER#)
                const pkId = order.PK.replace('ORDER#', '');
                orderNumber = `#${pkId.substring(0, 8)}`;
            } else {
                orderNumber = 'Unknown';
            }
            
            console.log('📊 Order data:', {
                orderId: order.orderId,
                orderNumber: orderNumber,
                total: totalAmount,
                deliveryFee: deliveryFee,
                status: displayStatus
            });
            
            return {
                financialAssignment: financialOrderAssignment(order),
                id: order.orderId, // alias for frontend models expecting `id`
                orderId: order.orderId,
                orderNumber: orderNumber,
                userId: order.userId || order.customerId, // Handle both field names
                customerName: order.customerName || 'Unknown Customer',
                customerPhone: order.customerPhone,
                storeId: businessId, // Use businessId from the query context
                storeName: order.storeName,
                status: displayStatus, // Use normalized display status
                originalStatus: orderStatus, // Keep original for debugging
                totalAmount: totalAmount,
                deliveryFee: deliveryFee,
                items: order.items || [],
                deliveryAddress: order.deliveryAddress,
                deliveryInstructions: order.deliveryInstructions,
                paymentMethod: order.paymentMethod,
                paymentStatus: order.paymentStatus,
                createdAt: order.createdAt,
                updatedAt: order.updatedAt,
                notes: order.notes || order.cancelReason,
                cancelReason: order.cancelReason, // Include cancel reason for cancelled orders
                businessId: businessId, // explicit for frontend session alignment
                // 🚗 معلومات السائق - Driver Information
                driverId: order.driverId || null,
                driverName: order.driverName || null,
                driverPhone: order.driverPhone || null,
                vehicleType: order.vehicleType || null,
                vehiclePlate: order.vehiclePlate || order.licenseNumber || null,
                driverAssignedAt: order.driverAssignedAt || order.assignedAt || null,
                pickedUpAt: order.pickedUpAt || null,
                startHeadingToStoreAt: order.startHeadingToStoreAt || null,
                arrivedAtStoreAt: order.arrivedAtStoreAt || null
            };
        });

        return createResponse(200, {
            success: true,
            orders: transformedOrders,
            count: transformedOrders.length,
            offset,
            nextOffset,
            totalAvailable: allOrders.length
        });

    } catch (error) {
        console.error('Error getting orders for business:', error);
        return createResponse(500, { success: false, message: 'Failed to get orders' });
    }
}

/**
 * Accept an order (Merchant accepts order from Customer)
 * This will trigger notifications to Driver App and update Central Platform
 * Updated for WizzOrders schema compatibility
 */
async function handleAcceptOrder(orderId, data) {
    console.log(`🔄 Accepting order: ${orderId}`, data);
    
    try {
        const { estimatedPreparationTime } = data;
        const timestamp = new Date().toISOString();

        console.log(`🔍 Getting current order for accept: ${orderId}`);
        
        // First, get the current order to get its current state
        const getParams = {
            TableName: ORDERS_TABLE,
            Key: { 
                PK: `ORDER#${orderId}`,
                SK: 'META'
            }
        };

        const currentOrderResult = await dynamodb.send(new GetCommand(getParams));
        if (!currentOrderResult.Item) {
            console.error(`❌ Order not found: ${orderId}`);
            return createResponse(404, { success: false, message: 'Order not found' });
        }

        const currentOrder = currentOrderResult.Item;
        console.log(`📄 Current order status: ${currentOrder.status}`);

        // Defensive store key resolution (storeId may be businessId in some schemas)
        const storeKey = currentOrder.storeId || currentOrder.businessId || currentOrder.merchantId;

        // Update the bucket to maintain the same bucket throughout order lifecycle
        const currentStoreStatus = currentOrder.storeStatus || `${storeKey}#${currentOrder.status}#b1`;
        const bucketMatch = currentStoreStatus.match(/#(b\d+)$/);
        const bucket = bucketMatch ? bucketMatch[1] : 'b1';
        
        // Update storeStatus with confirmed status but keep same bucket
        const newStoreStatus = `${storeKey}#confirmed#${bucket}`;

        // Update order status to 'confirmed' using WizzOrders schema (ensure orderId attribute exists)
        const updateParams = {
            TableName: ORDERS_TABLE,
            Key: { 
                PK: `ORDER#${orderId}`,
                SK: 'META'
            },
            UpdateExpression: 'SET #status = :status, updatedAt = :timestamp, confirmedAt = :timestamp, storeStatus = :storeStatus, orderId = if_not_exists(orderId, :orderId), rev = if_not_exists(rev, :zero) + :one',
            ExpressionAttributeNames: {
                '#status': 'status'
            },
            ExpressionAttributeValues: {
                ':status': 'confirmed',
                ':timestamp': timestamp,
                ':storeStatus': newStoreStatus,
                ':orderId': orderId,
                ':zero': 0,
                ':one': 1
            },
            ReturnValues: 'ALL_NEW'
        };

        // Add estimated preparation time if provided
        if (estimatedPreparationTime) {
            updateParams.UpdateExpression += ', estimatedPreparationTime = :prepTime';
            updateParams.ExpressionAttributeValues[':prepTime'] = estimatedPreparationTime;
        }

        console.log(`🔄 Confirming order with storeStatus: ${newStoreStatus}`);

        const result = await dynamodb.send(new UpdateCommand(updateParams));
        const updatedOrder = result.Attributes;

        console.log(`✅ Order accepted successfully: ${orderId} -> confirmed`);

        // Emit OrderStatusUpdated event for Driver App
        await publishOrderStatusUpdate(updatedOrder, 'ORDER_CONFIRMED');
        
        // Notify Central Platform
        await notifyCentralPlatform(updatedOrder, 'confirmed');

        // Forward accepted order to external POS if configured (best effort)
        try {
            const posResult = await forwardAcceptedOrder(updatedOrder);
            if (posResult && !posResult.skipped) {
                console.log(`🛒 POS forward result for order ${orderId}:`, posResult.success ? 'success' : 'failed');
            }
        } catch (posError) {
            console.error(`❌ POS forward error for order ${orderId}:`, posError);
        }

        return createResponse(200, {
            success: true,
            message: 'Order confirmed successfully',
            order: normalizeOrderForFrontend(updatedOrder),
            id: orderId,
            orderId: orderId,
            businessId: resolveBusinessId(updatedOrder),
            status: 'confirmed',
            estimatedPreparationTime: estimatedPreparationTime || 30
        });

    } catch (error) {
        console.error('❌ Error accepting order:', error);
        return createResponse(500, { success: false, message: 'Failed to accept order' });
    }
}

/**
 * Reject an order
 * Updated for WizzOrders schema compatibility
 */
async function handleRejectOrder(orderId, data) {
    console.log(`🔄 Rejecting order: ${orderId}`, data);
    
    try {
        const { reason } = data;
        const timestamp = new Date().toISOString();

        console.log(`🔍 Getting current order for reject: ${orderId}`);
        
        // First, get the current order to get its current state
        const getParams = {
            TableName: ORDERS_TABLE,
            Key: { 
                PK: `ORDER#${orderId}`,
                SK: 'META'
            }
        };

        const currentOrderResult = await dynamodb.send(new GetCommand(getParams));
        if (!currentOrderResult.Item) {
            console.error(`❌ Order not found: ${orderId}`);
            return createResponse(404, { success: false, message: 'Order not found' });
        }

        const currentOrder = currentOrderResult.Item;
        console.log(`📄 Current order status: ${currentOrder.status}`);

        const storeKey = currentOrder.storeId || currentOrder.businessId || currentOrder.merchantId;
        const currentStoreStatus = currentOrder.storeStatus || `${storeKey}#${currentOrder.status}#b1`;
        const bucketMatch = currentStoreStatus.match(/#(b\d+)$/);
        const bucket = bucketMatch ? bucketMatch[1] : 'b1';
        const newStoreStatus = `${storeKey}#rejected#${bucket}`;

        let updateExpression = 'SET #status = :status, updatedAt = :timestamp, rejectedAt = :timestamp, storeStatus = :storeStatus, orderId = if_not_exists(orderId, :orderId), rev = if_not_exists(rev, :zero) + :one';
        let attributeNames = {
            '#status': 'status'
        };
        let attributeValues = {
            ':status': 'rejected',
            ':timestamp': timestamp,
            ':storeStatus': newStoreStatus,
            ':orderId': orderId,
            ':zero': 0,
            ':one': 1
        };

        // Add rejection reason if provided
        if (reason) {
            updateExpression += ', rejectionReason = :reason';
            attributeValues[':reason'] = reason;
        }

        console.log(`🔄 Rejecting order with storeStatus: ${newStoreStatus}`);

        const updateParams = {
            TableName: ORDERS_TABLE,
            Key: { 
                PK: `ORDER#${orderId}`,
                SK: 'META'
            },
            UpdateExpression: updateExpression,
            ExpressionAttributeNames: attributeNames,
            ExpressionAttributeValues: attributeValues,
            ReturnValues: 'ALL_NEW'
        };

        const result = await dynamodb.send(new UpdateCommand(updateParams));
        const updatedOrder = result.Attributes;

        console.log(`✅ Order rejected successfully: ${orderId} -> rejected`);

        // Notify Customer App and Central Platform
        await publishOrderStatusUpdate(updatedOrder, 'ORDER_REJECTED');
        await notifyCentralPlatform(updatedOrder, 'rejected');

        return createResponse(200, {
            success: true,
            message: 'Order rejected successfully',
            order: normalizeOrderForFrontend(updatedOrder),
            id: orderId,
            orderId: orderId,
            businessId: resolveBusinessId(updatedOrder),
            status: 'rejected',
            reason: reason
        });

    } catch (error) {
        console.error('❌ Error rejecting order:', error);
        return createResponse(500, { success: false, message: 'Failed to reject order' });
    }
}

/**
 * Update order status (preparing, ready, etc.) using WizzOrders schema
 * This function is compatible with the new WizzOrders table structure
 */
async function handleUpdateOrderStatus(orderId, data) {
    console.log(`🔄 Updating order status: ${orderId}`, data);
    
    try {
        const { status, notes } = data;
        const timestamp = new Date().toISOString();

        console.log(`🔍 Getting current order for status update: ${orderId}`);
        
        // First, get the current order to get its current state
        const getParams = {
            TableName: ORDERS_TABLE,
            Key: { 
                PK: `ORDER#${orderId}`,
                SK: 'META'
            }
        };

        const currentOrderResult = await dynamodb.send(new GetCommand(getParams));
        if (!currentOrderResult.Item) {
            console.error(`❌ Order not found: ${orderId}`);
            return createResponse(404, { success: false, message: 'Order not found' });
        }

        const currentOrder = currentOrderResult.Item;
        console.log(`📄 Current order status: ${currentOrder.status}`);

        // Unified key resolution for storeStatus
        const storeKey = resolveBusinessId(currentOrder);
        const currentStoreStatus = currentOrder.storeStatus || `${storeKey}#${currentOrder.status}#b1`;
        const bucketMatch = currentStoreStatus.match(/#(b\d+)$/);
        const bucket = bucketMatch ? bucketMatch[1] : 'b1';
        const newStoreStatus = `${storeKey}#${status}#${bucket}`;
        let updateExpression = 'SET #status = :status, updatedAt = :timestamp, storeStatus = :storeStatus';
        let attributeNames = {
            '#status': 'status'
        };
        let attributeValues = {
            ':status': status,
            ':timestamp': timestamp,
            ':storeStatus': newStoreStatus
        };

        // Add status-specific timestamp fields
        switch (status) {
            case 'confirmed':
                updateExpression += ', confirmedAt = :timestamp';
                break;
            case 'preparing':
            case 'in_kitchen':
                updateExpression += ', inKitchenAt = :timestamp';
                break;
            case 'ready':
                updateExpression += ', readyAt = :timestamp';
                break;
            case 'out_for_delivery':
            case 'on_the_way':
                updateExpression += ', outForDeliveryAt = :timestamp';
                break;
            case 'delivered':
            case 'completed':
                updateExpression += ', deliveredAt = :timestamp';
                break;
            case 'cancelled':
            case 'rejected':
                updateExpression += ', canceledAt = :timestamp';
                if (notes) {
                    updateExpression += ', cancelReason = :cancelReason';
                    attributeValues[':cancelReason'] = notes;
                }
                break;
        }

        // Add notes if provided
        if (notes && !['cancelled', 'rejected'].includes(status)) {
            updateExpression += ', notes = :notes';
            attributeValues[':notes'] = notes;
        }

        // Ensure orderId and rev exist
        if (!updateExpression.includes('orderId =')) {
            updateExpression += ', orderId = if_not_exists(orderId, :orderId)';
            attributeValues[':orderId'] = orderId;
        }
        if (!updateExpression.includes('rev =')) {
            updateExpression += ', rev = if_not_exists(rev, :zero) + :one';
            attributeValues[':zero'] = 0;
            attributeValues[':one'] = 1;
        }

        console.log(`🔄 Updating order with new status: ${status}, storeStatus: ${newStoreStatus}`);

        const updateParams = {
            TableName: ORDERS_TABLE,
            Key: { 
                PK: `ORDER#${orderId}`,
                SK: 'META'
            },
            UpdateExpression: updateExpression,
            ExpressionAttributeNames: attributeNames,
            ExpressionAttributeValues: attributeValues,
            ReturnValues: 'ALL_NEW'
        };

        const result = await dynamodb.send(new UpdateCommand(updateParams));
        const updatedOrder = result.Attributes;

        console.log(`✅ Order status updated successfully: ${orderId} -> ${status}`);

        // Emit appropriate events based on status
        let eventType = 'ORDER_STATUS_UPDATED';
        switch (status) {
            case 'confirmed':
                eventType = 'ORDER_CONFIRMED';
                break;
            case 'preparing':
            case 'in_kitchen':
                eventType = 'ORDER_PREPARING';
                break;
            case 'ready':  // deprecated - keep for backward compatibility
            case 'ready_for_pickup':  // ✅ الحالة الصحيحة لنظام الموجات
                eventType = 'ORDER_READY_FOR_PICKUP';
                break;
            case 'out_for_delivery':
            case 'on_the_way':
                eventType = 'ORDER_OUT_FOR_DELIVERY';
                break;
            case 'delivered':
            case 'completed':
                eventType = 'ORDER_DELIVERED';
                break;
            case 'cancelled':
            case 'rejected':
                eventType = 'ORDER_CANCELLED';
                break;
        }

        // Send notifications
        await publishOrderStatusUpdate(updatedOrder, eventType);

        // ⭐ DISABLED: Old driver assignment system - replaced by Wave System DynamoDB Stream
        // Wave System handles driver assignment automatically via DynamoDB Stream on WizzOrders
        // This old code was calling non-existent WaveDispatchOrchestrator and causing duplicate dispatches
        /*
        if (['ready', 'preparing', 'ready_for_pickup'].includes(status)) {
            console.log(`🚚 Triggering driver assignment for status: ${status}`);
            try {
                await triggerDriverAssignment(orderId, status, updatedOrder);
            } catch (assignmentError) {
                console.error('❌ Driver assignment failed:', assignmentError);
                // Don't fail the status update if assignment fails
            }
        }
        */

        return createResponse(200, {
            success: true,
            message: 'Order status updated successfully',
            order: normalizeOrderForFrontend(updatedOrder),
            id: orderId,
            orderId: orderId,
            businessId: resolveBusinessId(updatedOrder),
            status: status,
            updatedAt: timestamp
        });

    } catch (error) {
        console.error('❌ Error updating order status:', error);
        return createResponse(500, { success: false, message: 'Failed to update order status' });
    }
}

/**
 * Register device token for push notifications (Mobile app)
 */
async function handleRegisterDeviceToken(merchantId, data) {
    try {
        console.log('🔥 handleRegisterDeviceToken called');
        console.log('🔥 merchantId:', merchantId);
        console.log('🔥 data:', JSON.stringify(data, null, 2));
        
        const { deviceToken, platform, deviceId, appVersion } = data; // platform: 'ios' | 'android'
        
        if (!deviceToken || !platform) {
            console.error('❌ Missing required fields: deviceToken or platform');
            return createResponse(400, { 
                success: false, 
                message: 'Missing required fields: deviceToken and platform are required' 
            });
        }

        const timestamp = new Date().toISOString();
        
        // Generate tokenId: merchantId#deviceId (or merchantId#platform if deviceId not provided)
        const tokenId = deviceId 
            ? `${merchantId}#${deviceId}` 
            : `${merchantId}#${platform}#${deviceToken.substring(0, 10)}`;

        console.log('🔥 Generated tokenId:', tokenId);
        console.log('🔥 Target table:', DEVICE_TOKENS_TABLE);

        const params = {
            TableName: DEVICE_TOKENS_TABLE,
            Item: {
                tokenId,
                merchantId,
                deviceToken,
                platform,
                deviceId: deviceId || 'unknown',
                appVersion: appVersion || 'unknown',
                isActive: true,
                registeredAt: timestamp,
                updatedAt: timestamp
            }
        };

        console.log('🔥 DynamoDB params:', JSON.stringify(params, null, 2));

        await dynamodb.send(new PutCommand(params));

        console.log('✅✅✅ Device token saved to DynamoDB successfully!');
        console.log('✅ Table:', DEVICE_TOKENS_TABLE);
        console.log('✅ TokenId:', tokenId);
        console.log('✅ MerchantId:', merchantId);

        return createResponse(200, {
            success: true,
            message: 'Device token registered successfully',
            data: {
                tokenId,
                merchantId,
                platform,
                registeredAt: timestamp
            }
        });

    } catch (error) {
        console.error('❌❌❌ Error registering device token:', error);
        console.error('❌ Error details:', JSON.stringify(error, null, 2));
        return createResponse(500, { 
            success: false, 
            message: 'Failed to register device token',
            error: error.message 
        });
    }
}

/**
 * Handle incoming order from Central Platform
 * This is called by your Central Platform when a customer places an order
 */
async function handleIncomingOrder(orderData) {
    try {
        console.log('🔔 Received order from WizzUser:', JSON.stringify(orderData, null, 2));

        const {
            orderId,
            orderNumber,
            storeId,
            userId,
            isGuestOrder,
            customerName,
            customerPhone,
            deliveryAddress,
            items,
            pricing,
            notes,
            deliveryType,
            paymentMethod,
            paymentChannel,
            createdAt
        } = orderData;

        // Check if business is online before accepting the order
        const businessOnline = await isBusinessOnline(storeId);

        if (!businessOnline) {
            console.log(`❌ Order ${orderId} rejected - Business ${storeId} is offline`);
            return createResponse(423, {
                success: false,
                message: 'Business is currently offline and cannot accept orders',
                orderId,
                storeId,
                status: 'rejected_offline'
            });
        }

        console.log(`✅ Business ${storeId} is online - proceeding with order ${orderId}`);

        // Use direct total values from order data only (no fallback to pricing object)
        const totalAmountInIQD = orderData.total || 0;
        const deliveryFeeInIQD = orderData.deliveryFee_legacy || orderData.deliveryFee || 0;
        const subtotalInIQD = orderData.subtotal || 0;
        
        // The order is already stored in WizzOrders table by WizzUser
        // We just need to notify the merchant
        console.log('📦 Order details:', {
            orderId,
            orderNumber,
            customerName,
            totalAmount: `${totalAmountInIQD} IQD`,
            deliveryFee: `${deliveryFeeInIQD} IQD`,
            subtotal: `${subtotalInIQD} IQD`,
            itemCount: items?.length || 0
        });

        // Notify Merchant App about new order via WebSocket and Push
        await notifyMerchant(storeId, {
            type: 'NEW_ORDER',
            orderId,
            orderNumber,
            customerName,
            totalAmount: totalAmountInIQD,
            message: `طلب جديد من ${customerName}`,
            data: {
                orderId,
                orderNumber,
                customerName,
                customerPhone,
                deliveryAddress,
                items,
                // Use only direct pricing fields (no fallback to pricing object)
                pricing: {
                    total: totalAmountInIQD,
                    deliveryFee: deliveryFeeInIQD,
                    goodsSubtotal: subtotalInIQD,
                    serviceFee: orderData.serviceFee_legacy || 0,
                    packagingFee: orderData.packagingFee_legacy || 0,
                    tax: orderData.tax_legacy || 0,
                    tip: orderData.tip_legacy || 0
                },
                notes,
                deliveryType,
                paymentMethod,
                createdAt,
                status: 'pending'
            }
        });

        return createResponse(201, {
            success: true,
            message: 'Order received and processed successfully',
            orderId
        });

    } catch (error) {
        console.error('Error handling incoming order:', error);
        return createResponse(500, { success: false, message: 'Failed to process incoming order' });
    }
}

/**
 * Handle order cancellation by user
 * Used when customer cancels their order
 */
async function handleCancelOrderByUser(orderId, data) {
    console.log(`🔄 Cancelling order by user: ${orderId}`, data);
    
    try {
        const { reason, userId } = data;
        const timestamp = new Date().toISOString();

        // Get current order
        const getParams = {
            TableName: ORDERS_TABLE,
            Key: { 
                PK: `ORDER#${orderId}`,
                SK: 'META'
            }
        };

        const currentOrderResult = await dynamodb.send(new GetCommand(getParams));
        if (!currentOrderResult.Item) {
            console.error(`❌ Order not found: ${orderId}`);
            return createResponse(404, { success: false, message: 'Order not found' });
        }

        const currentOrder = currentOrderResult.Item;
        
        // Check if cancellation is allowed based on current status
        const allowedCancellationStatuses = ['pending', 'confirmed'];
        if (!allowedCancellationStatuses.includes(currentOrder.status)) {
            return createResponse(400, { 
                success: false, 
                message: `Cannot cancel order in ${currentOrder.status} status` 
            });
        }

        // Update storeStatus with cancelled status
        const currentStoreStatus = currentOrder.storeStatus || `${currentOrder.storeId}#${currentOrder.status}#b1`;
        const bucketMatch = currentStoreStatus.match(/#(b\d+)$/);
        const bucket = bucketMatch ? bucketMatch[1] : 'b1';
        const newStoreStatus = `${currentOrder.storeId}#canceled_by_user#${bucket}`;

        const updateParams = {
            TableName: ORDERS_TABLE,
            Key: { 
                PK: `ORDER#${orderId}`,
                SK: 'META'
            },
            UpdateExpression: 'SET #status = :status, updatedAt = :timestamp, canceledAt = :timestamp, storeStatus = :storeStatus, canceledBy = :canceledBy, cancelReason = :reason, rev = if_not_exists(rev, :zero) + :one',
            ExpressionAttributeNames: {
                '#status': 'status'
            },
            ExpressionAttributeValues: {
                ':status': 'canceled_by_user',
                ':timestamp': timestamp,
                ':storeStatus': newStoreStatus,
                ':canceledBy': 'user',
                ':reason': reason || 'Customer cancellation',
                ':zero': 0,
                ':one': 1
            },
            ReturnValues: 'ALL_NEW'
        };

        const result = await dynamodb.send(new UpdateCommand(updateParams));
        const updatedOrder = result.Attributes;

        console.log(`✅ Order cancelled by user: ${orderId} -> canceled_by_user`);

        // Notify Store and Central Platform
        await publishOrderStatusUpdate(updatedOrder, 'ORDER_CANCELED_BY_USER');
        await notifyCentralPlatform(updatedOrder, 'canceled_by_user');

        return createResponse(200, {
            success: true,
            message: 'Order cancelled by user',
            order: normalizeOrderForFrontend(updatedOrder),
            id: orderId,
            orderId: orderId,
            businessId: resolveBusinessId(updatedOrder),
            status: 'canceled_by_user',
            reason: reason
        });

    } catch (error) {
        console.error('❌ Error cancelling order by user:', error);
        return createResponse(500, { success: false, message: 'Failed to cancel order by user' });
    }
}

/**
 * Handle order cancellation by store (after confirmation)
 * Used when restaurant cancels order due to issues
 */
async function handleCancelOrderByStore(orderId, data) {
    console.log(`🔄 Cancelling order by store: ${orderId}`, data);
    
    try {
        const { reason, storeId } = data;
        const timestamp = new Date().toISOString();

        // Get current order
        const getParams = {
            TableName: ORDERS_TABLE,
            Key: { 
                PK: `ORDER#${orderId}`,
                SK: 'META'
            }
        };

        const currentOrderResult = await dynamodb.send(new GetCommand(getParams));
        if (!currentOrderResult.Item) {
            console.error(`❌ Order not found: ${orderId}`);
            return createResponse(404, { success: false, message: 'Order not found' });
        }

        const currentOrder = currentOrderResult.Item;
        
        // Store can cancel after confirmation but before completion
        const allowedCancellationStatuses = ['confirmed', 'preparing', 'in_kitchen', 'ready'];
        if (!allowedCancellationStatuses.includes(currentOrder.status)) {
            return createResponse(400, { 
                success: false, 
                message: `Cannot cancel order in ${currentOrder.status} status` 
            });
        }

        // Update storeStatus with cancelled status
        const currentStoreStatus = currentOrder.storeStatus || `${currentOrder.storeId}#${currentOrder.status}#b1`;
        const bucketMatch = currentStoreStatus.match(/#(b\d+)$/);
        const bucket = bucketMatch ? bucketMatch[1] : 'b1';
        const newStoreStatus = `${currentOrder.storeId}#canceled_by_store#${bucket}`;

        const updateParams = {
            TableName: ORDERS_TABLE,
            Key: { 
                PK: `ORDER#${orderId}`,
                SK: 'META'
            },
            UpdateExpression: 'SET #status = :status, updatedAt = :timestamp, canceledAt = :timestamp, storeStatus = :storeStatus, canceledBy = :canceledBy, cancelReason = :reason, rev = if_not_exists(rev, :zero) + :one',
            ExpressionAttributeNames: {
                '#status': 'status'
            },
            ExpressionAttributeValues: {
                ':status': 'canceled_by_store',
                ':timestamp': timestamp,
                ':storeStatus': newStoreStatus,
                ':canceledBy': 'store',
                ':reason': reason || 'Store cancellation',
                ':zero': 0,
                ':one': 1
            },
            ReturnValues: 'ALL_NEW'
        };

        const result = await dynamodb.send(new UpdateCommand(updateParams));
        const updatedOrder = result.Attributes;

        console.log(`✅ Order cancelled by store: ${orderId} -> canceled_by_store`);

        // Notify Customer and Central Platform
        await publishOrderStatusUpdate(updatedOrder, 'ORDER_CANCELED_BY_STORE');
        await notifyCentralPlatform(updatedOrder, 'canceled_by_store');

        return createResponse(200, {
            success: true,
            message: 'Order cancelled by store',
            order: normalizeOrderForFrontend(updatedOrder),
            id: orderId,
            orderId: orderId,
            businessId: resolveBusinessId(updatedOrder),
            status: 'canceled_by_store',
            reason: reason
        });

    } catch (error) {
        console.error('❌ Error cancelling order by store:', error);
        return createResponse(500, { success: false, message: 'Failed to cancel order by store' });
    }
}

/**
 * Handle system timeout cancellation
 * Used when order times out without acceptance
 */
async function handleCancelOrderBySystem(orderId, data) {
    console.log(`🔄 Cancelling order by system (timeout): ${orderId}`, data);
    
    try {
        const { reason = 'Order timeout - no response from store' } = data;
        const timestamp = new Date().toISOString();

        // Get current order
        const getParams = {
            TableName: ORDERS_TABLE,
            Key: { 
                PK: `ORDER#${orderId}`,
                SK: 'META'
            }
        };

        const currentOrderResult = await dynamodb.send(new GetCommand(getParams));
        if (!currentOrderResult.Item) {
            console.error(`❌ Order not found: ${orderId}`);
            return createResponse(404, { success: false, message: 'Order not found' });
        }

        const currentOrder = currentOrderResult.Item;
        
        // System can cancel pending orders or long-standing ready orders
        const allowedCancellationStatuses = ['pending', 'ready'];
        if (!allowedCancellationStatuses.includes(currentOrder.status)) {
            return createResponse(400, { 
                success: false, 
                message: `Cannot cancel order in ${currentOrder.status} status` 
            });
        }

        // Update storeStatus with cancelled status
        const currentStoreStatus = currentOrder.storeStatus || `${currentOrder.storeId}#${currentOrder.status}#b1`;
        const bucketMatch = currentStoreStatus.match(/#(b\d+)$/);
        const bucket = bucketMatch ? bucketMatch[1] : 'b1';
        const newStoreStatus = `${currentOrder.storeId}#canceled_by_system#${bucket}`;

        const updateParams = {
            TableName: ORDERS_TABLE,
            Key: { 
                PK: `ORDER#${orderId}`,
                SK: 'META'
            },
            UpdateExpression: 'SET #status = :status, updatedAt = :timestamp, canceledAt = :timestamp, storeStatus = :storeStatus, canceledBy = :canceledBy, cancelReason = :reason, rev = if_not_exists(rev, :zero) + :one',
            ExpressionAttributeNames: {
                '#status': 'status'
            },
            ExpressionAttributeValues: {
                ':status': 'canceled_by_system',
                ':timestamp': timestamp,
                ':storeStatus': newStoreStatus,
                ':canceledBy': 'system',
                ':reason': reason,
                ':zero': 0,
                ':one': 1
            },
            ReturnValues: 'ALL_NEW'
        };

        const result = await dynamodb.send(new UpdateCommand(updateParams));
        const updatedOrder = result.Attributes;

        console.log(`✅ Order cancelled by system: ${orderId} -> canceled_by_system`);

        // Notify Customer, Store and Central Platform
        await publishOrderStatusUpdate(updatedOrder, 'ORDER_CANCELED_BY_SYSTEM');
        await notifyCentralPlatform(updatedOrder, 'canceled_by_system');

        return createResponse(200, {
            success: true,
            message: 'Order cancelled by system',
            order: normalizeOrderForFrontend(updatedOrder),
            id: orderId,
            orderId: orderId,
            businessId: resolveBusinessId(updatedOrder),
            status: 'canceled_by_system',
            reason: reason
        });

    } catch (error) {
        console.error('❌ Error cancelling order by system:', error);
        return createResponse(500, { success: false, message: 'Failed to cancel order by system' });
    }
}

/**
 * Publish order status update event (for EventBridge/SNS and WebSocket)
 */
async function publishOrderStatusUpdate(order, eventType) {
    try {
        const businessId = resolveBusinessId(order);
        const customerId = resolveCustomerId(order);
        const message = {
            eventType,
            orderId: order.orderId,
            businessId,
            customerId,
            status: order.status,
            timestamp: new Date().toISOString(),
            orderData: { ...order, businessId }
        };

        console.log('📤 Publishing order status update to SNS:', message);

        // Publish to SNS (existing functionality)
        if (process.env.ORDER_EVENTS_TOPIC_ARN) {
            await sns.send(new PublishCommand({
                TopicArn: process.env.ORDER_EVENTS_TOPIC_ARN,
                Message: JSON.stringify(message),
                MessageAttributes: {
                    eventType: { DataType: 'String', StringValue: eventType },
                    orderId: { DataType: 'String', StringValue: order.orderId }
                }
            }));
        }

        // Send WebSocket notification to customer app (NEW FUNCTIONALITY)
        await sendOrderUpdateToCustomer(order);

    } catch (error) {
        console.error('Error publishing order status update:', error);
    }
}

/**
 * Notify Central Platform about order status changes
 */
async function notifyCentralPlatform(order, status) {
    try {
        const start = Date.now();
        const businessId = resolveBusinessId(order);
        const notification = {
            orderId: order.orderId,
            orderNumber: order.orderNumber || order.orderId,
            businessId,
            status,
            total: order.pricing?.total != null ? Number(order.pricing.total) / 1000 : Number(order.total ?? order.totalAmount ?? 0),
            timestamp: new Date().toISOString()
        };
        console.log('📤 Notifying Central Platform:', notification);

        if (!CENTRAL_PLATFORM_WEBHOOK_URL) {
            console.log('ℹ️ CENTRAL_PLATFORM_WEBHOOK_URL not set, skipping notify');
            await recordCentralNotifyMetric('SKIPPED', 0);
            return;
        }
        if (typeof fetch !== 'function') {
            console.log('⚠️ fetch not available, skipping central notify');
            await recordCentralNotifyMetric('SKIPPED', 0);
            return;
        }

        const controller = new AbortController();
        const timeout = setTimeout(() => controller.abort(), 1500);
        let response;
        try {
            response = await fetch(CENTRAL_PLATFORM_WEBHOOK_URL, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(notification),
                signal: controller.signal
            });
        } catch (e) {
            if (e.name === 'AbortError') console.error('⏱️ Central notify timeout');
            else console.error('❌ Central notify network error:', e.message);
            await recordCentralNotifyMetric('FAILED', Date.now() - start);
            return;
        } finally { clearTimeout(timeout); }

        if (!response.ok) {
            const text = await response.text().catch(() => '');
            console.error(`❌ Central notify failed ${response.status}: ${text}`);
            await recordCentralNotifyMetric('FAILED', Date.now() - start);
            return;
        }
        console.log('✅ Central Platform notified');
        await recordCentralNotifyMetric('SUCCESS', Date.now() - start);
    } catch (error) {
        console.error('Error notifying central platform:', error.message);
        await recordCentralNotifyMetric('ERROR', 0);
    }
}

/**
 * Record CloudWatch metrics for Central Platform notify
 */
async function recordCentralNotifyMetric(result, durationMs) {
    try {
        if (!METRICS_NAMESPACE) return;
        await cloudwatch.send(new PutMetricDataCommand({
            Namespace: METRICS_NAMESPACE,
            MetricData: [
                { MetricName: 'CentralNotifyDurationMs', Value: durationMs, Unit: 'Milliseconds' },
                { MetricName: 'CentralNotifyResult', Value: 1, Unit: 'Count', Dimensions: [{ Name: 'Result', Value: result }] }
            ]
        }));
    } catch (e) {
        console.error('⚠️ Failed to record metric:', e.message);
    }
}

/**
 * Send order status update to customer via WebSocket
 * This connects to WizzUser WebSocket API to notify customers
 */
async function sendOrderUpdateToCustomer(order) {
    try {
        console.log('📡 Sending order update to customer via WebSocket:', order.orderId);

        // Use WizzUser WebSocket endpoint
        const wizzUserWebSocketEndpoint = process.env.WIZZUSER_WEBSOCKET_ENDPOINT;
        if (!wizzUserWebSocketEndpoint) {
            throw new Error('Missing required env var: WIZZUSER_WEBSOCKET_ENDPOINT');
        }
        
        // Prepare order update message for customer
        const orderUpdateMessage = {
            type: 'ORDER_STATUS_UPDATE',
            orderId: order.orderId,
            orderNumber: order.orderNumber || order.orderId,
            status: order.status,
            estimatedDeliveryTime: order.estimatedDeliveryTime,
            deliveryTime: order.deliveryTime,
            message: getStatusMessageForCustomer(order.status),
            timestamp: new Date().toISOString()
        };

        // Call WizzUser WebSocket send-update function
        const updatePayload = {
            orderId: order.orderId,
            updateData: orderUpdateMessage,
            websocketEndpoint: wizzUserWebSocketEndpoint
        };

        console.log('📤 Sending WebSocket update payload:', JSON.stringify(updatePayload, null, 2));

        const sendFunctionName = process.env.USER_WEBSOCKET_SEND_FUNCTION_NAME;
        if (!sendFunctionName) {
            console.warn('⚠️ USER_WEBSOCKET_SEND_FUNCTION_NAME not set; skipping customer WebSocket update');
            return;
        }

        // Invoke WizzUser WebSocket send-update Lambda function
        const AWS = require('aws-sdk');
        const lambda = new AWS.Lambda({ region: 'us-east-1' });
        
        const invokeParams = {
            FunctionName: sendFunctionName,
            Payload: JSON.stringify(updatePayload),
            InvocationType: 'Event' // Async invocation
        };

        const result = await lambda.invoke(invokeParams).promise();
        console.log('📨 WebSocket update sent to customer successfully:', result.StatusCode);

    } catch (error) {
        console.error('❌ Error sending order update to customer via WebSocket:', error);
        // Don't throw error to prevent breaking the main flow
    }
}

/**
 * Get status message for customer in Arabic
 */
function getStatusMessageForCustomer(status) {
    const statusMessages = {
        'pending': 'تم استلام طلبك وننتظر موافقة المطعم',
        'confirmed': 'تم تأكيد طلبك من المطعم',
        'preparing': 'يتم تحضير طلبك الآن',
        'in_kitchen': 'يتم تحضير طلبك في المطبخ',
        'ready': 'طلبك جاهز للتوصيل',
        'out_for_delivery': 'السائق في الطريق إليك',
        'on_the_way': 'السائق في الطريق إليك',
        'delivered': 'تم توصيل طلبك بنجاح',
        'completed': 'تم إكمال طلبك بنجاح',
        'cancelled': 'تم إلغاء الطلب',
        'rejected': 'تم رفض الطلب من المطعم',
        'canceled_by_user': 'تم إلغاء الطلب بواسطة العميل',
        'canceled_by_store': 'تم إلغاء الطلب من المطعم',
        'canceled_by_system': 'تم إلغاء الطلب تلقائياً'
    };

    return statusMessages[status] || 'تحديث حالة الطلب';
}

/**
 * Notify merchant about new orders or updates
 * Uses isolated push notification service - fire-and-forget, non-blocking
 */
async function notifyMerchant(businessId, notification) {
    try {
        console.log('🔔 Notifying merchant:', businessId);

        // Centralized push notifications (same approach as user/driver apps):
        // merchant app registers tokens directly in Central Notifications using Cognito sub.
        const ownerId = await getBusinessOwnerId(businessId);
        if (!ownerId) {
            console.log('📱 [PUSH] No ownerId for business; skipping push:', businessId);
        } else {
            sendMerchantOrderPush({
                subjectId: ownerId,
                action: String(notification.action || notification.type || 'new_order'),
                orderId: String(notification.orderId || '').trim(),
                orderNumber: notification.orderNumber,
                businessId,
                businessName: notification.businessName,
                customerName: notification.customerName,
                totalAmount: notification.totalAmount,
                updatedAt: notification.updatedAt || new Date().toISOString(),
            }).then((resp) => {
                if (!resp?.ok) {
                    console.log('⚠️ [PUSH] Central push failed:', resp?.status, resp?.body);
                } else {
                    console.log('✅ [PUSH] Central push accepted:', resp?.status);
                }
            }).catch((error) => {
                console.error('⚠️ [PUSH] Central push error (non-blocking):', error?.message || String(error));
            });
        }

        // Also send via WebSocket if available (backward compatibility)
        try {
            await sendWebSocketNotifications(businessId, notification);
        } catch (error) {
            console.error('⚠️ WebSocket notification failed:', error.message);
        }

        console.log('✅ Notification process initiated (non-blocking)');

    } catch (error) {
        // Never throw from this function - it should never break order processing
        console.error('❌ Error in notifyMerchant (non-fatal):', error.message);
    }
}

/**
 * Send WebSocket notifications (updated for wizzbussiness WebSocket table)
 */
async function sendWebSocketNotifications(businessId, notification) {
    try {
        // Use new WebSocket connections table from wizzbussiness integration
        if (!WEBSOCKET_CONNECTIONS_TABLE) {
            console.log('⚠️ WEBSOCKET_CONNECTIONS_TABLE not configured, skipping WebSocket notifications');
            return;
        }

        const params = {
            TableName: WEBSOCKET_CONNECTIONS_TABLE,
            IndexName: 'businessId-index',
            KeyConditionExpression: 'businessId = :businessId',
            FilterExpression: 'isActive = :active',
            ExpressionAttributeValues: {
                ':businessId': businessId,
                ':active': true
            }
        };

        const result = await dynamodb.send(new QueryCommand(params));
        const connections = result.Items || [];

        console.log(`📡 Found ${connections.length} active WebSocket connections for business ${businessId}`);

        if (connections.length === 0) {
            console.log('📡 No active WebSocket connections found');
            return;
        }

        // Send to all active connections
        const apiGwClient = new ApiGatewayManagementApiClient({
            endpoint: process.env.WEBSOCKET_ENDPOINT?.replace('wss://', 'https://'),
            region: process.env.AWS_REGION || 'us-east-1'
        });

        const message = {
            type: 'ORDER_NOTIFICATION',
            notification: notification,
            timestamp: new Date().toISOString()
        };

        const promises = connections.map(async (conn) => {
            try {
                await apiGwClient.send(new PostToConnectionCommand({
                    ConnectionId: conn.connectionId,
                    Data: JSON.stringify(message)
                }));
                console.log(`📡 WebSocket sent to: ${conn.connectionId}`);
            } catch (error) {
                if (error.statusCode === 410) {
                    console.log(`📡 Stale connection removed: ${conn.connectionId}`);
                    // Mark connection as inactive
                    await dynamodb.send(new UpdateCommand({
                        TableName: WEBSOCKET_CONNECTIONS_TABLE,
                        Key: { connectionId: conn.connectionId },
                        UpdateExpression: 'SET isActive = :false',
                        ExpressionAttributeValues: { ':false': false }
                    }));
                } else {
                    console.error(`📡 WebSocket error for ${conn.connectionId}:`, error.message);
                }
            }
        });

        await Promise.allSettled(promises);
        console.log(`📡 WebSocket notifications sent to ${connections.length} connections`);

    } catch (error) {
        console.error('⚠️ Error in sendWebSocketNotifications:', error.message);
    }
}

// Old WebSocket functions removed - now using wizzbussiness WebSocket integration
// See sendWebSocketNotifications() above for the updated implementation

/**
 * Log timeout events for orders
 */
async function handleTimeoutLog(orderId, requestData) {
    try {
        console.log('⏰ Logging timeout event for order:', orderId, 'Data:', requestData);

        const { timeoutType, businessId, remainingSeconds, alertLevel } = requestData;

        if (!timeoutType || !businessId) {
            return createResponse(400, {
                success: false,
                message: 'Missing required fields: timeoutType and businessId'
            });
        }

        // Validate timeout type
        const validTimeoutTypes = ['firstAlert', 'urgentAlert', 'autoReject'];
        if (!validTimeoutTypes.includes(timeoutType)) {
            return createResponse(400, {
                success: false,
                message: 'Invalid timeout type. Must be: firstAlert, urgentAlert, or autoReject'
            });
        }

        // Create timeout log entry
        const timestamp = new Date().toISOString();
        const ttl = Math.floor(Date.now() / 1000) + (30 * 24 * 60 * 60); // 30 days TTL

        const timeoutLogItem = {
            orderId,
            timestamp,
            businessId,
            timeoutType,
            alertLevel: alertLevel || timeoutType,
            remainingSeconds: remainingSeconds || 0,
            deviceTimestamp: new Date().toISOString(),
            ttl
        };

        await dynamodb.send(new PutCommand({
            TableName: TIMEOUT_LOGS_TABLE,
            Item: timeoutLogItem
        }));

        console.log('⏰ Successfully logged timeout event:', timeoutLogItem);

        return createResponse(200, {
            success: true,
            message: 'Timeout event logged successfully',
            data: {
                orderId,
                timeoutType,
                timestamp
            }
        });

    } catch (error) {
        console.error('❌ Error logging timeout event:', error);
        return createResponse(500, {
            success: false,
            message: 'Failed to log timeout event',
            error: error.message
        });
    }
}

const originalMerchantHandler=module.exports.handler;
const authenticatedMerchantHandler=merchantHandler(originalMerchantHandler,{db:lifecycleRawDb,deviceOrders:true});
module.exports.handler=async(event,context)=>{
 if(event.path?.includes('/webhooks/orders')&&event.httpMethod==='POST'){
  const expected=process.env.MERCHANT_WEBHOOK_INTERNAL_KEY;
  const supplied=event.headers?.['x-merchant-webhook-key']||event.headers?.['X-Merchant-Webhook-Key'];
  if(!expected||typeof supplied!=='string'||supplied.length!==expected.length||!require('node:crypto').timingSafeEqual(Buffer.from(supplied),Buffer.from(expected)))return createResponse(401,{code:'UNAUTHORIZED'});
  let body;try{body=JSON.parse(event.body||'{}');}catch(_){return createResponse(400,{code:'INVALID_BODY'});}
  const order=(await lifecycleRawDb.send(new GetCommand({TableName:ORDERS_TABLE,Key:{PK:'ORDER#'+body.orderId,SK:'META'},ConsistentRead:true}))).Item;
  const businessId=resolveBusinessId(order);
  if(!order||businessId!==body.storeId)return createResponse(403,{code:'ORDER_BUSINESS_SCOPE_INVALID'});
  const business=(await lifecycleRawDb.send(new GetCommand({TableName:'WhizzMerchants_Businesses',Key:{businessId},ConsistentRead:true}))).Item;
  if(!business||business.deletionRequestId||!business.ownerId||business.ownerId!==business.cognitoUserId)return createResponse(409,{code:'BUSINESS_UNAVAILABLE'});
  return require('../shared/merchant-lifecycle').merchantRequestContext.run({sub:business.ownerId,businessId},()=>originalMerchantHandler(event,context));
 }
 return authenticatedMerchantHandler(event,context);
};
