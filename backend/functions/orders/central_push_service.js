function normalizeBaseUrl(baseUrl) {
  const v = String(baseUrl || '').trim();
  if (!v) return '';
  return v.replace(/\/$/, '');
}

async function postJson(url, { headers, body, timeoutMs = 10000 }) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const resp = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        ...(headers || {}),
      },
      body: JSON.stringify(body || {}),
      signal: controller.signal,
    });

    const text = await resp.text();
    let parsed;
    try {
      parsed = text ? JSON.parse(text) : null;
    } catch (_) {
      parsed = { raw: text };
    }

    return { status: resp.status, ok: resp.ok, body: parsed };
  } finally {
    clearTimeout(timeout);
  }
}

async function sendMerchantOrderPush({
  subjectId,
  action,
  orderId,
  orderNumber,
  businessId,
  businessName,
  customerName,
  totalAmount,
  updatedAt,
}) {
  const baseUrl = normalizeBaseUrl(process.env.CENTRAL_PUSH_API_BASE_URL);
  const internalKey = String(process.env.CENTRAL_NOTIFICATIONS_INTERNAL_KEY || '').trim();

  if (!baseUrl) throw new Error('Missing CENTRAL_PUSH_API_BASE_URL');
  if (!internalKey) throw new Error('Missing CENTRAL_NOTIFICATIONS_INTERNAL_KEY');
  if (!subjectId) throw new Error('Missing subjectId');
  if (!action) throw new Error('Missing action');
  if (!orderId) throw new Error('Missing orderId');

  const url = `${baseUrl}/push/send/merchant-order`;

  return postJson(url, {
    headers: {
      'x-internal-key': internalKey,
    },
    body: {
      subjectId,
      action,
      orderId,
      orderNumber,
      businessId,
      businessName,
      customerName,
      totalAmount,
      updatedAt,
    },
    timeoutMs: 10000,
  });
}

module.exports = {
  sendMerchantOrderPush,
};
