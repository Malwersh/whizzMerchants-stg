#!/bin/bash
set -euo pipefail

echo "Testing Delete Account Backend"
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
COGNITO_REGION="${COGNITO_REGION:-us-east-1}"
EMAIL="${EMAIL:-}"
PASSWORD="${PASSWORD:-}"

require_var API_BASE_URL
require_var COGNITO_CLIENT_ID
require_var EMAIL
require_var PASSWORD

# Step 1: Authenticate with Cognito
echo "Step 1: Getting auth token..."
aws cognito-idp initiate-auth \
  --auth-flow USER_PASSWORD_AUTH \
  --client-id "$COGNITO_CLIENT_ID" \
  --region "$COGNITO_REGION" \
  --auth-parameters USERNAME="$EMAIL",PASSWORD="$PASSWORD" \
  --query 'AuthenticationResult.IdToken' \
  --output text > /tmp/token.txt

TOKEN=$(cat /tmp/token.txt)
echo "Token obtained (first 40 chars): ${TOKEN:0:40}..."
echo ""

# Step 2: Get business ID
echo "Step 2: Getting business details..."
curl -s "$API_BASE_URL/businesses/details" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" > /tmp/business.json

cat /tmp/business.json
echo ""

BUSINESS_ID=$(cat /tmp/business.json | jq -r '.id // .businessId // .data.id')
echo "Business ID: ${BUSINESS_ID}"
echo ""

# Step 3: Check categories before
echo "Step 3: Checking categories count BEFORE deletion..."
BEFORE=$(aws dynamodb scan --table-name WhizzMerchants_Categories --region us-east-1 --query 'Count' --output text)
echo "Categories BEFORE: ${BEFORE}"
echo ""

# Step 4: Delete account
echo "Step 4: Calling DELETE endpoint..."
echo "URL: $API_BASE_URL/businesses/${BUSINESS_ID}"
echo ""

curl -v -X DELETE \
  "$API_BASE_URL/businesses/${BUSINESS_ID}" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{\"password\":\"${PASSWORD}\"}" 2>&1 | tee /tmp/delete_response.txt

echo ""
echo ""

# Step 5: Check categories after
echo "Step 5: Checking categories count AFTER deletion..."
sleep 2
AFTER=$(aws dynamodb scan --table-name WhizzMerchants_Categories --region us-east-1 --query 'Count' --output text)
echo "Categories AFTER: ${AFTER}"
echo ""

if [ "${BEFORE}" == "${AFTER}" ]; then
  echo "✅ SUCCESS: Categories preserved! (${BEFORE} -> ${AFTER})"
else
  echo "❌ FAIL: Categories deleted! (${BEFORE} -> ${AFTER})"
fi

echo ""
echo "Test complete!"
