#!/bin/bash

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                                                              ║"
echo "║     🔄 REBUILD APP & CAPTURE FCM TOKEN ON IPHONE 🔄          ║"
echo "║                                                              ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Configuration
DEVICE_ID="00008110-001C79140284801E"
LOG_FILE="/tmp/flutter_iphone_rebuild.log"
TOKEN_FILE="/tmp/fcm_token.txt"

# Clean up old files
rm -f "$LOG_FILE" "$TOKEN_FILE"

echo "📱 iPhone Device ID: $DEVICE_ID"
echo "📝 Log file: $LOG_FILE"
echo "🎫 Token will be saved to: $TOKEN_FILE"
echo ""

# Check if device is connected
echo "🔍 Checking if iPhone is connected..."
if ! flutter devices | grep -q "$DEVICE_ID"; then
    echo "❌ iPhone not found! Please connect your iPhone and trust this computer."
    exit 1
fi
echo "✅ iPhone detected!"
echo ""

# Start device logging in background
echo "📱 Starting iOS device log capture..."
idevicesyslog > /tmp/iphone_system.log 2>&1 &
SYSLOG_PID=$!
echo "✅ Device logging started (PID: $SYSLOG_PID)"
echo ""

# Function to cleanup on exit
cleanup() {
    echo ""
    echo "🧹 Cleaning up..."
    kill $SYSLOG_PID 2>/dev/null
    echo "✅ Cleanup complete"
}
trap cleanup EXIT

# Build and run
echo "🔨 Building and installing app on iPhone..."
echo "⏰ This will take 1-2 minutes. Please wait..."
echo ""

# Run Flutter and capture output
flutter run -d "$DEVICE_ID" --release 2>&1 | tee "$LOG_FILE" | while IFS= read -r line; do
    echo "$line"
    
    # Check for FCM token in Flutter output
    if echo "$line" | grep -q "✅ FCM Token:"; then
        TOKEN=$(echo "$line" | sed 's/.*✅ FCM Token: //' | tr -d '[:space:]')
        if [ ! -z "$TOKEN" ]; then
            echo ""
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "🎉 FCM TOKEN CAPTURED FROM FLUTTER OUTPUT!"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo ""
            echo "$TOKEN"
            echo ""
            echo "$TOKEN" > "$TOKEN_FILE"
            echo "✅ Token saved to: $TOKEN_FILE"
            echo ""
        fi
    fi
done &

FLUTTER_PID=$!

# Wait for Flutter to finish or timeout after 3 minutes
TIMEOUT=180
ELAPSED=0

echo "⏳ Waiting for app to launch and initialize..."
echo ""

while kill -0 $FLUTTER_PID 2>/dev/null; do
    sleep 5
    ELAPSED=$((ELAPSED + 5))
    
    # Check if token file exists
    if [ -f "$TOKEN_FILE" ] && [ -s "$TOKEN_FILE" ]; then
        echo ""
        echo "✅ Token captured! Sending test notification..."
        
        TOKEN=$(cat "$TOKEN_FILE")
        if [ -f "send_test_notification.py" ]; then
            python3 send_test_notification.py "$TOKEN"
        else
            echo "⚠️  send_test_notification.py not found"
            echo "📝 Token: $TOKEN"
        fi
        
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "🎉 SUCCESS! Check your iPhone for the notification!"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        break
    fi
    
    # Show progress
    if [ $((ELAPSED % 20)) -eq 0 ]; then
        echo "   Still waiting... ($ELAPSED seconds elapsed)"
        
        # Check device logs as backup
        if [ -f /tmp/iphone_system.log ]; then
            DEVICE_TOKEN=$(grep -i "FCM Token\|Firebase registration token" /tmp/iphone_system.log | tail -1)
            if [ ! -z "$DEVICE_TOKEN" ]; then
                echo "   (Found token in device logs...)"
            fi
        fi
    fi
    
    if [ $ELAPSED -ge $TIMEOUT ]; then
        echo ""
        echo "⏰ Timeout reached. Let's check if token is in the logs..."
        break
    fi
done

# Final check in logs if token not found
if [ ! -f "$TOKEN_FILE" ] || [ ! -s "$TOKEN_FILE" ]; then
    echo ""
    echo "🔍 Searching for FCM token in logs..."
    
    # Check Flutter logs
    if [ -f "$LOG_FILE" ]; then
        TOKEN=$(grep "✅ FCM Token:" "$LOG_FILE" | tail -1 | sed 's/.*✅ FCM Token: //' | tr -d '[:space:]')
        if [ ! -z "$TOKEN" ]; then
            echo "$TOKEN" > "$TOKEN_FILE"
            echo "✅ Found token in Flutter logs!"
        fi
    fi
    
    # Check device logs
    if [ ! -f "$TOKEN_FILE" ] || [ ! -s "$TOKEN_FILE" ]; then
        if [ -f /tmp/iphone_system.log ]; then
            TOKEN=$(grep -oE "[a-zA-Z0-9_-]{140,}" /tmp/iphone_system.log | tail -1)
            if [ ! -z "$TOKEN" ]; then
                echo "$TOKEN" > "$TOKEN_FILE"
                echo "✅ Found token in device logs!"
            fi
        fi
    fi
    
    if [ -f "$TOKEN_FILE" ] && [ -s "$TOKEN_FILE" ]; then
        TOKEN=$(cat "$TOKEN_FILE")
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "🎉 FCM TOKEN FOUND!"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "$TOKEN"
        echo ""
        
        # Send test notification
        if [ -f "send_test_notification.py" ]; then
            echo "📤 Sending test notification..."
            python3 send_test_notification.py "$TOKEN"
            echo ""
            echo "✅ Check your iPhone for the notification!"
        fi
    else
        echo ""
        echo "⚠️  FCM token not found in logs."
        echo ""
        echo "📝 Possible issues:"
        echo "   1. App didn't finish launching"
        echo "   2. Firebase initialization failed"
        echo "   3. Notification permissions not granted"
        echo ""
        echo "🔍 Check the logs:"
        echo "   cat $LOG_FILE | grep -i 'fcm\|firebase'"
    fi
fi

echo ""
echo "📝 Full logs saved to: $LOG_FILE"
echo "🎫 Token saved to: $TOKEN_FILE"
echo ""
