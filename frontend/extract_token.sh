#!/bin/bash

# Extract FCM Token from Flutter logs
# Run this in a separate terminal while the app is running

echo "🔍 Monitoring Flutter logs for FCM token..."
echo "Keep this running while the app launches..."
echo ""

# Watch for FCM token in real-time
tail -f /tmp/flutter_run.log 2>/dev/null | grep --line-buffered -i "FCM Token" | while read line; do
  echo "=========================================="
  echo "✅ TOKEN FOUND!"
  echo "=========================================="
  echo "$line"
  echo "=========================================="
  
  # Try to extract just the token
  TOKEN=$(echo "$line" | grep -oE '[a-zA-Z0-9_-]{140,}')
  if [ ! -z "$TOKEN" ]; then
    echo ""
    echo "📋 Token extracted:"
    echo "$TOKEN"
    echo ""
    echo "$TOKEN" > /tmp/fcm_token.txt
    echo "✅ Saved to /tmp/fcm_token.txt"
    echo ""
    echo "🚀 Send test push:"
    echo "cd /Users/ghaythallaheebi/WhizzEcoSystem/whizzEcosystem/whizzMerchants/frontend"
    echo "python3 send_test_notification.py \"$TOKEN\""
  fi
done
