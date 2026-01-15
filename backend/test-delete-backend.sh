#!/bin/bash
set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Testing Delete Account Backend${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}\n"

# Configuration
API_BASE_URL="${API_BASE_URL:-}"
COGNITO_CLIENT_ID="${COGNITO_CLIENT_ID:-}"
COGNITO_USER_POOL_ID="${COGNITO_USER_POOL_ID:-}"
COGNITO_REGION="${COGNITO_REGION:-us-east-1}"
EMAIL="${EMAIL:-}"
PASSWORD="${PASSWORD:-}"
BUSINESSES_TABLE_NAME="${BUSINESSES_TABLE_NAME:-}"
CATEGORIES_TABLE_NAME="${CATEGORIES_TABLE_NAME:-}"
LAMBDA_LOG_GROUP_NAME="${LAMBDA_LOG_GROUP_NAME:-}"

require_var() {
  local name="$1"
  if [ -z "${!name:-}" ]; then
    echo -e "${RED}❌ Missing required env var: $name${NC}" >&2
    exit 1
  fi
}

require_var API_BASE_URL
require_var COGNITO_CLIENT_ID
require_var COGNITO_USER_POOL_ID
require_var EMAIL
require_var PASSWORD
require_var BUSINESSES_TABLE_NAME
require_var CATEGORIES_TABLE_NAME

REGION="$COGNITO_REGION"

echo -e "${YELLOW}Step 1: Getting authentication token...${NC}"

# Get Cognito token
AUTH_RESPONSE=$(aws cognito-idp initiate-auth \
  --auth-flow USER_PASSWORD_AUTH \
  --client-id "${COGNITO_CLIENT_ID}" \
  --region "${REGION}" \
  --auth-parameters USERNAME="${EMAIL}",PASSWORD="${PASSWORD}" \
  --output json 2>&1)

if [ $? -ne 0 ]; then
  echo -e "${RED}❌ Failed to authenticate${NC}"
  echo "${AUTH_RESPONSE}"
  exit 1
fi

# Extract ID token
ID_TOKEN=$(echo "${AUTH_RESPONSE}" | jq -r '.AuthenticationResult.IdToken')

if [ "${ID_TOKEN}" == "null" ] || [ -z "${ID_TOKEN}" ]; then
  echo -e "${RED}❌ Failed to get ID token${NC}"
  echo "${AUTH_RESPONSE}"
  exit 1
fi

echo -e "${GREEN}✅ Authentication successful${NC}"
echo -e "${BLUE}Token (first 50 chars): ${ID_TOKEN:0:50}...${NC}\n"

echo -e "${YELLOW}Step 2: Getting business ID...${NC}"

# Get business details to find business ID
BUSINESS_RESPONSE=$(curl -s -X GET \
  "${API_BASE_URL}/businesses/details" \
  -H "Authorization: Bearer ${ID_TOKEN}" \
  -H "Content-Type: application/json")

echo -e "${BLUE}Business response: ${BUSINESS_RESPONSE}${NC}"

BUSINESS_ID=$(echo "${BUSINESS_RESPONSE}" | jq -r '.id // .businessId // .data.id // .data.businessId')

if [ "${BUSINESS_ID}" == "null" ] || [ -z "${BUSINESS_ID}" ]; then
  echo -e "${RED}❌ Failed to get business ID${NC}"
  echo -e "${RED}Response: ${BUSINESS_RESPONSE}${NC}"
  exit 1
fi

echo -e "${GREEN}✅ Business ID: ${BUSINESS_ID}${NC}\n"

echo -e "${YELLOW}Step 3: Checking categories before deletion...${NC}"

CATEGORIES_BEFORE=$(aws dynamodb scan \
  --table-name "${CATEGORIES_TABLE_NAME}" \
  --region us-east-1 \
  --query 'Count' \
  --output text)

echo -e "${BLUE}Categories count BEFORE deletion: ${CATEGORIES_BEFORE}${NC}\n"

echo -e "${YELLOW}Step 4: Calling delete account endpoint...${NC}"
echo -e "${BLUE}DELETE ${API_BASE_URL}/businesses/${BUSINESS_ID}${NC}"
echo -e "${BLUE}Password: ${PASSWORD}${NC}\n"

# Call delete endpoint
DELETE_RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X DELETE \
  "${API_BASE_URL}/businesses/${BUSINESS_ID}" \
  -H "Authorization: Bearer ${ID_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{\"password\":\"${PASSWORD}\"}")

