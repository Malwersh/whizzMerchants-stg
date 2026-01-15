#!/bin/zsh
# Monitor DynamoDB for new device token entries
# Usage: ./monitor-tokens.sh [merchantId] [interval_seconds]

MERCHANT_ID="${1:-}"
INTERVAL="${2:-5}"
export AWS_REGION=us-east-1

echo "📱 Monitoring DynamoDB for new device tokens..."
echo "Table: WhizzMerchants_DeviceTokens"
if [ -n "$MERCHANT_ID" ]; then
  echo "Filtering by merchantId: $MERCHANT_ID"
fi
echo "Refresh interval: ${INTERVAL}s"
echo "Press Ctrl+C to stop"
echo ""

while true; do
  clear
  echo "🕐 $(date '+%H:%M:%S') - Checking for tokens..."
  echo ""
  
  if [ -n "$MERCHANT_ID" ]; then
    # Query by merchantId via GSI
    aws dynamodb query \
      --table-name WhizzMerchants_DeviceTokens \
      --index-name MerchantDeviceIndex \
      --key-condition-expression 'merchantId = :m' \
      --expression-attribute-values "{\":m\":{\"S\":\"$MERCHANT_ID\"}}" \
      --output json 2>/dev/null | \
      jq -r '.Items[] | "Token: \(.tokenId.S)\nMerchant: \(.merchantId.S)\nPlatform: \(.platform.S)\nDevice: \(.deviceId.S)\nUpdated: \(.updatedAt.S)\n"' || \
      echo "No tokens found for merchantId: $MERCHANT_ID"
  else
    # Scan recent entries (last 5)
    aws dynamodb scan \
      --table-name WhizzMerchants_DeviceTokens \
      --limit 5 \
      --output json 2>/dev/null | \
      jq -r '.Items[] | "Token: \(.tokenId.S)\nMerchant: \(.merchantId.S)\nPlatform: \(.platform.S)\nDevice: \(.deviceId.S)\nUpdated: \(.updatedAt.S)\n"' || \
      echo "No tokens found"
  fi
  
  echo ""
  echo "⏳ Refreshing in ${INTERVAL}s..."
  sleep "$INTERVAL"
done
