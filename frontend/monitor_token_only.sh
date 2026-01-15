#!/bin/bash

LOG_FILE="/tmp/flutter_iphone_fcm_token.log"
TOKEN_FILE="/tmp/fcm_token.txt"

echo "📱 FCM Token Monitor"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📝 Watching log file: $LOG_FILE"
echo "🎫 Token will be saved to: $TOKEN_FILE"
echo ""
echo "⏳ Waiting for Flutter app to launch and log FCM token..."
echo "   (This monitor will run until token is found)"
echo ""

# Clear old token file
rm -f "$TOKEN_FILE"

# Watch the log file for FCM token (runs indefinitely until token found)
tail -f "$LOG_FILE" 2>/dev/null | while read line; do
    # Echo all lines that mention FCM or Firebase
    if echo "$line" | grep -qi "fcm\|firebase"; then
        echo "$line"
    fi
    
    # Look for the specific FCM token line
    if echo "$line" | grep -q "✅ FCM Token:"; then
        # Extract the token (everything after "✅ FCM Token: ")
        TOKEN=$(echo "$line" | sed 's/.*✅ FCM Token: //' | tr -d '[:space:]')
        
        if [ ! -z "$TOKEN" ]; then
            echo ""
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "🎉 FCM TOKEN CAPTURED!"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo ""
            echo "$TOKEN"
            echo ""
            echo "$TOKEN" > "$TOKEN_FILE"
            
            echo "✅ Token saved to: $TOKEN_FILE"
            echo ""
            echo "📤 Sending test notification..."
            echo ""
            
            # Auto-send test notification
            if [ -f "send_test_notification.py" ]; then
                python3 send_test_notification.py "$TOKEN"
                if [ $? -eq 0 ]; then
                    echo ""
                    echo "✅ Test notification sent successfully!"
                    echo "📱 Check your iPhone for the notification"
                else
                    echo ""
                    echo "⚠️  Failed to send notification. You can manually send with:"
                    echo "   python3 send_test_notification.py $TOKEN"
                fi
            else
                echo "⚠️  send_test_notification.py not found"
                echo "   Manually send notification with:"
                echo "   python3 send_test_notification.py $TOKEN"
            fi
            
            echo ""
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "✅ MISSION ACCOMPLISHED! Press Ctrl+C to exit monitor."
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            
            # Keep monitoring in case token refreshes
            continue
        fi
    fi
done
