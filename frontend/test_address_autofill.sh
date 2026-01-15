#!/bin/bash
# Test script for Mapbox Address Autofill
# This script helps verify the implementation is working correctly

set -e

echo "🧪 Testing Mapbox Address Autofill Implementation"
echo "=================================================="
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if we're in the right directory
if [ ! -f "pubspec.yaml" ]; then
    echo -e "${RED}❌ Error: Must run from frontend directory${NC}"
    exit 1
fi

echo -e "${BLUE}📋 Pre-flight Checks${NC}"
echo "-------------------"

# Check 1: Dependencies
echo -n "1. Checking dependencies... "
if grep -q "mapbox_search" pubspec.yaml && grep -q "flutter_dotenv" pubspec.yaml; then
    echo -e "${GREEN}✅${NC}"
else
    echo -e "${RED}❌ Missing dependencies${NC}"
    echo "   Run: flutter pub get"
    exit 1
fi

# Check 2: .env file
echo -n "2. Checking .env file... "
if [ -f ".env" ]; then
    echo -e "${GREEN}✅${NC}"
    
    # Check if token is set
    if grep -q "your_mapbox_public_token_here" .env; then
        echo -e "${YELLOW}   ⚠️  Warning: Mapbox token not set${NC}"
        echo "   Edit .env and add your token from: https://account.mapbox.com/access-tokens/"
    fi
else
    echo -e "${RED}❌ Missing .env file${NC}"
    echo "   Run: cp .env.example .env"
    exit 1
fi

# Check 3: Service file
echo -n "3. Checking service file... "
if [ -f "lib/services/address_autofill_service.dart" ]; then
    echo -e "${GREEN}✅${NC}"
else
    echo -e "${RED}❌ Missing service file${NC}"
    exit 1
fi

# Check 4: Widget file
echo -n "4. Checking widget file... "
if [ -f "lib/widgets/address_autofill_field.dart" ]; then
    echo -e "${GREEN}✅${NC}"
else
    echo -e "${RED}❌ Missing widget file${NC}"
    exit 1
fi

# Check 5: iOS configuration
echo -n "5. Checking iOS config... "
if [ -f "ios/Runner/Info.plist" ]; then
    if grep -q "NSLocationWhenInUseUsageDescription" ios/Runner/Info.plist; then
        echo -e "${GREEN}✅${NC}"
    else
        echo -e "${YELLOW}⚠️  Missing location permissions${NC}"
        echo "   Run: ./setup_address_autofill.sh"
    fi
else
    echo -e "${YELLOW}⚠️  iOS directory not found${NC}"
fi

# Check 6: Android configuration
echo -n "6. Checking Android config... "
if [ -f "android/app/src/main/AndroidManifest.xml" ]; then
    if grep -q "ACCESS_FINE_LOCATION" android/app/src/main/AndroidManifest.xml; then
        echo -e "${GREEN}✅${NC}"
    else
        echo -e "${YELLOW}⚠️  Missing location permissions${NC}"
        echo "   Run: ./setup_address_autofill.sh"
    fi
else
    echo -e "${YELLOW}⚠️  Android directory not found${NC}"
fi

echo ""
echo -e "${BLUE}📝 Test Checklist${NC}"
echo "----------------"
echo ""
echo "To test the implementation:"
echo ""
echo "1. ${GREEN}Start the app:${NC}"
echo "   flutter run"
echo ""
echo "2. ${GREEN}Navigate to:${NC}"
echo "   Register → User Info → Next → Business Information"
echo ""
echo "3. ${GREEN}Test address field with these queries:${NC}"
echo ""

test_queries=(
    "Baghdad|Baghdad city and districts"
    "Al-Karrada|Karrada neighborhood"
    "Najaf|Najaf city"
    "Basra|Basra governorate"
    "Erbil|Erbil/Arbil"
    "Al-Rasheed|Famous street in Baghdad"
)

for query in "${test_queries[@]}"; do
    IFS='|' read -r search expected <<< "$query"
    echo "   ✓ Type: '${BLUE}$search${NC}'"
    echo "     Expected: $expected"
    echo ""
done

echo "4. ${GREEN}Verify behavior:${NC}"
echo "   [ ] Suggestions appear after 3 characters"
echo "   [ ] Loading spinner shows during search"
echo "   [ ] Dropdown is styled with icons"
echo "   [ ] Selecting suggestion fills the field"
echo "   [ ] Address details shown below field"
echo "   [ ] GPS coordinates extracted"
echo "   [ ] Success message appears"
echo ""

echo "5. ${GREEN}Check console logs:${NC}"
echo "   [ ] '✅ AddressAutofill: Initialized successfully'"
echo "   [ ] '🔍 AddressAutofill: Searching for: \"...\""
echo "   [ ] '✅ AddressAutofill: Found N suggestions'"
echo "   [ ] '📍 AddressAutofill: Extracted components:'"
echo ""

echo -e "${BLUE}🐛 Troubleshooting${NC}"
echo "-----------------"
echo ""
echo "If suggestions don't appear:"
echo "1. Check Mapbox token in .env"
echo "2. Verify token at: https://account.mapbox.com/access-tokens/"
echo "3. Ensure token has SEARCH:READ scope"
echo "4. Check internet connection"
echo "5. Run: flutter clean && flutter pub get"
echo ""

echo -e "${BLUE}📊 Expected Console Output${NC}"
echo "-------------------------"
echo ""
echo -e "${GREEN}On app start:${NC}"
echo "✅ AddressAutofill: Initialized successfully"
echo ""
echo -e "${GREEN}When typing 'Baghdad':${NC}"
echo "🔍 AddressAutofill: Searching for: \"Baghdad\""
echo "✅ AddressAutofill: Found 5 suggestions"
echo ""
echo -e "${GREEN}When selecting a suggestion:${NC}"
echo "📍 AddressAutofill: Extracted components:"
echo "   Street: Al-Mutanabbi Street"
echo "   Neighborhood: Karrada"
echo "   District: Rusafa"
echo "   City: Baghdad"
echo "   Governorate: Baghdad"
echo "   Coordinates: 33.3152, 44.3661"
echo ""

echo -e "${BLUE}🎯 Success Criteria${NC}"
echo "------------------"
echo ""
echo "✅ Implementation is successful if:"
echo "   1. App starts without errors"
echo "   2. Address field shows autofill functionality"
echo "   3. Suggestions appear for Iraqi locations"
echo "   4. Selecting fills field with address"
echo "   5. GPS coordinates are extracted"
echo "   6. Works on both iOS and Android"
echo ""

echo -e "${GREEN}=================================================="
echo "Ready to test! Run: flutter run"
echo "==================================================${NC}"
echo ""

# Optional: Offer to run the app
read -p "Would you like to run the app now? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "🚀 Starting Flutter app..."
    flutter run
fi
