#!/bin/bash

# Run Flutter app and capture FCM token
# This runs in debug mode to see all logs

echo "🚀 Starting Flutter app in debug mode..."
echo "📱 Make sure your iPhone is connected and unlocked"
echo ""

cd /Users/ghaythallaheebi/WhizzEcoSystem/whizzEcosystem/whizzMerchants/frontend

# Run Flutter in debug mode
flutter run -d 00008110-001C79140284801E --debug 2>&1 | tee /tmp/flutter_debug.log | while IFS= read -r line; do
  echo "$line"
  
  # Capture FCM Token
  if [[ "$line" =~ "FCM Token:" ]]; then
    TOKEN=$(echo "$line" | grep -oE '[a-zA-Z0-9_-]{140,}')
    if [ ! -z "$TOKEN" ]; then
      echo ""
      echo "=========================================="
      echo "✅ FCM TOKEN CAPTURED!"
      echo "=========================================="
      echo "$TOKEN"
      echo "=========================================="
      echo ""
      echo "$TOKEN" > /tmp/fcm_token.txt
      echo "Token saved to: /tmp/fcm_token.txt"
      echo ""
    fi
  fi
  
  # Capture token upload confirmation
  if [[ "$line" =~ "Device token uploaded" ]] || [[ "$line" =~ "device token upload" ]]; then
    echo ""
    echo "🎉 TOKEN UPLOADED TO BACKEND!"
    echo ""
  fi
done
