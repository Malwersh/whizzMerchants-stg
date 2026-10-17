const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { DynamoDBDocumentClient, GetCommand, UpdateCommand } = require('@aws-sdk/lib-dynamodb');

const dynamoDbClient = new DynamoDBClient({ region: process.env.AWS_REGION || 'us-east-1' });
const dynamodb = DynamoDBDocumentClient.from(dynamoDbClient);

const BUSINESSES_TABLE = process.env.BUSINESSES_TABLE || 'WhizzMerchants_Businesses';
const ORDERS_TABLE = process.env.ORDERS_TABLE || 'WizzOrders';

const DEFAULT_SETTINGS = {
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

function resolveBusinessId(order) {
  return order?.businessId || order?.storeId || order?.merchantId;
}

function resolveTotalAmount(order) {
  if (order.pricing && typeof order.pricing.total === 'number') {
    return order.pricing.total / 1000;
  }
  if (typeof order.totalAmount === 'number') {
    return order.totalAmount;
  }
  if (typeof order.total === 'number') {
    return order.total;
  }
  return 0;
}

function resolveDeliveryFee(order) {
  if (order.pricing && typeof order.pricing.deliveryFee === 'number') {
    return order.pricing.deliveryFee / 1000;
  }
  if (typeof order.deliveryFee === 'number') {
    return order.deliveryFee;
  }
  return 0;
}

/**
 * Fetch POS settings for a business.
 */
async function getPosSettings(businessId) {
  try {
    const result = await dynamodb.send(new GetCommand({
      TableName: BUSINESSES_TABLE,
      Key: { businessId },
      ProjectionExpression: 'posSettings'
    }));

    return { ...DEFAULT_SETTINGS, ...(result.Item?.posSettings || {}) };
  } catch (error) {
    console.error(`❌ Error reading POS settings for business ${businessId}:`, error);
    return DEFAULT_SETTINGS;
  }
}

/**
 * Forward an accepted order to the configured external POS.
 * This function never throws; failures are logged and returned.
 */
async function forwardAcceptedOrder(order) {
  const businessId = resolveBusinessId(order);
  if (!businessId) {
    console.warn('⚠️ Cannot forward order: businessId missing');
    return { skipped: true, reason: 'businessId missing' };
  }

  const posSettings = await getPosSettings(businessId);

  if (!posSettings.enabled) {
    console.log(`📭 POS integration disabled for business ${businessId}; skipping forward`);
    return { skipped: true, reason: 'POS integration disabled' };
  }

  if (!posSettings.autoSendOrders) {
    console.log(`📭 autoSendOrders disabled for business ${businessId}; skipping forward`);
    return { skipped: true, reason: 'autoSendOrders disabled' };
  }

  if (!posSettings.apiEndpoint || posSettings.apiEndpoint.trim() === '') {
    console.warn(`⚠️ POS enabled but no apiEndpoint for business ${businessId}`);
    return { success: false, error: 'API endpoint not configured' };
  }

  const timeoutSeconds = Math.min(Math.max(parseInt(posSettings.timeoutSeconds, 10) || 30, 10), 120);
  const payload = {
    event: 'order.accepted',
    posSystem: posSettings.systemType || 'genericApi',
    testMode: !!posSettings.testMode,
    locationId: posSettings.locationId || '',
    orderId: order.orderId || order.id,
    orderNumber: order.orderNumber || order.orderId || order.id,
    businessId,
    storeId: order.storeId,
    storeName: order.storeName,
    customerName: order.customerName || 'Unknown Customer',
    customerPhone: order.customerPhone,
    customerAddress: order.customerAddress,
    deliveryAddress: order.deliveryAddress,
    notes: order.notes || order.deliveryInstructions,
    createdAt: order.createdAt,
    acceptedAt: new Date().toISOString(),
    totalAmount: resolveTotalAmount(order),
    deliveryFee: resolveDeliveryFee(order),
    items: order.items || []
  };

  const headers = {
    'Content-Type': 'application/json'
  };
  if (posSettings.apiKey && posSettings.apiKey.trim() !== '') {
    headers['Authorization'] = `Bearer ${posSettings.apiKey.trim()}`;
  }
  if (posSettings.locationId && posSettings.locationId.trim() !== '') {
    headers['X-Location-Id'] = posSettings.locationId.trim();
  }
  headers['X-POS-System'] = posSettings.systemType || 'genericApi';
  if (posSettings.testMode) {
    headers['X-Test-Mode'] = 'true';
  }

  console.log(`🛒 Forwarding order ${payload.orderId} to POS for business ${businessId}: ${posSettings.apiEndpoint}`);

  try {
    const controller = new AbortController();
    const timeoutMs = timeoutSeconds * 1000;
    const timeoutHandle = setTimeout(() => controller.abort(), timeoutMs);

    const response = await fetch(posSettings.apiEndpoint.trim(), {
      method: 'POST',
      headers,
      body: JSON.stringify(payload),
      signal: controller.signal
    });

    clearTimeout(timeoutHandle);

    let responseBody = '';
    try {
      responseBody = await response.text();
    } catch (e) {
      // ignore body read errors
    }

    let posOrderId = null;
    try {
      const parsed = JSON.parse(responseBody);
      posOrderId = parsed.orderId || parsed.posOrderId || parsed.id || null;
    } catch (e) {
      // response wasn't JSON
    }

    if (response.status >= 200 && response.status < 300) {
      console.log(`✅ Order ${payload.orderId} forwarded to POS successfully. POS order id: ${posOrderId}`);

      // Persist POS reference on the order (best effort)
      await recordPosForwardResult(payload.orderId, {
        success: true,
        posOrderId,
        posResponse: responseBody,
        forwardedAt: new Date().toISOString()
      });

      return {
        success: true,
        posOrderId,
        posResponse: responseBody
      };
    }

    console.error(`❌ POS forward failed for order ${payload.orderId}: HTTP ${response.status} ${responseBody}`);

    await recordPosForwardResult(payload.orderId, {
      success: false,
      statusCode: response.status,
      posResponse: responseBody,
      forwardedAt: new Date().toISOString()
    });

    return {
      success: false,
      statusCode: response.status,
      error: responseBody || response.statusText
    };
  } catch (error) {
    console.error(`❌ POS forward exception for order ${payload.orderId}:`, error);

    await recordPosForwardResult(payload.orderId, {
      success: false,
      error: error.message || String(error),
      forwardedAt: new Date().toISOString()
    });

    return {
      success: false,
      error: error.message || String(error)
    };
  }
}

/**
 * Record POS forward result on the order item (best effort).
 */
async function recordPosForwardResult(orderId, result) {
  if (!orderId) return;
  try {
    await dynamodb.send(new UpdateCommand({
      TableName: ORDERS_TABLE,
      Key: {
        PK: `ORDER#${orderId}`,
        SK: 'META'
      },
      UpdateExpression: 'SET posForwardResult = :result',
      ExpressionAttributeValues: {
        ':result': result
      }
    }));
  } catch (error) {
    console.error(`⚠️ Failed to record POS forward result for order ${orderId}:`, error);
  }
}

module.exports = {
  forwardAcceptedOrder
};
