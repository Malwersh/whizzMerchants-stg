#!/bin/bash
# Auto-send notification when FCM token is detected

LOG_FILE="/tmp/flutter_iphone_fcm_token.log"
SCRIPT_DIR="/Users/ghaythallaheebi/WhizzEcoSystem/whizzEcosystem/whizzMerchants/frontend"

echo "🔍 Watching for FCM Token and auto-sending notification..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Wait for log file to exist
while [ ! -f "$LOG_FILE" ]; do
    sleep 1
done

# Monitor the log file
tail -f "$LOG_FILE" 2>/dev/null | while read -r line; do
    # Display the line
    echo "$line"
    
    # Check for FCM Token
    if echo "$line" | grep -q "✅ FCM Token:"; then
        TOKEN=$(echo "$line" | sed 's/.*✅ FCM Token: //' | sed 's/[[:space:]]*$//' | tr -d '\r\n')
        
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "🎉 FCM TOKEN FOUND!"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "Token: ${TOKEN:0:50}..."
        echo ""
        
        # Save token
        echo "$TOKEN" > /tmp/fcm_token.txt
        echo "✅ Token saved to: /tmp/fcm_token.txt"
        echo ""
        
        # Send notification automatically
        echo "📤 Sending test notification automatically..."
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        
        cd "$SCRIPT_DIR" || exit
        python3 send_test_notification.py "$TOKEN"
        
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "✅ DONE! Check your iPhone for the notification!"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        
        # Exit after sending
        exit 0
    fi
done
