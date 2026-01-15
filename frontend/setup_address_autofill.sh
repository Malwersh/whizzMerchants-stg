#!/bin/bash
# Setup script for Mapbox Address Autofill in WhizzMerchants Flutter App
# This script helps configure the Mapbox integration for iOS and Android

set -e

echo "🚀 Setting up Mapbox Address Autofill for WhizzMerchants"
echo "=========================================================="
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if we're in the right directory
if [ ! -f "pubspec.yaml" ]; then
    echo -e "${RED}❌ Error: Must run this script from the frontend directory${NC}"
    echo "   cd whizzMerchants/frontend"
    exit 1
fi

echo "📋 Step 1: Checking dependencies..."
if ! grep -q "mapbox_search" pubspec.yaml; then
    echo -e "${YELLOW}⚠️  Adding mapbox_search dependency...${NC}"
    # Already added in pubspec.yaml
fi

if ! grep -q "flutter_dotenv" pubspec.yaml; then
    echo -e "${YELLOW}⚠️  Adding flutter_dotenv dependency...${NC}"
    # Already added in pubspec.yaml
fi

echo -e "${GREEN}✅ Dependencies configured${NC}"
echo ""

echo "📋 Step 2: Creating .env file..."
if [ ! -f ".env" ]; then
    if [ -f ".env.example" ]; then
        cp .env.example .env
        echo -e "${GREEN}✅ Created .env file from .env.example${NC}"
        echo -e "${YELLOW}⚠️  Please edit .env and add your MAPBOX_ACCESS_TOKEN${NC}"
        echo ""
        echo "   Get your token from: https://account.mapbox.com/access-tokens/"
        echo ""
    else
        echo -e "${RED}❌ Error: .env.example not found${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}⚠️  .env file already exists${NC}"
fi

# Check if .env has a real token
if grep -q "your_mapbox_public_token_here" .env 2>/dev/null; then
    echo -e "${YELLOW}⚠️  Don't forget to replace 'your_mapbox_public_token_here' with your actual token!${NC}"
fi

echo ""
echo "📋 Step 3: Updating .gitignore..."
if ! grep -q "^.env$" .gitignore 2>/dev/null; then
    echo ".env" >> .gitignore
    echo -e "${GREEN}✅ Added .env to .gitignore${NC}"
else
    echo -e "${GREEN}✅ .env already in .gitignore${NC}"
fi

echo ""
echo "📋 Step 4: Installing Flutter dependencies..."
flutter pub get

echo ""
echo "📋 Step 5: iOS Configuration..."
if [ -d "ios" ]; then
    INFO_PLIST="ios/Runner/Info.plist"
    if [ -f "$INFO_PLIST" ]; then
        if ! grep -q "NSLocationWhenInUseUsageDescription" "$INFO_PLIST"; then
            echo -e "${YELLOW}⚠️  Adding location permissions to Info.plist${NC}"
            # Backup
            cp "$INFO_PLIST" "$INFO_PLIST.bak"
            
            # Add before closing </dict>
            sed -i '' '/<\/dict>/i\
\	<key>NSLocationWhenInUseUsageDescription<\/key>\
\	<string>Your location helps us provide better address suggestions<\/string>\
\	<key>NSLocationAlwaysUsageDescription<\/key>\
\	<string>Your location helps us provide better address suggestions<\/string>
' "$INFO_PLIST"
            
            echo -e "${GREEN}✅ iOS location permissions added${NC}"
        else
            echo -e "${GREEN}✅ iOS location permissions already configured${NC}"
        fi
    fi
else
    echo -e "${YELLOW}⚠️  iOS directory not found. Run 'flutter create .' to generate iOS files${NC}"
fi

echo ""
echo "📋 Step 6: Android Configuration..."
if [ -d "android" ]; then
    MANIFEST="android/app/src/main/AndroidManifest.xml"
    if [ -f "$MANIFEST" ]; then
        if ! grep -q "ACCESS_FINE_LOCATION" "$MANIFEST"; then
            echo -e "${YELLOW}⚠️  Adding location permissions to AndroidManifest.xml${NC}"
            # Backup
            cp "$MANIFEST" "$MANIFEST.bak"
            
            # Add after <manifest> tag
            sed -i '' '/<manifest/a\
\    <uses-permission android:name="android.permission.INTERNET"/>\
\    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>\
\    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
' "$MANIFEST"
            
            echo -e "${GREEN}✅ Android location permissions added${NC}"
        else
            echo -e "${GREEN}✅ Android location permissions already configured${NC}"
        fi
    fi
else
    echo -e "${YELLOW}⚠️  Android directory not found. Run 'flutter create .' to generate Android files${NC}"
fi

echo ""
echo "=========================================================="
echo -e "${GREEN}✅ Setup Complete!${NC}"
echo ""
echo "📝 Next Steps:"
echo "   1. Get your Mapbox token from: https://account.mapbox.com/access-tokens/"
echo "      - Create a new token with SEARCH:READ and GEOCODING:READ scopes"
echo ""
echo "   2. Edit .env file and add your token:"
echo "      MAPBOX_ACCESS_TOKEN=pk.eyJ1IjoieW91cnVzZXJuYW1lIi..."
echo ""
echo "   3. Initialize in main.dart:"
echo "      await AddressAutofillService.initialize();"
echo ""
echo "   4. Test the implementation:"
echo "      flutter run"
echo ""
echo "   5. Navigate to Registration → Business Information"
echo "      Type in the address field to see suggestions!"
echo ""
echo "📚 Documentation: ADDRESS_AUTOFILL_FLUTTER_GUIDE.md"
echo ""
