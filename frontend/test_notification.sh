#!/bin/bash

# FCM Test Notification Script
# This script helps you test push notifications to your iOS device

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}🔔 FCM Notification Testing Tool${NC}"
echo ""

# Check if FCM token is provided
if [ -z "$1" ]; then
    echo -e "${YELLOW}Usage: ./test_notification.sh <FCM_TOKEN> [optional: notification_title] [optional: notification_body]${NC}"
    echo ""
    echo -e "${YELLOW}Example:${NC}"
    echo "./test_notification.sh your_fcm_token_here"
    echo "./test_notification.sh your_fcm_token_here 'New Order' 'You have a new order from John!'"
    echo ""
    echo -e "${BLUE}📋 How to get your FCM token:${NC}"
    echo "1. Deploy app to iPhone"
    echo "2. Check Xcode console or terminal output"
    echo "3. Look for: 📱 FCM Token: <YOUR_TOKEN>"
    echo "4. Copy the token and use it with this script"
    echo ""
    exit 1
fi

FCM_TOKEN=$1
TITLE=${2:-"Test Notification"}
BODY=${3:-"This is a test notification from WhizzMerchants"}

echo -e "${BLUE}📱 Target Device FCM Token:${NC}"
echo "${FCM_TOKEN:0:20}...${FCM_TOKEN: -20}"
echo ""
echo -e "${BLUE}📝 Notification Content:${NC}"
echo "Title: $TITLE"
echo "Body: $BODY"
echo ""

# Check if Firebase Server Key is set
if [ -z "$FIREBASE_SERVER_KEY" ]; then
    echo -e "${YELLOW}⚠️  Firebase Server Key not set${NC}"
    echo ""
    echo -e "${BLUE}To send notifications via this script, you need:${NC}"
    echo "1. Go to Firebase Console > Project Settings > Cloud Messaging"
    echo "2. Under 'Cloud Messaging API (Legacy)', get your Server Key"
    echo "3. Run: export FIREBASE_SERVER_KEY='your_key_here'"
    echo "4. Then run this script again"
    echo ""
    echo -e "${BLUE}Alternative: Use Firebase Console${NC}"
    echo "1. Go to Firebase Console > Cloud Messaging"
    echo "2. Click 'Send your first message'"
    echo "3. Enter title and body"
    echo "4. Click 'Send test message'"
    echo "5. Paste your FCM token: $FCM_TOKEN"
    echo "6. Click 'Test'"
    echo ""
    exit 1
fi

# Send notification using FCM Legacy API
echo -e "${BLUE}📤 Sending notification...${NC}"

RESPONSE=$(curl -X POST https://fcm.googleapis.com/fcm/send \
  -H "Authorization: key=$FIREBASE_SERVER_KEY" \
  -H "Content-Type: application/json" \
  -d "{
    \"to\": \"$FCM_TOKEN\",
    \"notification\": {
      \"title\": \"$TITLE\",
      \"body\": \"$BODY\",
      \"sound\": \"default\",
      \"badge\": \"1\"
    },
    \"data\": {
      \"click_action\": \"FLUTTER_NOTIFICATION_CLICK\",
      \"test\": \"true\",
      \"timestamp\": \"$(date +%s)\"
    },
    \"priority\": \"high\"
  }" 2>&1)

echo ""
echo -e "${BLUE}📨 Response:${NC}"
echo "$RESPONSE"
echo ""

if echo "$RESPONSE" | grep -q "\"success\":1"; then
    echo -e "${GREEN}✅ Notification sent successfully!${NC}"
    echo ""
    echo -e "${BLUE}📱 Check your iPhone:${NC}"
    echo "- If app is in foreground: Notification should appear as banner"
    echo "- If app is in background: Notification should appear in notification center"
    echo "- If app is closed: Notification should appear and wake screen"
    echo ""
else
    echo -e "${RED}❌ Failed to send notification${NC}"
    echo ""
    echo -e "${YELLOW}Troubleshooting:${NC}"
    echo "1. Verify FCM token is correct"
    echo "2. Check Firebase Server Key is valid"
    echo "3. Ensure APNs key is uploaded to Firebase"
    echo "4. Check app has notification permissions"
    echo ""
fi
