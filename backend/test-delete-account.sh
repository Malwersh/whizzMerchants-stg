#!/bin/bash
set -euo pipefail

# Test Delete Account Feature - Quick Verification Script
# This script performs automated checks on the deployed Delete Account feature

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Delete Account Feature Test Suite${NC}"
echo -e "${BLUE}========================================${NC}\n"

# Configuration
STAGE="${STAGE:-staging}"
STACK_NAME="${STACK_NAME:-whizz-merchants-delete-account-${STAGE}}"
REGION="${AWS_REGION:-us-east-1}"
LAMBDA_NAME="${LAMBDA_NAME:-whizz-merchants-delete-account-${STAGE}}"
USER_POOL_ID="${COGNITO_USER_POOL_ID:-}"
CATEGORIES_TABLE_NAME="${CATEGORIES_TABLE_NAME:-WhizzMerchants_Categories}"

require_var() {
  local name="$1"
  if [ -z "${!name:-}" ]; then
    echo -e "${RED}❌ Missing required env var: $name${NC}" >&2
    exit 1
  fi
}

require_var COGNITO_USER_POOL_ID

# Test 1: Check Stack Status
echo -e "${YELLOW}Test 1: Checking CloudFormation Stack...${NC}"
STACK_STATUS=$(aws cloudformation describe-stacks \
  --stack-name "${STACK_NAME}" \
  --region "${REGION}" \
  --query 'Stacks[0].StackStatus' \
  --output text 2>/dev/null)

if [ "$STACK_STATUS" == "CREATE_COMPLETE" ] || [ "$STACK_STATUS" == "UPDATE_COMPLETE" ]; then
  echo -e "${GREEN}✅ Stack Status: ${STACK_STATUS}${NC}"
else
  echo -e "${RED}❌ Stack Status: ${STACK_STATUS}${NC}"
  exit 1
fi

# Test 2: Check Lambda Function
echo -e "\n${YELLOW}Test 2: Checking Lambda Function...${NC}"
LAMBDA_STATE=$(aws lambda get-function \
  --function-name "${LAMBDA_NAME}" \
  --region "${REGION}" \
  --query 'Configuration.State' \
  --output text 2>/dev/null)

if [ "$LAMBDA_STATE" == "Active" ]; then
  echo -e "${GREEN}✅ Lambda Function: Active${NC}"
else
  echo -e "${RED}❌ Lambda Function: ${LAMBDA_STATE}${NC}"
  exit 1
fi

# Test 3: Check Lambda Runtime
LAMBDA_RUNTIME=$(aws lambda get-function \
  --function-name "${LAMBDA_NAME}" \
  --region "${REGION}" \
  --query 'Configuration.Runtime' \
  --output text 2>/dev/null)

if [ "$LAMBDA_RUNTIME" == "nodejs20.x" ]; then
  echo -e "${GREEN}✅ Lambda Runtime: ${LAMBDA_RUNTIME}${NC}"
else
  echo -e "${YELLOW}⚠️  Lambda Runtime: ${LAMBDA_RUNTIME} (expected nodejs20.x)${NC}"
fi

# Test 4: Check API Gateway
echo -e "\n${YELLOW}Test 3: Checking API Gateway...${NC}"
API_ID=$(aws cloudformation describe-stacks \
  --stack-name "${STACK_NAME}" \
  --region "${REGION}" \
  --query 'Stacks[0].Outputs[?OutputKey==`ApiId`].OutputValue' \
  --output text 2>/dev/null)

if [ -n "$API_ID" ]; then
  echo -e "${GREEN}✅ API Gateway ID: ${API_ID}${NC}"
  
  API_URL=$(aws cloudformation describe-stacks \
    --stack-name "${STACK_NAME}" \
    --region "${REGION}" \
    --query 'Stacks[0].Outputs[?OutputKey==`DeleteAccountApiUrl`].OutputValue' \
    --output text 2>/dev/null)
  
  echo -e "${GREEN}✅ API Endpoint: ${API_URL}${NC}"
else
  echo -e "${RED}❌ API Gateway not found${NC}"
  exit 1
fi

# Test 5: Check IAM Permissions
echo -e "\n${YELLOW}Test 4: Checking IAM Role...${NC}"
ROLE_ARN=$(aws lambda get-function \
  --function-name "${LAMBDA_NAME}" \
  --region "${REGION}" \
  --query 'Configuration.Role' \
  --output text 2>/dev/null)

if [ -n "$ROLE_ARN" ]; then
  echo -e "${GREEN}✅ IAM Role exists: ${ROLE_ARN}${NC}"
else
  echo -e "${RED}❌ IAM Role not found${NC}"
  exit 1
fi

# Test 6: Check DynamoDB Tables
echo -e "\n${YELLOW}Test 5: Checking DynamoDB Tables...${NC}"
TABLES=(
  "WhizzMerchants_Users"
  "WhizzMerchants_Businesses"
  "WhizzMerchants_Products"
  "WhizzMerchants_Categories"
  "WhizzMerchants_Discounts"
  "WhizzMerchants_BusinessSettings"
  "WhizzMerchants_BusinessWorkingHours"
)

