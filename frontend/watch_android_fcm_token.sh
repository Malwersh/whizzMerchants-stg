#!/bin/bash

LOG_FILE="/tmp/flutter_android_fcm.log"
TOKEN_FILE="/tmp/android_fcm_token.txt"

echo "📱 Monitoring Android FCM logs..."
echo "📝 Log file: $LOG_FILE"
echo "🎫 Token will be saved to: $TOKEN_FILE"
echo ""
echo "Waiting for FCM token..."
echo ""

# Watch the log file for FCM token
tail -f "$LOG_FILE" 2>/dev/null | while read line; do
    echo "$line"
    
    # Look for FCM token patterns
    if echo "$line" | grep -qi "FCM.*Token:\|Firebase registration token:\|✅ FCM Token:"; then
        # Extract the token (it's usually the last part after a colon)
        TOKEN=$(echo "$line" | grep -oE "[a-zA-Z0-9_-]{140,}" | head -1)
        
        if [ ! -z "$TOKEN" ]; then
            echo ""
            echo "🎉 =================================="
            echo "🎫 FCM TOKEN FOUND!"
            echo "🎉 =================================="
            echo "$TOKEN"
            echo "$TOKEN" > "$TOKEN_FILE"
            echo ""
            echo "✅ Token saved to: $TOKEN_FILE"
            echo ""
            echo "📤 Ready to send test notification!"
            echo "Run: python3 send_test_notification.py $TOKEN"
            echo ""
            
            # Auto-send test notification
            if [ -f "send_test_notification.py" ]; then
                echo "🚀 Auto-sending test notification..."
                python3 send_test_notification.py "$TOKEN"
            fi
            
            break
        fi
    fi
done
