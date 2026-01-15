#!/bin/bash

# Simple FCM Token Finder
# Searches Xcode derived data logs for FCM token

echo "🔍 Searching for FCM Token in Xcode logs..."
echo ""

# Search Xcode DerivedData logs
LOG_PATH="$HOME/Library/Developer/Xcode/DerivedData/Runner-*/Logs/Debug/"

if [ -d "$LOG_PATH" ]; then
  echo "Searching recent Xcode logs..."
  find ~/Library/Developer/Xcode/DerivedData/Runner-*/Logs -name "*.xcactivitylog" -exec strings {} \; | grep -i "FCM Token" | tail -5
fi

echo ""
echo "🔍 Checking device logs with idevicesyslog..."
timeout 30 idevicesyslog 2>/dev/null | grep -i "FCM Token" --line-buffered &

echo ""
echo "⏳ Monitoring for 30 seconds..."
echo "💡 TIP: If no token appears:"
echo "   1. Make sure app is open on iPhone"
echo "   2. Look in Xcode console (bottom panel)"
echo "   3. Try: Xcode → Window → Devices → Select iPhone → Open Console"
echo "   4. Search for 'FCM' in the console"
echo ""
