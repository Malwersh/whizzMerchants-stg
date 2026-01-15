#!/bin/bash

# Deploy Device Token Infrastructure to Whizz Merchants Backend
# Deploys to a SEPARATE stack for push notifications infrastructure

set -e

echo "🚀 Deploying Device Token Infrastructure (Separate Stack)..."
echo ""

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

STAGE="${STAGE:-staging}"

# Install Lambda dependencies
echo "📦 Installing Lambda dependencies..."
cd functions/notifications
npm install
cd ../..

# Build SAM template
echo "🔨 Building SAM application..."
sam build

# Deploy to NEW separate stack
echo "☁️  Deploying to AWS (new stack: whizz-merchants-push-notifications)..."
sam deploy \
  --stack-name whizz-merchants-push-notifications \
  --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
  --parameter-overrides Stage="$STAGE" \
  --no-fail-on-empty-changeset \
  --resolve-s3

echo ""
echo "✅ Deployment Complete!"
echo ""
echo "📋 Resources Created in Stack: whizz-merchants-push-notifications"
echo "  - DynamoDB Table: WhizzMerchants_DeviceTokens"
echo "  - Lambda Function: (depends on template + Stage parameter)"
echo "  - API Gateway: Regional API with push notification endpoints"
echo ""
echo "📝 Get your API endpoint:"
echo "  aws cloudformation describe-stacks --stack-name whizz-merchants-push-notifications --query 'Stacks[0].Outputs[?OutputKey==\`ApiGatewayEndpoint\`].OutputValue' --output text"
echo ""
echo "🧪 Test the endpoint:"
echo "  curl -X POST https://YOUR_API_URL/$STAGE/merchants/TEST_MERCHANT/device-token \\\n     -H \"Authorization: Bearer YOUR_TOKEN\" \\\n     -H \"Content-Type: application/json\" \\\n     -d '"'"'{"deviceToken":"test-token","platform":"ios","deviceId":"test-device","appVersion":"1.0.0"}'"'"''"
echo '    -H "Authorization: Bearer YOUR_TOKEN" \'
echo '    -H "Content-Type: application/json" \'
echo '    -d '"'"'{"deviceToken":"test-token","platform":"ios","deviceId":"test-device","appVersion":"1.0.0"}'"'"
echo ""
