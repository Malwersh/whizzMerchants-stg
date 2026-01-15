#!/bin/bash

# FCM Token Checker
# This script helps you find your FCM token from the running app

echo "🔍 FCM Token Finder"
echo "==================="
echo ""

DEVICE_ID="00008110-001C79140284801E"

echo "📱 Device: Ghayth's iPhone"
echo "🎯 App: WhizzMerchants (com.whizz.merchants)"
echo ""

# Method 1: Check if app is running
echo "1️⃣ Checking if app is running..."
if pgrep -f "flutter run" > /dev/null; then
    echo "   ✅ Flutter is connected to device"
else
    echo "   ⚠️  Flutter is not connected (but app may still be running)"
fi
echo ""

# Method 2: Try to get device logs
echo "2️⃣ Checking device logs for FCM token..."
echo "   (This may take a few seconds...)"
echo ""

# Try using Console.app logs
log show --predicate 'process == "Runner"' --info --last 2m 2>/dev/null | grep -i "fcm\|firebase\|token" | tail -10

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📋 Manual Methods to Get FCM Token:"
echo ""
echo "Method A: Xcode Console (Recommended)"
echo "  1. Open Xcode: ios/Runner.xcworkspace"
echo "  2. Press ⌘⇧C to show console"
echo "  3. Look for: '📱 FCM Token:' or '🔥 Firebase'"
echo "  4. Copy the token (starts with letters, contains :APA91b)"
echo ""
echo "Method B: Console.app"
echo "  1. Open Applications > Utilities > Console.app"
echo "  2. Select 'Ghayth's iPhone' from left sidebar"
echo "  3. Search for: 'FCM Token'"
echo "  4. Look in 'Runner' process logs"
echo ""
echo "Method C: Flutter Logs (Current Terminal)"
echo "  The app is running in the terminal that executed:"
echo "  'flutter run --release -d $DEVICE_ID --no-build'"
echo "  Look for Firebase/FCM logs there"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "❓ App Status Check:"
echo ""
read -p "Is the app open and running on your iPhone? (yes/no): " APP_RUNNING

if [[ "$APP_RUNNING" == "yes" ]]; then
    echo ""
    echo "✅ Great! The app is running successfully!"
    echo ""
    read -p "Can you see the FCM token in any console/logs? (yes/no): " TOKEN_VISIBLE
    
    if [[ "$TOKEN_VISIBLE" == "yes" ]]; then
        echo ""
        echo "🎉 Perfect! Copy the token and proceed to next steps:"
        echo ""
        echo "Next Steps:"
        echo "1. Copy your FCM token (152-160 characters)"
        echo "2. Upload APNs key to Firebase Console"
        echo "3. Send test notification"
        echo ""
        echo "See: GET_FCM_TOKEN.md for detailed instructions"
    else
        echo ""
        echo "🔍 Token not visible yet. Try these:"
        echo ""
        echo "1. Open Xcode and check console (⌘⇧C)"
        echo "2. Restart the app: Press 'q' in terminal, then 'flutter run' again"
        echo "3. Check if Firebase initialized correctly"
        echo ""
        echo "Or run: open ios/Runner.xcworkspace"
        echo "Then press ⌘R to run and check Xcode console"
    fi
else
    echo ""
    echo "❌ App is not running. Let's troubleshoot:"
    echo ""
    read -p "Did the app crash or show a white screen? (yes/no): " APP_CRASHED
    
    if [[ "$APP_CRASHED" == "yes" ]]; then
        echo ""
        echo "🔧 Troubleshooting crash:"
        echo ""
        echo "1. Open Xcode: open ios/Runner.xcworkspace"
        echo "2. Press ⌘R to run from Xcode"
        echo "3. Check console for crash logs"
        echo "4. Look for: SIGABRT, Firebase errors, method channel errors"
        echo ""
        echo "Common issues:"
        echo "- Firebase initialized twice"
        echo "- Missing GoogleService-Info.plist"
        echo "- Method channel not set up correctly"
    else
        echo ""
        echo "📱 Try launching from Xcode:"
        echo ""
        echo "1. Open: open ios/Runner.xcworkspace"
        echo "2. Select 'Ghayth's iPhone' in device dropdown"
        echo "3. Press ⌘R (or click Play button)"
        echo "4. Watch Xcode console for logs"
    fi
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📚 Documentation:"
echo "  - GET_FCM_TOKEN.md - How to get FCM token"
echo "  - LAUNCH_FROM_XCODE.md - Launch instructions"
echo "  - DEPLOYMENT_COMPLETE.md - Full guide"
echo ""
