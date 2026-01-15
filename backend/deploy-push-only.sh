#!/bin/bash

# Deploy ONLY Push Notifications Infrastructure
# Minimal deployment - just DynamoDB table and Lambda function

set -e

echo "🚀 Deploying Push Notifications Infrastructure..."
echo ""

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

STAGE="${STAGE:-staging}"

# Install Lambda dependencies
echo "📦 Installing Lambda dependencies..."
cd functions/notifications
npm install 2>&1 | tail -3
cd ../..

# Build using the push notifications template
echo "🔨 Building SAM application..."
sam build -t template-push-notifications.yaml

# Deploy
echo "☁️  Deploying to AWS CloudFormation..."
sam deploy \
  --template-file .aws-sam/build/template.yaml \
  --stack-name whizz-merchants-push-notifications \
  --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
  --parameter-overrides Stage="$STAGE" \
  --no-fail-on-empty-changeset \
  --resolve-s3 \
  --no-confirm-changeset

echo ""
echo "✅ Deployment Complete!"
echo ""
echo "📋 Resources Created:"
aws cloudformation describe-stacks \
  --stack-name whizz-merchants-push-notifications \
  --query 'Stacks[0].Outputs' \
  --output table

echo ""
echo "🧪 Next Steps:"
echo "  1. Update your main API to call this Lambda function"
echo "  2. Or add API Gateway endpoint to this stack"
echo "  3. Test from Flutter app"
echo ""
