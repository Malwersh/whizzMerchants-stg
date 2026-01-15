#!/bin/zsh
# Post a device token to the API Gateway endpoint (Cognito-protected)
# Usage: ./post-device-token.sh <API_BASE_URL> <MERCHANT_ID> <JWT> <FCM_TOKEN> [ios|android] [deviceId] [appVersion] [isActive]

set -e

API_BASE="$1"
MERCHANT_ID="$2"
JWT="$3"
FCM_TOKEN="$4"
PLATFORM="${5:-ios}"
DEVICE_ID="${6:-test-device}"
APP_VERSION="${7:-1.0.0}"
IS_ACTIVE="${8:-true}"

if [ -z "$API_BASE" ] || [ -z "$MERCHANT_ID" ] || [ -z "$JWT" ] || [ -z "$FCM_TOKEN" ]; then
  echo "Usage: $0 <API_BASE_URL> <MERCHANT_ID> <JWT> <FCM_TOKEN> [ios|android] [deviceId] [appVersion] [isActive]"
  echo "Example API_BASE_URL: https://abcdef.execute-api.us-east-1.amazonaws.com/staging"
  exit 1
fi

URL="${API_BASE%/}/merchants/${MERCHANT_ID}/device-token"

BODY=$(jq -n \
  --arg t "$FCM_TOKEN" \
  --arg p "$PLATFORM" \
  --arg d "$DEVICE_ID" \
  --arg v "$APP_VERSION" \
  --argjson a "$IS_ACTIVE" '{deviceToken:$t, platform:$p, deviceId:$d, appVersion:$v, isActive:$a}')

echo "POST $URL"

HTTP_STATUS=$(curl -sS -o /tmp/post_device_token_resp.json -w "%{http_code}" \
  -X POST "$URL" \
  -H "Authorization: Bearer $JWT" \
  -H "Content-Type: application/json" \
  --data "$BODY")

echo "HTTP $HTTP_STATUS"
if command -v jq >/dev/null 2>&1; then
  jq '.' /tmp/post_device_token_resp.json || cat /tmp/post_device_token_resp.json
else
  cat /tmp/post_device_token_resp.json
fi
