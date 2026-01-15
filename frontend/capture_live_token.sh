#!/bin/bash

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                                                              ║"
echo "║     🎫 CAPTURE FCM TOKEN FROM RUNNING APP 🎫                 ║"
echo "║                                                              ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

TOKEN_FILE="/tmp/fcm_token.txt"
DEVICE_ID="00008110-001C79140284801E"

echo "📱 Monitoring iPhone logs for FCM token..."
echo "🔍 Looking for: '✅ FCM Token:' or 'FCM registration token:'"
echo ""
echo "📝 Token will be saved to: $TOKEN_FILE"
echo ""
echo "⏰ Watching for 60 seconds... (Press Ctrl+C to stop)"
echo "💡 TIP: If token doesn't appear, force-quit and reopen the app"
echo ""

# Start monitoring device logs
rm -f "$TOKEN_FILE"

# Monitor for 60 seconds
timeout 60s idevicesyslog | while read -r line; do
    # Check for FCM token in various formats
    if echo "$line" | grep -q "✅ FCM Token:"; then
        TOKEN=$(echo "$line" | grep -oE "✅ FCM Token: [A-Za-z0-9_:-]+" | sed 's/✅ FCM Token: //')
        echo "🎉 FOUND IT!"
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "🎫 FCM TOKEN:"
        echo "$TOKEN"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "$TOKEN" > "$TOKEN_FILE"
        echo "✅ Token saved to: $TOKEN_FILE"
        echo ""
        echo "📤 You can now test push notifications with:"
        echo "   python3 send_test_notification.py \"$TOKEN\""
        exit 0
    elif echo "$line" | grep -q "FCM registration token:"; then
        TOKEN=$(echo "$line" | grep -oE "FCM registration token: [A-Za-z0-9_:-]+" | sed 's/FCM registration token: //')
        echo "🎉 FOUND IT!"
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "🎫 FCM TOKEN:"
        echo "$TOKEN"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "$TOKEN" > "$TOKEN_FILE"
        echo "✅ Token saved to: $TOKEN_FILE"
        echo ""
        echo "📤 You can now test push notifications with:"
        echo "   python3 send_test_notification.py \"$TOKEN\""
        exit 0
    fi
done

echo ""
echo "⏱️ Timeout reached. Token not detected."
echo ""
echo "🔄 Try these steps:"
echo "   1. Force-quit the app on your iPhone (swipe up)"
echo "   2. Reopen the Whizz Merchants app"
echo "   3. Run this script again"
echo ""
echo "   OR"
echo ""
echo "   View Xcode console logs directly:"
echo "   - Open Xcode"
echo "   - Window → Devices and Simulators"
echo "   - Select your iPhone"
echo "   - Click 'Open Console'"
echo "   - Look for 'FCM Token' messages"
