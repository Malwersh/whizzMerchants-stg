#!/bin/bash

# Run Flutter and monitor for FCM token
cd /Users/ghaythallaheebi/WhizzEcoSystem/whizzEcosystem/whizzMerchants/frontend

LOG_FILE="/tmp/flutter_iphone_fcm_token.log"
TOKEN_FILE="/tmp/fcm_token.txt"

echo "🔄 Starting Flutter on iPhone and monitoring for FCM token..."
echo "📝 Log file: $LOG_FILE"
echo ""

# Clean previous logs
rm -f "$LOG_FILE" "$TOKEN_FILE"

# Run flutter in background and capture output
flutter run -d 00008110-001C79140284801E --debug 2>&1 | tee "$LOG_FILE" &
FLUTTER_PID=$!

echo "✅ Flutter started with PID: $FLUTTER_PID"
echo "🔍 Monitoring for FCM token (this will take 30-60 seconds)..."
echo ""

# Monitor the log file for FCM token
for i in {1..120}; do
    if [ -f "$LOG_FILE" ]; then
        # Look for the FCM token line
        TOKEN=$(grep "✅ FCM Token:" "$LOG_FILE" | tail -1 | sed 's/.*✅ FCM Token: //')
        
        if [ ! -z "$TOKEN" ]; then
            echo ""
            echo "🎉 FCM TOKEN FOUND!"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "$TOKEN"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo ""
            echo "$TOKEN" > "$TOKEN_FILE"
            
            echo "📤 Sending test notification..."
            python3 send_test_notification.py "$TOKEN"
            
            echo ""
            echo "✅ Done! Check your iPhone for the notification."
            echo "   Log file: $LOG_FILE"
            echo "   Token saved to: $TOKEN_FILE"
            break
        fi
    fi
    
    # Show progress every 5 seconds
    if [ $((i % 5)) -eq 0 ]; then
        echo "   Waiting... ($i seconds)"
    fi
    
    sleep 1
done

if [ -z "$TOKEN" ]; then
    echo ""
    echo "⚠️  No FCM token found after 120 seconds"
    echo "   Please check the log file: $LOG_FILE"
    echo "   You can manually search for the token with:"
    echo "   grep 'FCM Token' $LOG_FILE"
fi

echo ""
echo "💡 Flutter is still running (PID: $FLUTTER_PID)"
echo "   Press Ctrl+C to stop, or use: kill $FLUTTER_PID"
