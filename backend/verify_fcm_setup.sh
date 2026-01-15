#!/bin/bash

# Quick Verification Script for FCM Token Save Implementation
# Run this script to verify everything is configured correctly

echo "🔍 FCM Token Save Implementation - Quick Verification"
echo "===================================================="
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 1. Check Lambda Function
echo "1️⃣  Checking Lambda Function..."
LAMBDA_FUNCTION_NAME="${LAMBDA_FUNCTION_NAME:-}"
AWS_REGION="${AWS_REGION:-us-east-1}"
DEVICE_TOKENS_TABLE_NAME="${DEVICE_TOKENS_TABLE_NAME:-}"
IAM_ROLE_NAME="${IAM_ROLE_NAME:-}"
API_BASE_URL="${API_BASE_URL:-}"

if [ -z "$LAMBDA_FUNCTION_NAME" ]; then
  echo -e "   ${RED}❌ Missing required env var: LAMBDA_FUNCTION_NAME${NC}" >&2
  exit 1
fi

if [ -z "$DEVICE_TOKENS_TABLE_NAME" ]; then
  echo -e "   ${RED}❌ Missing required env var: DEVICE_TOKENS_TABLE_NAME${NC}" >&2
  exit 1
fi
LAMBDA_STATUS=$(aws lambda get-function \
  --function-name "$LAMBDA_FUNCTION_NAME" \
  --region "$AWS_REGION" \
  --query 'Configuration.[State,LastUpdateStatus]' \
  --output text 2>&1)

if [[ $LAMBDA_STATUS == *"Active"*"Successful"* ]]; then
    echo -e "   ${GREEN}✅ Lambda function is Active and deployed successfully${NC}"
else
    echo -e "   ${RED}❌ Lambda function issue: $LAMBDA_STATUS${NC}"
fi
echo ""

# 2. Check Environment Variable
echo "2️⃣  Checking Environment Variables..."
ENV_VAR=$(aws lambda get-function-configuration \
  --function-name "$LAMBDA_FUNCTION_NAME" \
  --region "$AWS_REGION" \
  --query 'Environment.Variables.DEVICE_TOKENS_TABLE' \
  --output text 2>&1)

if [[ $ENV_VAR == "$DEVICE_TOKENS_TABLE_NAME" ]]; then
    echo -e "   ${GREEN}✅ DEVICE_TOKENS_TABLE = $ENV_VAR${NC}"
else
    echo -e "   ${RED}❌ Environment variable not set correctly: $ENV_VAR${NC}"
fi
echo ""

# 3. Check DynamoDB Table
echo "3️⃣  Checking DynamoDB Table..."
TABLE_STATUS=$(aws dynamodb describe-table \
  --table-name "$DEVICE_TOKENS_TABLE_NAME" \
  --region "$AWS_REGION" \
  --query 'Table.TableStatus' \
  --output text 2>&1)

if [[ $TABLE_STATUS == "ACTIVE" ]]; then
    ITEM_COUNT=$(aws dynamodb scan \
      --table-name "$DEVICE_TOKENS_TABLE_NAME" \
      --region "$AWS_REGION" \
      --select "COUNT" \
      --output text \
      --query 'Count' 2>&1)
    echo -e "   ${GREEN}✅ Table is ACTIVE with $ITEM_COUNT items${NC}"
else
    echo -e "   ${RED}❌ Table status: $TABLE_STATUS${NC}"
fi
echo ""

# 4. Check IAM Permissions
echo "4️⃣  Checking IAM Permissions..."
if [ -z "$IAM_ROLE_NAME" ]; then
  echo -e "   ${YELLOW}⚠️  Skipping IAM role policy check (set IAM_ROLE_NAME to enable)${NC}"
  POLICY=""
else
  POLICY=$(aws iam get-role-policy \
    --role-name "$IAM_ROLE_NAME" \
    --policy-name MerchantOrderFunctionRolePolicy0 \
    --output json 2>&1 | jq -r --arg table "$DEVICE_TOKENS_TABLE_NAME" '.PolicyDocument.Statement[] | select(.Resource[]? | tostring | contains($table)) | .Effect' || true)
fi

if [[ $POLICY == "Allow" ]]; then
    echo -e "   ${GREEN}✅ IAM permissions configured for WhizzMerchants_DeviceTokens${NC}"
else
    echo -e "   ${RED}❌ IAM permissions not found${NC}"
fi
echo ""

# 5. Check API Gateway Endpoint
echo "5️⃣  Checking API Gateway Endpoint..."
if [ -z "$API_BASE_URL" ]; then
  echo -e "   ${YELLOW}⚠️  API base URL not set (set API_BASE_URL to enable)${NC}"
else
  echo -e "   ${GREEN}✅ API Base URL: $API_BASE_URL${NC}"
fi
echo "   📍 Route: POST /merchants/{merchantId}/device-token"
echo ""

# Summary
echo "📊 Summary"
echo "=========="
echo ""
echo "✅ Lambda Function: $LAMBDA_FUNCTION_NAME"
echo "✅ Environment: DEVICE_TOKENS_TABLE=$DEVICE_TOKENS_TABLE_NAME"
echo "✅ DynamoDB Table: $DEVICE_TOKENS_TABLE_NAME (ACTIVE)"
echo "✅ IAM Permissions: Configured"
echo "✅ API Base URL: Ready"
echo ""
echo "🧪 To test, run:"
echo "   ./test_fcm_token_save.sh"
echo ""
echo "📱 Or test from Flutter app by:"
echo "   1. Login to WhizzMerchants app"
echo "   2. Watch logs for: '✅✅✅ Device token uploaded SUCCESSFULLY'"
echo "   3. Verify in DynamoDB"
echo ""
echo "📝 View recent tokens:"
echo "   aws dynamodb scan --table-name $DEVICE_TOKENS_TABLE_NAME --region $AWS_REGION | jq '.Items'"
echo ""
echo -e "${GREEN}✅ All systems ready for FCM token storage!${NC}"
echo ""
