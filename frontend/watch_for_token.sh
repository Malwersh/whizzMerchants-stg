#!/bin/bash

echo "🎫 CAPTURING FCM TOKEN FROM iPhone..."
echo ""
echo "📱 Monitoring device logs..."
echo "💡 Force-quit and reopen the app if you don't see the token"
echo "⏰ Watching for 30 seconds..."
echo ""

# Monitor device logs and filter for FCM token
/opt/homebrew/bin/idevicesyslog 2>/dev/null | grep --line-buffered -i "fcm" | while read -r line; do
    echo "$line"
    
    # Check if this line contains the token
    if echo "$line" | grep -qi "token"; then
        # Try to extract token-like strings (long alphanumeric with possible : and -)
        TOKEN=$(echo "$line" | grep -oE "[A-Za-z0-9_-]{100,}" | head -1)
        if [ ! -z "$TOKEN" ]; then
            echo ""
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "🎉 FOUND FCM TOKEN:"
            echo "$TOKEN"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo ""
            echo "$TOKEN" > /tmp/fcm_token.txt
            echo "✅ Saved to: /tmp/fcm_token.txt"
            echo ""
            echo "📤 Test notification:"
            echo "   python3 send_test_notification.py \"$TOKEN\""
            echo ""
            exit 0
        fi
    fi
done
