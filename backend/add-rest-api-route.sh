#!/bin/bash
set -e

API_ID="${API_ID:-v3pmynegul}"
REGION="${REGION:-us-east-1}"
LAMBDA_ARN="${LAMBDA_ARN:-}"
ACCOUNT_ID="${ACCOUNT_ID:-}"
STAGE="${STAGE:-staging}"

if [ -z "$LAMBDA_ARN" ]; then
  echo "❌ Missing required env var: LAMBDA_ARN" >&2
  exit 1
fi

if [ -z "$ACCOUNT_ID" ]; then
  echo "❌ Missing required env var: ACCOUNT_ID" >&2
  exit 1
fi

echo "🔧 Adding device token route to REST API: $API_ID"

# Get root resource ID
echo "📡 Getting root resource..."
ROOT_ID=$(aws apigateway get-resources --rest-api-id $API_ID --region $REGION --query 'items[?path==`/`].id' --output text)
echo "Root ID: $ROOT_ID"

# Check if /merchants resource exists
MERCHANTS_ID=$(aws apigateway get-resources --rest-api-id $API_ID --region $REGION --query 'items[?pathPart==`merchants`].id' --output text)

if [ -z "$MERCHANTS_ID" ]; then
  echo "Creating /merchants resource..."
  MERCHANTS_ID=$(aws apigateway create-resource \
    --rest-api-id $API_ID \
    --region $REGION \
    --parent-id $ROOT_ID \
    --path-part merchants \
    --query 'id' --output text)
fi
echo "✅ Merchants resource: $MERCHANTS_ID"

# Create {merchantId} resource
echo "Creating /{merchantId} resource..."
MERCHANT_ID_RESOURCE=$(aws apigateway create-resource \
  --rest-api-id $API_ID \
  --region $REGION \
  --parent-id $MERCHANTS_ID \
  --path-part '{merchantId}' \
  --query 'id' --output text)
echo "✅ MerchantId resource: $MERCHANT_ID_RESOURCE"

# Create /device-token resource
echo "Creating /device-token resource..."
DEVICE_TOKEN_RESOURCE=$(aws apigateway create-resource \
  --rest-api-id $API_ID \
  --region $REGION \
  --parent-id $MERCHANT_ID_RESOURCE \
  --path-part 'device-token' \
  --query 'id' --output text)
echo "✅ Device-token resource: $DEVICE_TOKEN_RESOURCE"

# Create POST method
echo "Creating POST method..."
aws apigateway put-method \
  --rest-api-id $API_ID \
  --region $REGION \
  --resource-id $DEVICE_TOKEN_RESOURCE \
  --http-method POST \
  --authorization-type AWS_IAM \
  --request-parameters "method.request.path.merchantId=true"

# Create Lambda integration
echo "Creating Lambda integration..."
aws apigateway put-integration \
  --rest-api-id $API_ID \
  --region $REGION \
  --resource-id $DEVICE_TOKEN_RESOURCE \
  --http-method POST \
  --type AWS_PROXY \
  --integration-http-method POST \
  --uri "arn:aws:apigateway:$REGION:lambda:path/2015-03-31/functions/$LAMBDA_ARN/invocations"

# Grant permission
echo "🔐 Granting API Gateway permission..."
aws lambda add-permission \
  --region $REGION \
  --function-name whizz-merchants-register-device-token \
  --statement-id apigateway-invoke-rest \
  --action lambda:InvokeFunction \
  --principal apigateway.amazonaws.com \
  --source-arn "arn:aws:execute-api:$REGION:$ACCOUNT_ID:$API_ID/*/POST/merchants/*/device-token" \
  2>/dev/null || echo "⚠️  Permission already exists"

# Deploy to stage
echo "🚀 Deploying to ${STAGE} stage..."
aws apigateway create-deployment \
  --rest-api-id $API_ID \
  --region $REGION \
  --stage-name "$STAGE" \
  --description "Added device token endpoint"

echo ""
echo "✅ API route setup complete!"
echo ""
echo "📱 Endpoint URL:"
echo "POST https://$API_ID.execute-api.$REGION.amazonaws.com/$STAGE/merchants/{merchantId}/device-token"
echo ""
