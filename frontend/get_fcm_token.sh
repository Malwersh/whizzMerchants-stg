#!/bin/bash

clear
echo "╔════════════════════════════════════════════════════════════╗"
echo "║     🎯 WHIZZ MERCHANTS - FCM TOKEN CAPTURE GUIDE          ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Check if iPhone is connected
if ! idevice_id -l >/dev/null 2>&1; then
    echo "❌ No iPhone detected!"
    echo "   Please connect your iPhone via USB and trust this computer."
    exit 1
fi

DEVICE_ID=$(idevice_id -l | head -1)
echo "✅ iPhone connected: $DEVICE_ID"
echo ""

# Check if app is installed
echo "🔍 Checking if Whizz Merchants app is installed..."
if ideviceinstaller -u "$DEVICE_ID" -l 2>/dev/null | grep -q "com.whizz.merchants"; then
    echo "✅ App is installed!"
else
    echo "⚠️  App not found. Building and installing..."
    echo ""
    cd /Users/ghaythallaheebi/WhizzEcoSystem/whizzEcosystem/whizzMerchants/frontend
    flutter build ios --release
    flutter install -d "$DEVICE_ID"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📱 NEXT STEPS:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "1. 📲 Open the \"Whizz Merchants\" app on your iPhone"
echo "2. 🔐 Log in with your credentials"
echo "3. ⏱️  Wait for this terminal to show the FCM token (5-10 seconds)"
echo ""
echo "Press ENTER when ready to start monitoring..."
read

echo ""
echo "🔍 Monitoring iPhone logs for FCM token..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

TOKEN_FILE="/tmp/fcm_token.txt"

# Monitor device logs
idevicesyslog 2>&1 | while read line; do
    # Only show relevant lines
    if echo "$line" | grep -qi "runner\|firebase\|fcm\|token\|messaging"; then
        echo "$line"
    fi
    
    # Look for FCM Token
    if echo "$line" | grep -qi "✅ FCM Token:"; then
        TOKEN=$(echo "$line" | sed -n 's/.*✅ FCM Token: \([a-zA-Z0-9_-]*\).*/\1/p')
        
        if [ ! -z "$TOKEN" ]; then
            echo ""
            echo "🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉"
            echo "          🎫 FCM TOKEN CAPTURED! 🎫"
            echo "🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉"
            echo ""
            echo "$TOKEN"
            echo ""
            echo "$TOKEN" > "$TOKEN_FILE"
            echo "✅ Token saved to: $TOKEN_FILE"
            echo ""
            
            # Send test notification
            cd /Users/ghaythallaheebi/WhizzEcoSystem/whizzEcosystem/whizzMerchants/frontend
            if [ -f "send_test_notification.py" ]; then
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                echo "📤 Sending test notification to your iPhone..."
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                echo ""
                python3 send_test_notification.py "$TOKEN"
                echo ""
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                echo "✅ Check your iPhone for the notification!"
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            fi
            
            echo ""
            echo "Press Ctrl+C to stop monitoring or wait for more notifications..."
        fi
    fi
    
    # Also look for Firebase registration token format
    if echo "$line" | grep -qi "Firebase registration token:"; then
        TOKEN=$(echo "$line" | grep -oE "[a-zA-Z0-9_-]{140,}" | head -1)
        
        if [ ! -z "$TOKEN" ]; then
            echo ""
            echo "🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉"
            echo "          🎫 FIREBASE TOKEN CAPTURED! 🎫"
            echo "🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉"
            echo ""
            echo "$TOKEN"
            echo ""
            echo "$TOKEN" > "$TOKEN_FILE"
            echo "✅ Token saved to: $TOKEN_FILE"
            echo ""
            
            # Send test notification
            cd /Users/ghaythallaheebi/WhizzEcoSystem/whizzEcosystem/whizzMerchants/frontend
            if [ -f "send_test_notification.py" ]; then
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                echo "📤 Sending test notification to your iPhone..."
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                echo ""
                python3 send_test_notification.py "$TOKEN"
                echo ""
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                echo "✅ Check your iPhone for the notification!"
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            fi
            
            echo ""
            echo "Press Ctrl+C to stop monitoring..."
        fi
    fi
done
