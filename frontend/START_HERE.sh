#!/bin/bash

cat << 'EOF'

╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║           🎯 FCM TOKEN CAPTURE - READY TO GO! 🎯              ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝

📋 You need TWO terminal windows/tabs:

┌─────────────────────────────────────────────────────────────┐
│ TERMINAL 1: Token Monitor (Start this FIRST!)              │
└─────────────────────────────────────────────────────────────┘

cd /Users/ghaythallaheebi/WhizzEcoSystem/whizzEcosystem/whizzMerchants/frontend
./monitor_token_only.sh


┌─────────────────────────────────────────────────────────────┐
│ TERMINAL 2: Flutter App (Start this SECOND!)               │
└─────────────────────────────────────────────────────────────┘

cd /Users/ghaythallaheebi/WhizzEcoSystem/whizzEcosystem/whizzMerchants/frontend
rm -f /tmp/flutter_iphone_fcm_token.log
flutter run -d 00008110-001C79140284801E --debug 2>&1 | tee /tmp/flutter_iphone_fcm_token.log


═══════════════════════════════════════════════════════════════

⏰ TIMELINE:
   • 0-5s:    Flutter resolves dependencies
   • 5-40s:   Xcode builds the app
   • 40-60s:  App launches on iPhone
   • 60-75s:  Firebase initializes
   • 75s:     ✅ FCM TOKEN CAPTURED!

📱 WHAT TO EXPECT:
   • Terminal 1 will show: "⏳ Waiting for Flutter app..."
   • Terminal 2 will show: Flutter build progress
   • Your iPhone will show: App launching
   • Terminal 1 will show: "🎉 FCM TOKEN CAPTURED!"
   • Your iPhone will show: Test notification!

⚠️  IMPORTANT:
   • DON'T kill either process until token is captured
   • DON'T press Ctrl+C or close terminals
   • DO keep your iPhone unlocked to see notification
   • DO wait patiently - it takes 60-90 seconds total

📖 Full instructions: cat FCM_TOKEN_CAPTURE_GUIDE.md

═══════════════════════════════════════════════════════════════

Ready? Press Enter to see the commands again, or Ctrl+C to exit.

EOF

read -p ""

echo ""
echo "📋 TERMINAL 1 (Copy this):"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "cd /Users/ghaythallaheebi/WhizzEcoSystem/whizzEcosystem/whizzMerchants/frontend && ./monitor_token_only.sh"
echo ""
echo ""
echo "📋 TERMINAL 2 (Copy this):"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "cd /Users/ghaythallaheebi/WhizzEcoSystem/whizzEcosystem/whizzMerchants/frontend && rm -f /tmp/flutter_iphone_fcm_token.log && flutter run -d 00008110-001C79140284801E --debug 2>&1 | tee /tmp/flutter_iphone_fcm_token.log"
echo ""
