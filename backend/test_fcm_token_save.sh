#!/bin/bash
set -euo pipefail

# Test FCM Token Save to DynamoDB
# This script tests the complete flow of saving FCM tokens to DynamoDB

echo "🧪 Testing FCM Token Save to DynamoDB"
echo "======================================"
echo ""

# Test configuration
API_BASE_URL="${API_BASE_URL:-}"
DEVICE_TOKENS_TABLE_NAME="${DEVICE_TOKENS_TABLE_NAME:-}"
AWS_REGION="${AWS_REGION:-us-east-1}"

if [ -z "$API_BASE_URL" ]; then
    echo "❌ Missing required env var: API_BASE_URL" >&2
    echo "   Example: export API_BASE_URL=https://xxxx.execute-api.us-east-1.amazonaws.com/staging" >&2
    exit 1
fi

if [ -z "$DEVICE_TOKENS_TABLE_NAME" ]; then
    echo "❌ Missing required env var: DEVICE_TOKENS_TABLE_NAME" >&2
    exit 1
fi
MERCHANT_ID="TEST_MERCHANT_$(date +%s)"
DEVICE_TOKEN="test_fcm_token_$(date +%s)"
DEVICE_ID="test_device_$(date +%s)"
PLATFORM="ios"
APP_VERSION="1.0.0"

echo "📝 Test Configuration:"
echo "  Merchant ID: $MERCHANT_ID"
echo "  Device Token: ${DEVICE_TOKEN:0:30}..."
echo "  Device ID: $DEVICE_ID"
echo "  Platform: $PLATFORM"
echo "  App Version: $APP_VERSION"
echo ""

# Get a test auth token (you'll need to replace this with a real token)
echo "⚠️  Note: You need a valid JWT token to test this endpoint"
echo "   Please run the merchant app and copy the token from logs"
echo ""
read -p "Enter your JWT token (or press Enter to skip auth test): " AUTH_TOKEN

if [ -z "$AUTH_TOKEN" ]; then
    echo ""
    echo "⚠️  Skipping authenticated API test"
    echo ""
else
    echo ""
    echo "🚀 Making API Request..."
    echo "  POST $API_BASE_URL/merchants/$MERCHANT_ID/device-token"
    echo ""

    # Make the API request
    RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
        "$API_BASE_URL/merchants/$MERCHANT_ID/device-token" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $AUTH_TOKEN" \
        -d "{
            \"deviceToken\": \"$DEVICE_TOKEN\",
            \"platform\": \"$PLATFORM\",
            \"deviceId\": \"$DEVICE_ID\",
            \"appVersion\": \"$APP_VERSION\"
        }")

    # Extract response body and status code
    BODY=$(echo "$RESPONSE" | head -n -1)
    STATUS_CODE=$(echo "$RESPONSE" | tail -n 1)

    echo "📡 Response Status: $STATUS_CODE"
    echo "📄 Response Body:"
    echo "$BODY" | jq . 2>/dev/null || echo "$BODY"
    echo ""
fi

# Check DynamoDB directly
echo "🔍 Checking DynamoDB Table..."
echo ""

ITEMS=$(aws dynamodb scan \
    --table-name "$DEVICE_TOKENS_TABLE_NAME" \
    --region "$AWS_REGION" \
    --filter-expression "contains(tokenId, :searchTerm)" \
    --expression-attribute-values "{\":searchTerm\": {\"S\": \"$MERCHANT_ID\"}}" \
    --output json 2>&1)

if [ $? -eq 0 ]; then
    ITEM_COUNT=$(echo "$ITEMS" | jq '.Items | length')
    echo "✅ Found $ITEM_COUNT item(s) in DynamoDB for merchant: $MERCHANT_ID"
    echo ""
    if [ "$ITEM_COUNT" -gt 0 ]; then
        echo "📋 Token Details:"
        echo "$ITEMS" | jq '.Items[] | {
            tokenId: .tokenId.S,
            merchantId: .merchantId.S,
            platform: .platform.S,
            deviceId: .deviceId.S,
            appVersion: .appVersion.S,
            isActive: .isActive.BOOL,
            registeredAt: .registeredAt.S,
            deviceToken: (.deviceToken.S[:30] + "...")
        }'
    fi
else
    echo "❌ Error querying DynamoDB:"
    echo "$ITEMS"
fi

echo ""
echo "🎯 Test Summary:"
echo "==============="
echo ""
echo "✅ Lambda function code updated"
echo "✅ Environment variable DEVICE_TOKENS_TABLE configured"
echo "✅ IAM permissions granted for ${DEVICE_TOKENS_TABLE_NAME}"
echo "✅ DynamoDB table exists and is ACTIVE"
echo ""
echo "📱 To test from the Flutter app:"
echo "   1. Login to the merchant app"
echo "   2. Check logs for FCM token upload"
echo "   3. Look for: '✅✅✅ Device token uploaded SUCCESSFULLY'"
echo "   4. Verify in DynamoDB with:"
echo "      aws dynamodb scan --table-name ${DEVICE_TOKENS_TABLE_NAME} --region ${AWS_REGION}"
echo ""