ALL_TABLES_EXIST=true
for TABLE in "${TABLES[@]}"; do
  TABLE_STATUS=$(aws dynamodb describe-table \
    --table-name "$TABLE" \
    --region "${REGION}" \
    --query 'Table.TableStatus' \
    --output text 2>/dev/null)
  
  if [ "$TABLE_STATUS" == "ACTIVE" ]; then
    echo -e "${GREEN}  ✅ ${TABLE}: Active${NC}"
  else
    echo -e "${RED}  ❌ ${TABLE}: Not found or inactive${NC}"
    ALL_TABLES_EXIST=false
  fi
done

if [ "$ALL_TABLES_EXIST" = false ]; then
  echo -e "${RED}❌ Some DynamoDB tables are missing${NC}"
  exit 1
fi

# Test 7: Check Cognito User Pool
echo -e "\n${YELLOW}Test 6: Checking Cognito User Pool...${NC}"
USER_POOL_STATUS=$(aws cognito-idp describe-user-pool \
  --user-pool-id "${USER_POOL_ID}" \
  --region "${REGION}" \
  --query 'UserPool.Status' \
  --output text 2>/dev/null)

if [ "$USER_POOL_STATUS" == "Enabled" ]; then
  echo -e "${GREEN}✅ Cognito User Pool: Enabled${NC}"
else
  echo -e "${RED}❌ Cognito User Pool: ${USER_POOL_STATUS}${NC}"
  exit 1
fi

# Test 8: Check Lambda Logs
echo -e "\n${YELLOW}Test 7: Checking Lambda Logs...${NC}"
LOG_GROUP="/aws/lambda/${LAMBDA_NAME}"
LOG_GROUP_EXISTS=$(aws logs describe-log-groups \
  --log-group-name-prefix "${LOG_GROUP}" \
  --region "${REGION}" \
  --query 'logGroups[0].logGroupName' \
  --output text 2>/dev/null)

if [ "$LOG_GROUP_EXISTS" == "$LOG_GROUP" ]; then
  echo -e "${GREEN}✅ CloudWatch Log Group exists${NC}"
  
  # Check for recent log streams
  RECENT_LOGS=$(aws logs describe-log-streams \
    --log-group-name "${LOG_GROUP}" \
    --region "${REGION}" \
    --order-by LastEventTime \
    --descending \
    --max-items 1 \
    --query 'logStreams[0].lastEventTime' \
    --output text 2>/dev/null)
  
  if [ -n "$RECENT_LOGS" ] && [ "$RECENT_LOGS" != "None" ]; then
    echo -e "${GREEN}✅ Recent logs available${NC}"
  else
    echo -e "${YELLOW}⚠️  No recent invocations (expected if not tested yet)${NC}"
  fi
else
  echo -e "${YELLOW}⚠️  Log group will be created on first invocation${NC}"
fi

# Test 9: Verify Backend Code
echo -e "\n${YELLOW}Test 8: Verifying Backend Code...${NC}"
CODE_FILE="$(cd "$(dirname "$0")" && pwd)/functions/business/delete_business_handler.js"

if [ -f "$CODE_FILE" ]; then
  echo -e "${GREEN}✅ Handler file exists${NC}"
  
  # Check for password verification
  if grep -q "verifyUserPassword" "$CODE_FILE"; then
    echo -e "${GREEN}✅ Password verification code present${NC}"
  else
    echo -e "${RED}❌ Password verification code missing${NC}"
    exit 1
  fi
  
  # Check for category skip logic
  if grep -q "Skipping categories" "$CODE_FILE"; then
    echo -e "${GREEN}✅ Category preservation code present${NC}"
  else
    echo -e "${RED}❌ Category preservation code missing${NC}"
    exit 1
  fi
else
  echo -e "${RED}❌ Handler file not found${NC}"
  exit 1
fi

# Test 10: Check Categories Table (Pre-test baseline)
echo -e "\n${YELLOW}Test 9: Checking Categories Baseline...${NC}"
CATEGORY_COUNT=$(aws dynamodb scan \
  --table-name "$CATEGORIES_TABLE_NAME" \
  --region "${REGION}" \
  --select COUNT \
  --query 'Count' \
  --output text 2>/dev/null)

if [ -n "$CATEGORY_COUNT" ]; then
  echo -e "${GREEN}✅ Categories Table: ${CATEGORY_COUNT} items${NC}"
  echo -e "${BLUE}   (Note this count before testing - should NOT decrease after deletion)${NC}"
else
  echo -e "${YELLOW}⚠️  Could not count categories${NC}"
fi

# Summary
echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}         Test Results Summary${NC}"
echo -e "${BLUE}========================================${NC}\n"

echo -e "${GREEN}All automated checks passed! ✅${NC}\n"

echo -e "${YELLOW}Next Steps:${NC}"
echo -e "1. Test manually with a test account (do not commit credentials)"
echo -e "2. Verify password verification works"
echo -e "3. Confirm account deletion completes"
echo -e "4. VERIFY categories count remains: ${CATEGORY_COUNT}"
echo -e "5. Check CloudWatch logs for execution details\n"

echo -e "${YELLOW}Monitor logs during testing:${NC}"
echo -e "aws logs tail /aws/lambda/${LAMBDA_NAME} --follow\n"

echo -e "${YELLOW}API Endpoint:${NC}"
echo -e "DELETE ${API_URL}/businesses/{businessId}\n"

echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}Ready for Manual Testing! 🚀${NC}"
echo -e "${BLUE}========================================${NC}\n"
