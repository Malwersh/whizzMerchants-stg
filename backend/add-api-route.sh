#!/bin/bash

# Script to add device token route to API Gateway
set -e

API_ID="${API_ID:-v3pmynegul}"
REGION="${REGION:-us-east-1}"
LAMBDA_ARN="${LAMBDA_ARN:-}"
STAGE="${STAGE:-staging}"

if [ -z "$LAMBDA_ARN" ]; then
  echo "❌ Missing required env var: LAMBDA_ARN" >&2
  exit 1
fi

echo "🔧 Adding POST /merchants/{merchantId}/device-token route to API Gateway..."

# Get API details
echo "📡 Getting API Gateway details..."
aws apigatewayv2 get-apis --region $REGION | jq -r '.Items[] | select(.ApiId=="'$API_ID'")'

# Create integration
echo "🔗 Creating Lambda integration..."
INTEGRATION_ID=$(aws apigatewayv2 create-integration \
  --region $REGION \
  --api-id $API_ID \
  --integration-type AWS_PROXY \
  --integration-uri $LAMBDA_ARN \
  --payload-format-version 2.0 \
  --output text --query 'IntegrationId')

echo "✅ Integration created: $INTEGRATION_ID"

# Create route
echo "🛣️  Creating route POST /merchants/{merchantId}/device-token..."
ROUTE_ID=$(aws apigatewayv2 create-route \
  --region $REGION \
  --api-id $API_ID \
  --route-key 'POST /merchants/{merchantId}/device-token' \
  --target "integrations/$INTEGRATION_ID" \
  --authorization-type JWT \
  --output text --query 'RouteId')

echo "✅ Route created: $ROUTE_ID"

# Grant API Gateway permission to invoke Lambda
echo "🔐 Granting API Gateway permission to invoke Lambda..."
aws lambda add-permission \
  --region $REGION \
  --function-name whizz-merchants-register-device-token \
  --statement-id apigateway-invoke-device-token \
  --action lambda:InvokeFunction \
  --principal apigateway.amazonaws.com \
  --source-arn "arn:aws:execute-api:$REGION:031857856164:$API_ID/*/*/merchants/*/device-token" \
  2>/dev/null || echo "⚠️  Permission already exists (OK)"

echo ""
echo "✅ API route setup complete!"
echo ""
echo "📱 Test the endpoint:"
echo "POST https://$API_ID.execute-api.$REGION.amazonaws.com/$STAGE/merchants/MERCHANT_TEST_001/device-token"
echo ""