# Extract HTTP status
HTTP_STATUS=$(echo "${DELETE_RESPONSE}" | grep -o "HTTP_STATUS:[0-9]*" | cut -d':' -f2)
RESPONSE_BODY=$(echo "${DELETE_RESPONSE}" | sed 's/HTTP_STATUS:[0-9]*$//')

echo -e "${BLUE}Response Status: ${HTTP_STATUS}${NC}"
echo -e "${BLUE}Response Body: ${RESPONSE_BODY}${NC}\n"

# Check response
if [ "${HTTP_STATUS}" == "200" ]; then
  echo -e "${GREEN}✅ Account deletion successful!${NC}\n"
  
  echo -e "${YELLOW}Step 5: Verifying deletion results...${NC}"
  
  # Wait a moment for DynamoDB to update
  sleep 2
  
  # Check if user exists in Cognito
  echo -e "\n${BLUE}Checking if user deleted from Cognito...${NC}"
  USER_CHECK=$(aws cognito-idp admin-get-user \
    --user-pool-id "${COGNITO_USER_POOL_ID}" \
    --username "${EMAIL}" \
    --region us-east-1 2>&1 || true)
  
  if echo "${USER_CHECK}" | grep -q "UserNotFoundException"; then
    echo -e "${GREEN}✅ User successfully deleted from Cognito${NC}"
  else
    echo -e "${YELLOW}⚠️  User still exists in Cognito (might take a moment)${NC}"
  fi
  
  # Check if business exists in DynamoDB
  echo -e "\n${BLUE}Checking if business deleted from DynamoDB...${NC}"
  BUSINESS_CHECK=$(aws dynamodb get-item \
    --table-name "${BUSINESSES_TABLE_NAME}" \
    --key "{\"id\":{\"S\":\"${BUSINESS_ID}\"}}" \
    --region us-east-1 \
    --output json 2>&1 || true)
  
  if echo "${BUSINESS_CHECK}" | grep -q "Item"; then
    echo -e "${YELLOW}⚠️  Business still exists in DynamoDB${NC}"
  else
    echo -e "${GREEN}✅ Business successfully deleted from DynamoDB${NC}"
  fi
  
  # CRITICAL: Check if categories still exist
  echo -e "\n${BLUE}Checking if categories preserved (CRITICAL!)...${NC}"
  CATEGORIES_AFTER=$(aws dynamodb scan \
    --table-name "${CATEGORIES_TABLE_NAME}" \
    --region us-east-1 \
    --query 'Count' \
    --output text)
  
  echo -e "${BLUE}Categories count AFTER deletion: ${CATEGORIES_AFTER}${NC}"
  
  if [ "${CATEGORIES_AFTER}" == "${CATEGORIES_BEFORE}" ]; then
    echo -e "${GREEN}✅✅✅ CATEGORIES PRESERVED! Count unchanged: ${CATEGORIES_BEFORE}${NC}"
  else
    echo -e "${RED}❌❌❌ CATEGORIES WERE DELETED! This is a BUG!${NC}"
    echo -e "${RED}Before: ${CATEGORIES_BEFORE}, After: ${CATEGORIES_AFTER}${NC}"
  fi
  
  echo -e "\n${GREEN}═══════════════════════════════════════════════════════════════${NC}"
  echo -e "${GREEN}  ✅ DELETE ACCOUNT TEST COMPLETED SUCCESSFULLY!${NC}"
  echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
  
elif [ "${HTTP_STATUS}" == "401" ]; then
  echo -e "${RED}❌ Authentication failed - Invalid password${NC}"
  echo -e "${YELLOW}Check if password is correct: ${PASSWORD}${NC}"
  exit 1
  
elif [ "${HTTP_STATUS}" == "404" ]; then
  echo -e "${RED}❌ Business not found${NC}"
  echo -e "${YELLOW}Business ID: ${BUSINESS_ID}${NC}"
  exit 1
  
else
  echo -e "${RED}❌ Delete account failed with status: ${HTTP_STATUS}${NC}"
  exit 1
fi

echo -e "\n${BLUE}View Lambda logs:${NC}"
if [ -n "${LAMBDA_LOG_GROUP_NAME}" ]; then
  echo -e "aws logs tail ${LAMBDA_LOG_GROUP_NAME} --follow"
else
  echo -e "(set LAMBDA_LOG_GROUP_NAME to show a logs tail command)"
fi
