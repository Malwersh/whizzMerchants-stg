#!/bin/zsh
# Query device tokens by merchantId via GSI
# Usage: ./query-device-tokens.sh <MERCHANT_ID> [REGION]

set -e

MERCHANT_ID="$1"
REGION="${2:-${AWS_REGION:-us-east-1}}"

if [ -z "$MERCHANT_ID" ]; then
  echo "Usage: $0 <MERCHANT_ID> [REGION]"
  exit 1
fi

export AWS_REGION="$REGION"
export AWS_DEFAULT_REGION="$REGION"

if ! aws sts get-caller-identity >/dev/null 2>&1; then
  echo "❌ AWS credentials not configured. Run: aws sso login"
  exit 1
fi

OUT=$(aws dynamodb query \
  --table-name WhizzMerchants_DeviceTokens \
  --index-name MerchantDeviceIndex \
  --key-condition-expression 'merchantId = :m' \
  --expression-attribute-values '{":m":{"S":"'"$MERCHANT_ID"'"}}' \
  --output json)

if command -v jq >/dev/null 2>&1; then
  echo "$OUT" | jq '[.Items[] | {
    tokenId:.tokenId.S,
    merchantId:.merchantId.S,
    platform:.platform.S,
    deviceId:.deviceId.S,
    appVersion:(.appVersion.S // "unknown"),
    isActive:(.isActive.BOOL // true),
    createdAt:(.createdAt.S // null),
    updatedAt:(.updatedAt.S // null)
  }]'
else
  echo "$OUT"
fi
