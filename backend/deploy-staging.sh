#!/bin/bash

# Deploy WhizzMerchants Backend to Staging
# - Uses staging profile + real CFN exports (no dev hardcoding)
# - Derives WebSocket API ID from the exported WebSocket URL

set -euo pipefail

REGION="us-east-1"
PROFILE="Wizz_stg_UserApp"
STACK_NAME="Wizz-Merchants-staging"
STAGE="staging"

CENTRAL_PUSH_API_BASE_URL_DEFAULT="https://x066k4dftk.execute-api.us-east-1.amazonaws.com/staging"

CENTRAL_PUSH_API_BASE_URL="${CENTRAL_PUSH_API_BASE_URL:-$CENTRAL_PUSH_API_BASE_URL_DEFAULT}"
CENTRAL_NOTIFICATIONS_INTERNAL_KEY="${CENTRAL_NOTIFICATIONS_INTERNAL_KEY:-${NOTIFICATIONS_INTERNAL_KEY:-}}"

# Optional: load internal key from Secrets Manager to avoid manual copy/paste.
# Default name matches the existing naming convention used for Firebase.
CENTRAL_NOTIFICATIONS_INTERNAL_KEY_SECRET_ID="${CENTRAL_NOTIFICATIONS_INTERNAL_KEY_SECRET_ID:-wizz/${STAGE}/notifications/internal-key}"

get_secret_string() {
  local secret_id="$1"
  aws secretsmanager get-secret-value \
    --secret-id "$secret_id" \
    --region "$REGION" \
    --profile "$PROFILE" \
    --query 'SecretString' \
    --output text 2>/dev/null || true
}

if [[ -z "$CENTRAL_NOTIFICATIONS_INTERNAL_KEY" ]]; then
  candidate="$(get_secret_string "$CENTRAL_NOTIFICATIONS_INTERNAL_KEY_SECRET_ID")"
  if [[ -n "$candidate" && "$candidate" != "None" && "$candidate" != "null" ]]; then
    CENTRAL_NOTIFICATIONS_INTERNAL_KEY="$candidate"
  fi
fi

if [[ -z "$CENTRAL_NOTIFICATIONS_INTERNAL_KEY" ]]; then
  echo "🔐 CENTRAL_NOTIFICATIONS_INTERNAL_KEY is required to call Central Notifications internal send endpoints."
  echo "   Tried Secrets Manager: $CENTRAL_NOTIFICATIONS_INTERNAL_KEY_SECRET_ID"
  echo "   Paste it now (input hidden). Press Enter to confirm."
  read -r -s -p "CENTRAL_NOTIFICATIONS_INTERNAL_KEY: " CENTRAL_NOTIFICATIONS_INTERNAL_KEY
  echo ""
fi

export AWS_PAGER=""

echo "🚀 Starting WhizzMerchants deployment to staging..."

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "❌ Missing required command: $1"
    exit 1
  fi
}

get_export() {
  local export_name="$1"
  aws --profile "$PROFILE" --region "$REGION" cloudformation list-exports \
    --query "Exports[?Name==\
'${export_name}'].Value | [0]" \
    --output text
}

require_cmd aws
require_cmd sam

cd "$(dirname "$0")"
echo "📂 Current directory: $(pwd)"

WIZZUSER_API_BASE_URL="$(get_export 'WizzUser-backend-staging-ApiUrl')"
WIZZUSER_WEBSOCKET_URL="$(get_export 'WizzUser-backend-staging-WebSocketUrl')"
COGNITO_USER_POOL_ID="${MERCHANTS_COGNITO_USER_POOL_ID:-$(get_export 'WizzUser-backend-staging-UserPoolId')}"
COGNITO_CLIENT_ID="${MERCHANTS_COGNITO_CLIENT_ID:-$(get_export 'WizzUser-backend-staging-UserPoolClientId')}"

if [[ -z "$WIZZUSER_API_BASE_URL" || "$WIZZUSER_API_BASE_URL" == "None" ]]; then
  echo "❌ Missing export: WizzUser-backend-staging-ApiUrl"
  exit 1
