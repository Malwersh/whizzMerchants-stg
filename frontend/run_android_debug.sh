#!/bin/bash

echo "🤖 Starting Flutter app on Android emulator..."
echo "📝 Logs will be saved to: /tmp/flutter_android_fcm.log"
echo ""

cd /Users/ghaythallaheebi/WhizzEcoSystem/whizzEcosystem/whizzMerchants/frontend

# Run Flutter and capture all output
flutter run -d emulator-5554 --debug 2>&1 | tee /tmp/flutter_android_fcm.log

echo ""
echo "✅ App stopped. Check logs at: /tmp/flutter_android_fcm.log"
