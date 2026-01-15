#!/bin/bash

# Quick Manual Setup - Create resources directly without CloudFormation
# This is faster for testing!

set -e

echo "🚀 Quick Setup: Creating Push Notification Resources Manually..."
echo ""

# 1. Create DynamoDB Table
echo "1️⃣  Creating DynamoDB Table..."
aws dynamodb create-table \
  --table-name WhizzMerchants_DeviceTokens \
  --attribute-definitions \
    AttributeName=tokenId,AttributeType=S \
    AttributeName=merchantId,AttributeType=S \
  --key-schema \
    AttributeName=tokenId,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --global-secondary-indexes \
    "IndexName=MerchantDeviceIndex,KeySchema=[{AttributeName=merchantId,KeyType=HASH}],Projection={ProjectionType=ALL}" \
  --tags \
    Key=Environment,Value=dev \
    Key=Service,Value=WhizzMerchants \
  2>&1 | grep -E "TableName|TableStatus" || echo "Table might already exist"

echo "✅ DynamoDB table created/exists"
echo ""

# 2. Create Lambda execution role
echo "2️⃣  Creating Lambda execution role..."
ROLE_NAME="whizz-merchants-device-token-role"

aws iam create-role \
  --role-name $ROLE_NAME \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": {"Service": "lambda.amazonaws.com"},
      "Action": "sts:AssumeRole"
    }]
  }' 2>&1 | grep -E "RoleName|Arn" || echo "Role might already exist"

# Attach policies
aws iam attach-role-policy \
  --role-name $ROLE_NAME \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole 2>/dev/null || true

# Create inline policy for DynamoDB access
aws iam put-role-policy \
  --role-name $ROLE_NAME \
  --policy-name DeviceTokensDynamoDBAccess \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Action": [
        "dynamodb:PutItem",
        "dynamodb:GetItem",
        "dynamodb:Query",
        "dynamodb:UpdateItem"
      ],
      "Resource": [
        "arn:aws:dynamodb:us-east-1:*:table/WhizzMerchants_DeviceTokens",
        "arn:aws:dynamodb:us-east-1:*:table/WhizzMerchants_DeviceTokens/index/*"
      ]
    }]
  }' 2>/dev/null || true

echo "✅ IAM role created/updated"
echo ""

# Wait for role to propagate
echo "⏳ Waiting 10 seconds for IAM role to propagate..."
sleep 10

# 3. Package Lambda function
echo "3️⃣  Packaging Lambda function..."
cd /Users/ghaythallaheebi/WhizzEcoSystem/whizzEcosystem/whizzMerchants/backend/functions/notifications
npm install --production 2>&1 | tail -2
zip -qr /tmp/device-token-lambda.zip . 

echo "✅ Lambda package created"
echo ""

# 4. Create/Update Lambda function
echo "4️⃣  Creating Lambda function..."
ROLE_ARN=$(aws iam get-role --role-name $ROLE_NAME --query 'Role.Arn' --output text)

aws lambda create-function \
  --function-name whizz-merchants-register-device-token \
  --runtime nodejs20.x \
  --role $ROLE_ARN \
  --handler register-device-token.handler \
  --zip-file fileb:///tmp/device-token-lambda.zip \
  --timeout 29 \
  --memory-size 512 \
  --environment "Variables={DEVICE_TOKENS_TABLE=WhizzMerchants_DeviceTokens}" \
  2>&1 | grep -E "FunctionName|FunctionArn|State" || {
    echo "Function exists, updating..."
    aws lambda update-function-code \
      --function-name whizz-merchants-register-device-token \
      --zip-file fileb:///tmp/device-token-lambda.zip
    aws lambda update-function-configuration \
      --function-name whizz-merchants-register-device-token \
      --environment "Variables={DEVICE_TOKENS_TABLE=WhizzMerchants_DeviceTokens}"
  }

echo "✅ Lambda function created/updated"
echo ""

# 5. Get Lambda ARN for API Gateway integration
LAMBDA_ARN=$(aws lambda get-function --function-name whizz-merchants-register-device-token --query 'Configuration.FunctionArn' --output text)

echo ""
echo "=========================================="
echo "✅ SETUP COMPLETE!"
echo "=========================================="
echo ""
echo "📋 Resources Created:"
echo "  - DynamoDB: WhizzMerchants_DeviceTokens"
echo "  - Lambda: whizz-merchants-register-device-token"
echo "  - IAM Role: $ROLE_NAME"
echo ""
echo "🔗 Lambda ARN:"
echo "  $LAMBDA_ARN"
echo ""
echo "🧪 Test Lambda directly:"
echo 'aws lambda invoke \'
echo '  --function-name whizz-merchants-register-device-token \'
echo '  --payload '"'"'{"pathParameters":{"merchantId":"TEST"},"body":"{\"deviceToken\":\"test123\",\"platform\":\"ios\",\"deviceId\":\"device1\",\"appVersion\":\"1.0.0\"}"}'"'"' \'
echo '  /tmp/lambda-response.json && cat /tmp/lambda-response.json'
echo ""
echo "📝 Next: Add this Lambda to your existing API Gateway"
echo ""