fi
if [[ -z "$WIZZUSER_WEBSOCKET_URL" || "$WIZZUSER_WEBSOCKET_URL" == "None" ]]; then
  echo "❌ Missing export: WizzUser-backend-staging-WebSocketUrl"
  exit 1
fi
if [[ -z "$COGNITO_USER_POOL_ID" || "$COGNITO_USER_POOL_ID" == "None" ]]; then
  echo "❌ Missing Cognito user pool id. Set MERCHANTS_COGNITO_USER_POOL_ID or ensure CFN export exists."
  exit 1
fi
if [[ -z "$COGNITO_CLIENT_ID" || "$COGNITO_CLIENT_ID" == "None" ]]; then
  echo "❌ Missing Cognito client id. Set MERCHANTS_COGNITO_CLIENT_ID or ensure CFN export exists."
  exit 1
fi

# Derive API ID from: wss://<apiId>.execute-api.<region>.amazonaws.com/<stage>
SHARED_WEBSOCKET_API_ID="$(
  echo "$WIZZUSER_WEBSOCKET_URL" | sed -E 's#^wss://([^./]+)\..*#\1#'
)"
if [[ -z "$SHARED_WEBSOCKET_API_ID" || "$SHARED_WEBSOCKET_API_ID" == "$WIZZUSER_WEBSOCKET_URL" ]]; then
  echo "❌ Failed to derive SharedWebSocketApiId from: $WIZZUSER_WEBSOCKET_URL"
  exit 1
fi

WEBSOCKET_CONNECTIONS_TABLE_NAME="WizzUser_websocket_connections_staging"
WEBSOCKET_SUBSCRIPTIONS_TABLE_NAME="WizzUser_websocket_subscriptions_staging"

PARAM_OVERRIDES=(
  "Stage=\"$STAGE\""
  "WebSocketConnectionsTableName=\"$WEBSOCKET_CONNECTIONS_TABLE_NAME\""
  "WebSocketSubscriptionsTableName=\"$WEBSOCKET_SUBSCRIPTIONS_TABLE_NAME\""
  "WizzUserApiBaseUrl=\"$WIZZUSER_API_BASE_URL\""
  "SharedWebSocketUrl=\"$WIZZUSER_WEBSOCKET_URL\""
  "UserAppWebSocketUrl=\"$WIZZUSER_WEBSOCKET_URL\""
  "BusinessAppWebSocketUrl=\"$WIZZUSER_WEBSOCKET_URL\""
  "SharedWebSocketApiId=\"$SHARED_WEBSOCKET_API_ID\""
  "CognitoUserPoolId=\"$COGNITO_USER_POOL_ID\""
  "CognitoClientId=\"$COGNITO_CLIENT_ID\""
  "CentralPushApiBaseUrl=\"$CENTRAL_PUSH_API_BASE_URL\""
  "CentralNotificationsInternalKey=\"$CENTRAL_NOTIFICATIONS_INTERNAL_KEY\""
  # Optional; leaving empty disables cross-service websocket Lambda invocations.
  "UserWebSocketSendFunctionName=\"${USER_WEBSOCKET_SEND_FUNCTION_NAME:-}\""
  "BusinessWebSocketSendFunctionName=\"${BUSINESS_WEBSOCKET_SEND_FUNCTION_NAME:-}\""
)

if [[ -n "${BUSINESS_PHOTOS_BUCKET_NAME:-}" ]]; then
  PARAM_OVERRIDES+=("BusinessPhotosBucketName=\"$BUSINESS_PHOTOS_BUCKET_NAME\"")
fi

echo "🔎 Validating SAM template..."
sam validate

echo "🔨 Building SAM application..."
sam build

echo "🚀 Deploying stack: $STACK_NAME ($STAGE)"
sam deploy \
  --config-env staging \
  --stack-name "$STACK_NAME" \
  --region "$REGION" \
  --profile "$PROFILE" \
  --capabilities CAPABILITY_IAM \
  --parameter-overrides "${PARAM_OVERRIDES[@]}" \
  --no-confirm-changeset

echo "✅ Deployment completed."