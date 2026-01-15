#!/bin/bash

# Clean iOS Installation Script
# This script completely removes the old app and does a fresh install

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}🧹 Starting Clean iOS Installation...${NC}"
echo ""

# Device ID
DEVICE_ID="00008110-001C79140284801E"
BUNDLE_ID="com.whizz.merchants"

echo -e "${YELLOW}📱 Target Device: Ghayth's iPhone${NC}"
echo -e "${YELLOW}📦 Bundle ID: $BUNDLE_ID${NC}"
echo ""

# Step 1: Remove app from device (if installed)
echo -e "${BLUE}🗑️  Removing old app from device...${NC}"
echo "Please manually delete the WhizzMerchants app from your iPhone:"
echo "1. Long press the app icon on your iPhone"
echo "2. Tap 'Remove App'"
echo "3. Tap 'Delete App'"
echo ""
read -p "Press ENTER when you've deleted the app from your iPhone..."
echo ""

# Step 2: Clean Flutter build
echo -e "${BLUE}🧹 Cleaning Flutter build...${NC}"
flutter clean > /dev/null 2>&1
echo -e "${GREEN}✅ Flutter cleaned${NC}"
echo ""

# Step 3: Remove iOS build artifacts
echo -e "${BLUE}🧹 Removing iOS build artifacts...${NC}"
rm -rf ios/Pods
rm -rf ios/Podfile.lock
rm -rf ios/build
rm -rf ios/.symlinks
rm -rf build
echo -e "${GREEN}✅ iOS artifacts removed${NC}"
echo ""

# Step 4: Get Flutter dependencies
echo -e "${BLUE}📦 Getting Flutter dependencies...${NC}"
flutter pub get > /dev/null 2>&1
echo -e "${GREEN}✅ Dependencies retrieved${NC}"
echo ""

# Step 5: Install CocoaPods
echo -e "${BLUE}🔧 Installing CocoaPods...${NC}"
cd ios
pod install --repo-update
cd ..
echo -e "${GREEN}✅ CocoaPods installed${NC}"
echo ""

# Step 6: Build and deploy
echo -e "${BLUE}🏗️  Building and deploying to iPhone...${NC}"
echo -e "${YELLOW}⏳ This will take a few minutes...${NC}"
echo ""
echo -e "${BLUE}The app will automatically launch on your iPhone when ready.${NC}"
echo ""

# Run in release mode
flutter run --release -d $DEVICE_ID

echo ""
echo -e "${GREEN}🎉 Clean installation complete!${NC}"
echo ""
echo -e "${BLUE}📋 Next Steps:${NC}"
echo "1. Check if the app opens without crashing"
echo "2. Look for FCM token in the console above"
echo "3. Copy the token for testing"
echo ""
