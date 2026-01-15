#!/bin/bash

# Watch for FCM token and automatically send test notification
# This script monitors the Flutter log for the FCM token and sends a test notification

LOG_FILE="/tmp/flutter_fcm_full_log.log"
TOKEN_FILE="/tmp/fcm_token_captured.txt"

echo "👀 Watching for FCM token in: $LOG_FILE"
echo "📱 Will automatically send test notification when token appears"
echo ""

# Clear any previous token
rm -f "$TOKEN_FILE"

# Watch the log file for FCM token
tail -f "$LOG_FILE" 2>/dev/null | while read line; do
  # Look for FCM token patterns
  if echo "$line" | grep -q "🎫 FCM Token"; then
    echo "✅ Found FCM Token line: $line"
    
    # Extract token (after "Token:" or "token:")
    TOKEN=$(echo "$line" | grep -oE '[a-zA-Z0-9_-]{100,}' | head -1)
    
    if [ -n "$TOKEN" ]; then
      echo "🎯 Extracted Token: $TOKEN"
      echo "$TOKEN" > "$TOKEN_FILE"
      
      echo ""
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo "🚀 Sending test notification..."
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      
      cd /Users/ghaythallaheebi/WhizzEcoSystem/whizzEcosystem/whizzMerchants/frontend
      python3 send_test_notification.py "$TOKEN"
      
      echo ""
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo "✅ Test notification sent!"
      echo "📱 Check your iPhone for the notification"
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      
      # Exit after sending
      break
    fi
  fi
done

echo ""
echo "✅ Watch script completed"
