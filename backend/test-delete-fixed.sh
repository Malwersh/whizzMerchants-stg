#!/bin/bash
set -euo pipefail
echo "==================================================================="
echo "  Testing Delete Account - Backend Direct Test"
echo "==================================================================="
echo ""

require_var() {
  local name="$1"
  if [ -z "${!name:-}" ]; then
    echo "❌ Missing required env var: $name" >&2
    exit 1
  fi
}

# Required configuration
API_BASE_URL="${API_BASE_URL:-}"
COGNITO_CLIENT_ID="${COGNITO_CLIENT_ID:-}"
COGNITO_USER_POOL_ID="${COGNITO_USER_POOL_ID:-}"
COGNITO_REGION="${COGNITO_REGION:-us-east-1}"
EMAIL="${EMAIL:-}"
PASSWORD="${PASSWORD:-}"
BUSINESSES_TABLE_NAME="${BUSINESSES_TABLE_NAME:-}"
CATEGORIES_TABLE_NAME="${CATEGORIES_TABLE_NAME:-}"
LAMBDA_LOG_GROUP_NAME="${LAMBDA_LOG_GROUP_NAME:-}"

require_var API_BASE_URL
require_var COGNITO_CLIENT_ID
require_var COGNITO_USER_POOL_ID
require_var EMAIL
require_var PASSWORD
require_var BUSINESSES_TABLE_NAME
require_var CATEGORIES_TABLE_NAME

# Get auth token
echo "1. Getting Cognito token..."
TOKEN=$(aws cognito-idp initiate-auth \
  --auth-flow USER_PASSWORD_AUTH \
  --client-id "$COGNITO_CLIENT_ID" \
  --region "$COGNITO_REGION" \
  --auth-parameters USERNAME="$EMAIL",PASSWORD="$PASSWORD" \
  --query 'AuthenticationResult.IdToken' \
  --output text)

echo "✅ Token obtained"
echo ""

# Get user ID from Cognito token (it's in the sub claim)
USER_ID=$(echo $TOKEN | jq -R 'split(".") | .[1] | @base64d | fromjson | .sub' -r)
echo "2. User ID from token: ${USER_ID}"
echo ""

# Query businesses table by userId
echo "3. Getting business ID from DynamoDB..."
BUSINESS_DATA=$(aws dynamodb query \
  --table-name "$BUSINESSES_TABLE_NAME" \
  --index-name userId-index \
  --key-condition-expression "userId = :userId" \
  --expression-attribute-values '{":userId":{"S":"'${USER_ID}'"}}' \
  --region us-east-1 \
  --output json)

BUSINESS_ID=$(echo $BUSINESS_DATA | jq -r '.Items[0].id.S')
echo "✅ Business ID: ${BUSINESS_ID}"
echo ""

# Check categories before
echo "4. Categories count BEFORE deletion..."
BEFORE=$(aws dynamodb scan --table-name "$CATEGORIES_TABLE_NAME" --region us-east-1 --query 'Count' --output text)
echo "   Count: ${BEFORE}"
echo ""

# Delete account
echo "5. Calling DELETE /businesses/${BUSINESS_ID}..."
DELETE_RESPONSE=$(curl -s -X DELETE \
  "$API_BASE_URL/businesses/${BUSINESS_ID}" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{\"password\":\"${PASSWORD}\"}")

echo "   Response: ${DELETE_RESPONSE}"
echo ""

# Check categories after
echo "6. Categories count AFTER deletion..."
sleep 2
AFTER=$(aws dynamodb scan --table-name WhizzMerchants_Categories --region us-east-1 --query 'Count' --output text)
AFTER=$(aws dynamodb scan --table-name "$CATEGORIES_TABLE_NAME" --region us-east-1 --query 'Count' --output text)
echo "   Count: ${AFTER}"
echo ""

# Result
if [ "${BEFORE}" == "${AFTER}" ]; then
  echo "==================================================================="
  echo "  ✅ SUCCESS: Categories preserved! (${BEFORE} -> ${AFTER})"
  echo "==================================================================="
else
  echo "==================================================================="
  echo "  ❌ FAIL: Categories deleted! (${BEFORE} -> ${AFTER})"
  echo "==================================================================="
fi

# Check if user was deleted from Cognito
echo ""
echo "7. Verifying user deleted from Cognito..."
USER_CHECK=$(aws cognito-idp admin-get-user \
  --user-pool-id "$COGNITO_USER_POOL_ID" \
  --username "$EMAIL" \
  --region "$COGNITO_REGION" 2>&1 || echo "USER_NOT_FOUND")

if echo "${USER_CHECK}" | grep -q "UserNotFoundException\|USER_NOT_FOUND"; then
  echo "   ✅ User deleted from Cognito"
else
  echo "   ⚠️  User still exists in Cognito"
fi

echo ""
echo "View Lambda logs:"
if [ -n "${LAMBDA_LOG_GROUP_NAME}" ]; then
  echo "aws logs tail ${LAMBDA_LOG_GROUP_NAME} --follow"
else
  echo "(set LAMBDA_LOG_GROUP_NAME to show a logs tail command)"
fi
