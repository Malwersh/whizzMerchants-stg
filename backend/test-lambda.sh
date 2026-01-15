#!/bin/bash

# Test Lambda Function - Simple Version
# Tests the device token registration Lambda

export AWS_REGION=us-east-1

echo "🧪 Testing Lambda Function..."
echo ""

# Create a test payload file
cat > /tmp/lambda-test-payload.json << 'EOF'
{
  "pathParameters": {
    "merchantId": "TEST_MERCHANT_123"
  },
  "body": "{\"deviceToken\":\"test-fcm-token-abc123\",\"platform\":\"ios\",\"deviceId\":\"iPhone14-test\",\"appVersion\":\"1.0.0\",\"isActive\":true}",
  "httpMethod": "POST"
}
EOF

echo "📤 Invoking Lambda with test payload..."
aws lambda invoke \
  --function-name whizz-merchants-register-device-token \
  --region us-east-1 \
  --payload file:///tmp/lambda-test-payload.json \
  --no-cli-pager \
  /tmp/lambda-response.json

echo ""
echo "📥 Lambda Response:"
cat /tmp/lambda-response.json | python3 -m json.tool 2>/dev/null || cat /tmp/lambda-response.json
echo ""

# Check if it was successful
if grep -q '"success":true' /tmp/lambda-response.json; then
  echo "✅ Lambda test PASSED!"
  echo ""
  echo "📊 Checking DynamoDB for the test token..."
  aws dynamodb scan \
    --table-name WhizzMerchants_DeviceTokens \
    --region us-east-1 \
    --limit 5 \
    --no-cli-pager \
    --query 'Items[*].[tokenId.S,merchantId.S,platform.S,deviceId.S]' \
    --output table
  
  echo ""
  echo "🎉 Backend is fully operational!"
  echo ""
  echo "🚀 Next Step: Run Flutter app to capture real FCM token"
  echo "   cd /Users/ghaythallaheebi/WhizzEcoSystem/whizzEcosystem/whizzMerchants/frontend"
  echo "   flutter run -d 00008110-001C79140284801E --debug"
else
  echo "❌ Lambda test FAILED"
  echo "Check the response above for errors"
fi
