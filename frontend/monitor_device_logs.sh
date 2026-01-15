#!/bin/bash

echo "🔍 Monitoring iPhone device logs for FCM token..."
echo "Press Ctrl+C to stop"
echo ""

# Monitor device logs
idevicesyslog -d 00008110-001C79140284801E 2>&1 | grep --line-buffered -E "FCM Token|Firebase|device token|APNs"
