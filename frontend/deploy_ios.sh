#!/bin/bash

# WhizzMerchants iOS Deployment Script
# This script builds and deploys the app to a connected iPhone

set -e

echo "🚀 Starting iOS deployment process..."
echo ""

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if iPhone is connected
echo -e "${BLUE}📱 Checking for connected devices...${NC}"
DEVICE_COUNT=$(xcrun xctrace list devices 2>&1 | grep "iPhone" | grep -v "Simulator" | wc -l | xargs)

if [ "$DEVICE_COUNT" -eq "0" ]; then
    echo -e "${RED}❌ No iPhone detected. Please connect your iPhone via USB.${NC}"
    exit 1
fi

DEVICE_NAME=$(xcrun xctrace list devices 2>&1 | grep "iPhone" | grep -v "Simulator" | head -1)
echo -e "${GREEN}✅ Found device: $DEVICE_NAME${NC}"
echo ""

# Clean build folders
echo -e "${BLUE}🧹 Cleaning build folders...${NC}"
flutter clean > /dev/null 2>&1
rm -rf ios/Pods ios/Podfile.lock
echo -e "${GREEN}✅ Cleaned${NC}"
echo ""

# Get dependencies
echo -e "${BLUE}📦 Getting Flutter dependencies...${NC}"
flutter pub get > /dev/null 2>&1
echo -e "${GREEN}✅ Dependencies retrieved${NC}"
echo ""

# Install CocoaPods
echo -e "${BLUE}🔧 Installing CocoaPods...${NC}"
cd ios
pod install --repo-update
cd ..
echo -e "${GREEN}✅ CocoaPods installed${NC}"
echo ""

# Build and deploy to iPhone
echo -e "${BLUE}🏗️  Building and deploying to iPhone...${NC}"
echo -e "${YELLOW}⏳ This may take a few minutes...${NC}"
echo ""

flutter run --release -d 00008110-001C79140284801E

echo ""
echo -e "${GREEN}🎉 Deployment complete!${NC}"
echo ""
echo -e "${YELLOW}📋 Next Steps:${NC}"
echo "1. Check Xcode console for FCM token"
echo "2. Copy the FCM token (starts with 'FCM Token: ...')"
echo "3. Upload APNs key to Firebase Console"
echo "4. Send test notification"
echo ""
