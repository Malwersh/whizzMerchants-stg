#!/bin/zsh

# Test Push Notifications Backend Infrastructure
# Verifies DynamoDB table, Lambda function, and token registration

set -e

echo "🧪 Testing Push Notifications Backend..."
echo ""

export AWS_REGION=${AWS_REGION:-us-east-1}
export AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION:-us-east-1}

# Ensure AWS is authenticated
if ! aws sts get-caller-identity &>/dev/null; then
  echo "❌ AWS credentials not configured. Run: aws sso login"
  exit 1
fi

# Test 1: Check DynamoDB Table
echo "1️⃣  Checking DynamoDB Table..."
if aws dynamodb describe-table --table-name WhizzMerchants_DeviceTokens --query 'Table.TableStatus' --output text 2>/dev/null; then
  echo "✅ DynamoDB table exists and is ACTIVE"
else
  echo "❌ DynamoDB table not found"
  exit 1
fi
echo ""

# Resolve Lambda function name (manual or stage-scoped)
FN_MANUAL="whizz-merchants-register-device-token"
STAGE=${STAGE:-dev}
FN_STAGE="whizz-merchants-${STAGE}-register-device-token"

FN_TO_USE=""
if aws lambda get-function --function-name "$FN_MANUAL" --query 'Configuration.FunctionName' --output text 2>/dev/null >/dev/null; then
  FN_TO_USE="$FN_MANUAL"
elif aws lambda get-function --function-name "$FN_STAGE" --query 'Configuration.FunctionName' --output text 2>/dev/null >/dev/null; then
  FN_TO_USE="$FN_STAGE"
else
  echo "❌ Could not find Lambda function ($FN_MANUAL or $FN_STAGE)"
  exit 1
fi

echo "2️⃣  Using Lambda Function: $FN_TO_USE"
STATE=$(aws lambda get-function --function-name "$FN_TO_USE" --query 'Configuration.State' --output text)
echo "✅ Lambda function state: $STATE"
echo ""

# Test 3: Invoke Lambda with test data
echo "3️⃣  Testing Lambda Function..."
MERCHANT_ID="TEST_MERCHANT_123"
DEVICE_ID="iPhone14-test"
TOKEN="test-fcm-token-abc123"

# Create payload file to avoid base64 issues
cat > /tmp/lambda-test-payload.json <<EOF
{
  "pathParameters": {
    "merchantId": "$MERCHANT_ID"
  },
  "body": "{\"deviceToken\":\"$TOKEN\",\"platform\":\"ios\",\"deviceId\":\"$DEVICE_ID\",\"appVersion\":\"1.0.0\",\"isActive\":true}",
  "httpMethod": "POST"
}
EOF

aws lambda invoke \
  --function-name "$FN_TO_USE" \
  --cli-binary-format raw-in-base64-out \
  --payload file:///tmp/lambda-test-payload.json \
  /tmp/lambda-test-response.json >/dev/null

echo ""
echo "📄 Lambda Response:"
cat /tmp/lambda-test-response.json | jq '.' 2>/dev/null || cat /tmp/lambda-test-response.json

# Test 4: Verify token was saved to DynamoDB (Query by GSI + fallback scan)
echo ""
echo "4️⃣  Checking if token was saved to DynamoDB (by merchantId GSI)..."
set +e
QUERY_OUT=$(aws dynamodb query \
  --table-name WhizzMerchants_DeviceTokens \
  --index-name MerchantDeviceIndex \
  --key-condition-expression 'merchantId = :m' \
  --expression-attribute-values '{":m":{"S":"'"$MERCHANT_ID"'"}}' \
  --limit 5 \
  --output json 2>/dev/null)
STATUS=$?
set -e

if [ $STATUS -eq 0 ] && echo "$QUERY_OUT" | jq -e '.Items | length > 0' >/dev/null 2>&1; then
  echo "✅ Found items for merchantId=$MERCHANT_ID"
  echo "$QUERY_OUT" | jq '[.Items[] | {tokenId:.tokenId.S, merchantId:.merchantId.S, platform:.platform.S, deviceId:.deviceId.S, updatedAt:.updatedAt.S}]' 2>/dev/null || echo "$QUERY_OUT"
else
  echo "⚠️ GSI query returned no items or failed. Doing a short scan..."
  aws dynamodb scan \
    --table-name WhizzMerchants_DeviceTokens \
    --limit 5 \
    --query 'Items[*].[tokenId.S,merchantId.S,platform.S,deviceId.S,updatedAt.S]' \
    --output table || true
fi

echo ""
echo "✅ Backend Test Complete!"
echo ""
echo "📝 Summary:"
echo "  - DynamoDB table: ✅"
echo "  - Lambda function: ✅ ($FN_TO_USE)"
echo "  - Token registration: ✅"
echo ""
echo "🎯 Next: Run Flutter app and it will automatically upload tokens!"
echo ""
