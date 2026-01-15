#!/bin/bash
# Watch for FCM token in the log file

echo "🔍 Monitoring for FCM Token..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

LOG_FILE="/tmp/flutter_fcm_debug.log"

# Create empty log file if it doesn't exist
touch "$LOG_FILE"

# Watch the log file in real-time
tail -f "$LOG_FILE" 2>/dev/null | while read -r line; do
    # Display the line
    echo "$line"
    
    # Check for FCM Token
    if echo "$line" | grep -q "✅ FCM Token:"; then
        TOKEN=$(echo "$line" | sed 's/.*✅ FCM Token: //' | tr -d '\r\n[:space:]')
        
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "🎉 FCM TOKEN FOUND!"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "$TOKEN"
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        
        # Save to file
        echo "$TOKEN" > /tmp/fcm_token.txt
        echo "✅ Token saved to: /tmp/fcm_token.txt"
        echo ""
        
        # Show how to use it
        echo "🚀 Send test notification:"
        echo "   cd /Users/ghaythallaheebi/WhizzEcoSystem/whizzEcosystem/whizzMerchants/frontend"
        echo "   python3 send_test_notification.py $TOKEN"
        echo ""
        
        # Keep monitoring but show notification
        continue
    fi
    
    # Also check for Firebase initialization
    if echo "$line" | grep -qi "firebase.*initialized"; then
        echo "✅ Firebase initialized!"
    fi
    
    # Check for errors
    if echo "$line" | grep -qi "error\|failed\|exception"; then
        echo "⚠️  Check this line for potential issues"
    fi
done
