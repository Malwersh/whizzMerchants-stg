#!/bin/bash

# Monitor for FCM token in the log file and automatically send test notification

LOG_FILE="/tmp/flutter_fcm_debug.log"
TOKEN_FILE="/tmp/fcm_token.txt"

echo "🔍 Monitoring for FCM token in $LOG_FILE..."
echo "Press Ctrl+C to stop"
echo ""

# Clear previous token
rm -f "$TOKEN_FILE"

# Monitor the log file
tail -f "$LOG_FILE" 2>/dev/null | while read -r line; do
  # Look for FCM token patterns
  if echo "$line" | grep -q "FCM Token"; then
    echo "✅ Found FCM token line: $line"
    
    # Extract token (look for long alphanumeric strings)
    TOKEN=$(echo "$line" | grep -oE '[a-zA-Z0-9_-]{140,}' | head -1)
    
    if [ -n "$TOKEN" ]; then
      echo ""
      echo "🎉 FCM TOKEN FOUND!"
      echo "Token: $TOKEN"
      echo ""
      echo "$TOKEN" > "$TOKEN_FILE"
      echo "✅ Token saved to $TOKEN_FILE"
      echo ""
      echo "📤 Sending test notification..."
      python3 send_test_notification.py "$TOKEN"
      echo ""
      echo "✅ Test notification sent!"
      echo ""
      echo "Check your iPhone for the notification 📱"
      break
    fi
  fi
  
  # Also look for the Firebase registration token pattern
  if echo "$line" | grep -q "Firebase registration token"; then
    echo "✅ Found Firebase registration token line: $line"
    TOKEN=$(echo "$line" | grep -oE '[a-zA-Z0-9_-]{140,}' | head -1)
    
    if [ -n "$TOKEN" ]; then
      echo ""
      echo "🎉 FCM TOKEN FOUND!"
      echo "Token: $TOKEN"
      echo ""
      echo "$TOKEN" > "$TOKEN_FILE"
      echo "✅ Token saved to $TOKEN_FILE"
      echo ""
      echo "📤 Sending test notification..."
      python3 send_test_notification.py "$TOKEN"
      echo ""
      echo "✅ Test notification sent!"
      echo ""
      echo "Check your iPhone for the notification 📱"
      break
    fi
  fi
done
