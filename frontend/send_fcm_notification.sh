#!/bin/bash
# Send FCM Push Notification - Scheduled Maintenance Alert
# Usage: ./send_fcm_notification.sh <FCM_TOKEN> <SERVER_KEY>

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=================================================="
echo "📱 Whizz Merchants - FCM Notification Sender"
echo "=================================================="
echo ""

# Check if arguments are provided
if [ $# -eq 0 ]; then
    echo -e "${YELLOW}📋 Instructions:${NC}"
    echo ""
    echo "1️⃣ Get your FCM Token from the app console:"
    echo "   Look for: '✅ FCM Token: ...'"
    echo ""
    echo "2️⃣ Get your Firebase Server Key:"
    echo "   • Go to: https://console.firebase.google.com"
    echo "   • Select project: 'wizz-business-app'"
    echo "   • Go to: Project Settings > Cloud Messaging"
    echo "   • Copy the 'Server key' (Legacy)"
    echo ""
    echo -e "${GREEN}Usage:${NC}"
    echo "  $0 <FCM_TOKEN> <SERVER_KEY>"
    echo ""
    echo -e "${GREEN}Example:${NC}"
    echo "  $0 'dXyZ123...' 'AAAABCdefGH...'"
    echo ""
    exit 1
fi

FCM_TOKEN=$1
SERVER_KEY=$2

if [ -z "$FCM_TOKEN" ] || [ -z "$SERVER_KEY" ]; then
    echo -e "${RED}❌ Error: Both FCM_TOKEN and SERVER_KEY are required${NC}"
    exit 1
fi

echo -e "${BLUE}📤 Sending notification...${NC}"
echo "Target: ${FCM_TOKEN:0:20}..."
echo ""

# Create JSON payload
PAYLOAD=$(cat <<EOF
{
  "to": "$FCM_TOKEN",
  "notification": {
    "title": "🔧 Scheduled Maintenance",
    "body": "System maintenance scheduled for tonight at 11 PM. Expected downtime: 2 hours.",
    "sound": "default",
    "badge": "1"
  },
  "data": {
    "type": "maintenance",
    "scheduled_time": "$(date -u -v+6H '+%Y-%m-%dT%H:%M:%SZ')",
    "duration": "2 hours",
    "priority": "high",
    "click_action": "FLUTTER_NOTIFICATION_CLICK"
  },
  "priority": "high",
  "content_available": true
}
EOF
)

# Send notification
RESPONSE=$(curl -s -X POST \
  -H "Authorization: Bearer $SERVER_KEY" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD" \
  https://fcm.googleapis.com/fcm/send)

# Check response
if echo "$RESPONSE" | grep -q "\"success\":1"; then
    echo -e "${GREEN}✅ Notification sent successfully!${NC}"
    echo ""
    echo "Response:"
    echo "$RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$RESPONSE"
    echo ""
    echo -e "${GREEN}🎉 Check your iPhone for the notification!${NC}"
elif echo "$RESPONSE" | grep -q "error"; then
    echo -e "${RED}❌ Failed to send notification${NC}"
    echo ""
    echo "Response:"
    echo "$RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$RESPONSE"
else
    echo -e "${YELLOW}⚠️ Unexpected response${NC}"
    echo ""
    echo "Response:"
    echo "$RESPONSE"
fi

echo ""
echo "=================================================="
