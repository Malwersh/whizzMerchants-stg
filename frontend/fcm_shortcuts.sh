#!/bin/bash

# FCM Token Capture - Quick Reference
# Save this file and run: source fcm_shortcuts.sh

alias fcm-start='cd /Users/ghaythallaheebi/WhizzEcoSystem/whizzEcosystem/whizzMerchants/frontend && ./START_HERE.sh'
alias fcm-monitor='cd /Users/ghaythallaheebi/WhizzEcoSystem/whizzEcosystem/whizzMerchants/frontend && ./monitor_token_only.sh'
alias fcm-run='cd /Users/ghaythallaheebi/WhizzEcoSystem/whizzEcosystem/whizzMerchants/frontend && rm -f /tmp/flutter_iphone_fcm_token.log && flutter run -d 00008110-001C79140284801E --debug 2>&1 | tee /tmp/flutter_iphone_fcm_token.log'
alias fcm-token='cat /tmp/fcm_token.txt'
alias fcm-log='tail -50 /tmp/flutter_iphone_fcm_token.log'
alias fcm-send='cd /Users/ghaythallaheebi/WhizzEcoSystem/whizzEcosystem/whizzMerchants/frontend && python3 send_test_notification.py $(cat /tmp/fcm_token.txt)'

echo "✅ FCM shortcuts loaded!"
echo ""
echo "Available commands:"
echo "  fcm-start     - Show instructions"
echo "  fcm-monitor   - Start token monitor (Terminal 1)"
echo "  fcm-run       - Run Flutter app (Terminal 2)"
echo "  fcm-token     - Display captured token"
echo "  fcm-log       - Show recent logs"
echo "  fcm-send      - Send test notification"
echo ""
