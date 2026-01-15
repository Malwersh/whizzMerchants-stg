#!/bin/bash

# Monitor iOS device logs for FCM token in real-time
# Run this while the app is running on your iPhone

echo "🔍 Monitoring iPhone device logs for FCM token..."
echo "Press Ctrl+C to stop"
echo ""

log stream --predicate 'processImagePath contains "Runner"' --level debug 2>/dev/null | \
  grep --line-buffered -E "FCM Token|Firebase|device token" | \
  while read line; do
    echo "$line"
    
    # Check if this line contains the token
    if echo "$line" | grep -q "FCM Token"; then
      TOKEN=$(echo "$line" | grep -oE '[a-zA-Z0-9_-]{140,}')
      if [ ! -z "$TOKEN" ]; then
        echo ""
        echo "=========================================="
        echo "✅ FCM TOKEN CAPTURED!"
        echo "=========================================="
        echo "$TOKEN"
        echo "=========================================="
        echo ""
        echo "$TOKEN" > /tmp/fcm_token.txt
        echo "✅ Saved to /tmp/fcm_token.txt"
        echo ""
        echo "🚀 Send test push with:"
        echo "cd /Users/ghaythallaheebi/WhizzEcoSystem/whizzEcosystem/whizzMerchants/frontend"
        echo "python3 send_test_notification.py \"$TOKEN\""
        echo ""
      fi
    fi
  done
