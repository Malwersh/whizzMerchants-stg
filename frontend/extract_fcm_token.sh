#!/bin/bash

# FCM Token Extractor
# Helps extract and save FCM token from deployment logs

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}🔍 FCM Token Extractor${NC}"
echo ""

LOG_FILE="/Users/ghaythallaheebi/WhizzEcoSystem/whizzEcosystem/whizzMerchants/frontend/deploy_log.txt"

if [ ! -f "$LOG_FILE" ]; then
    echo -e "${YELLOW}⚠️  Log file not found: $LOG_FILE${NC}"
    echo ""
    echo -e "${BLUE}Alternative ways to get FCM token:${NC}"
    echo ""
    echo "1. From Xcode Console:"
    echo "   - Open Xcode"
    echo "   - Open Console (⌘⇧C)"
    echo "   - Look for '📱 FCM Token:' in logs"
    echo ""
    echo "2. From Terminal (if app is running):"
    echo "   - Check the terminal where you ran 'flutter run'"
    echo "   - Look for '📱 FCM Token:' in output"
    echo ""
    echo "3. Re-run deployment with logging:"
    echo "   flutter run --release -d 00008110-001C79140284801E 2>&1 | tee deploy_log.txt"
    echo ""
    exit 1
fi

echo -e "${BLUE}📄 Searching log file...${NC}"
echo ""

# Search for FCM token in log file
FCM_TOKEN=$(grep -o 'FCM Token: [A-Za-z0-9:_-]*' "$LOG_FILE" | head -1 | sed 's/FCM Token: //')

if [ -z "$FCM_TOKEN" ]; then
    echo -e "${YELLOW}⚠️  No FCM token found in log file${NC}"
    echo ""
    echo -e "${BLUE}Showing recent log entries that might contain token info:${NC}"
    echo ""
    grep -i -A 2 -B 2 "firebase\|fcm\|token\|notification" "$LOG_FILE" | tail -20
    echo ""
    echo -e "${YELLOW}💡 Tip: Make sure the app launched successfully and Firebase initialized${NC}"
    echo ""
else
    echo -e "${GREEN}✅ FCM Token found!${NC}"
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
    echo -e "${GREEN}$FCM_TOKEN${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
    echo ""
    
    # Save to file
    TOKEN_FILE="/Users/ghaythallaheebi/WhizzEcoSystem/whizzEcosystem/whizzMerchants/frontend/fcm_token.txt"
    echo "$FCM_TOKEN" > "$TOKEN_FILE"
    echo -e "${GREEN}✅ Token saved to: $TOKEN_FILE${NC}"
    echo ""
    
    # Copy to clipboard (macOS)
    echo "$FCM_TOKEN" | pbcopy
    echo -e "${GREEN}✅ Token copied to clipboard!${NC}"
    echo ""
    
    echo -e "${BLUE}🎯 Next Steps:${NC}"
    echo ""
    echo "1. Upload APNs Key to Firebase Console:"
    echo "   - File: /Users/ghaythallaheebi/Downloads/AuthKey_4PQUPLUSU2.p8"
    echo "   - Key ID: 4PQUPLUSU2"
    echo "   - Team ID: F6B9QH9W82"
    echo ""
    echo "2. Send test notification:"
    echo "   - Option A: Firebase Console > Cloud Messaging > Send test message"
    echo "   - Option B: Run ./test_notification.sh $FCM_TOKEN"
    echo ""
    echo "3. Test notification in different states:"
    echo "   - Foreground (app open)"
    echo "   - Background (app minimized)"
    echo "   - Terminated (app closed)"
    echo ""
fi
