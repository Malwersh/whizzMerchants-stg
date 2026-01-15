#!/bin/bash

echo "📱 Capturing iOS device logs for FCM token..."
echo "🔍 Make sure the Whizz Merchants app is running on your iPhone"
echo ""
echo "Please open the app on your iPhone now and log in."
echo "This script will capture the FCM token from the device logs."
echo ""
echo "Press Ctrl+C when done."
echo ""

TOKEN_FILE="/tmp/fcm_token.txt"

# Start capturing device logs and filter for FCM-related output
idevicesyslog | while read line; do
    # Print the line
    echo "$line"
    
    # Look for FCM Token in the logs
    if echo "$line" | grep -qi "FCM Token:"; then
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
            
            # Send test notification
            if [ -f "send_test_notification.py" ]; then
                echo "📤 Sending test notification..."
                python3 send_test_notification.py "$TOKEN"
            fi
            
            echo ""
            echo "Press Ctrl+C to stop monitoring"
        fi
    fi
    
    # Also look for Firebase registration token
    if echo "$line" | grep -qi "Firebase registration token:"; then
        TOKEN=$(echo "$line" | grep -oE "[a-zA-Z0-9_-]{140,}" | head -1)
        
        if [ ! -z "$TOKEN" ]; then
            echo ""
            echo "🎉 =================================="
            echo "🎫 FIREBASE TOKEN FOUND!"
            echo "🎉 =================================="
            echo "$TOKEN"
            echo "$TOKEN" > "$TOKEN_FILE"
            echo ""
            echo "✅ Token saved to: $TOKEN_FILE"
            echo ""
            
            # Send test notification
            if [ -f "send_test_notification.py" ]; then
                echo "📤 Sending test notification..."
                python3 send_test_notification.py "$TOKEN"
            fi
            
            echo ""
            echo "Press Ctrl+C to stop monitoring"
        fi
    fi
done
