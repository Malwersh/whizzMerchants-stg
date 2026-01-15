#!/bin/zsh
# Complete Installation Script for Mapbox Address Autofill
# WhizzMerchants Flutter App - macOS/zsh version

set -e

echo "🚀 Installing Mapbox Address Autofill - Complete Setup"
echo "========================================================="
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

FRONTEND_DIR="/Users/ghaythallaheebi/WhizzEcoSystem/whizzEcosystem/whizzMerchants/frontend"

# Check if frontend directory exists
if [ ! -d "$FRONTEND_DIR" ]; then
    echo -e "${RED}❌ Frontend directory not found: $FRONTEND_DIR${NC}"
    exit 1
fi

cd "$FRONTEND_DIR"

echo -e "${BLUE}Step 1: Installing Flutter Dependencies${NC}"
echo "----------------------------------------"
echo ""

# Check if dependencies are already in pubspec.yaml
if grep -q "mapbox_search" pubspec.yaml; then
    echo -e "${GREEN}✅ mapbox_search already in pubspec.yaml${NC}"
else
    echo -e "${YELLOW}⚠️  mapbox_search not found - please check pubspec.yaml${NC}"
fi

if grep -q "flutter_dotenv" pubspec.yaml; then
    echo -e "${GREEN}✅ flutter_dotenv already in pubspec.yaml${NC}"
else
    echo -e "${YELLOW}⚠️  flutter_dotenv not found - please check pubspec.yaml${NC}"
fi

echo ""
echo "Running flutter pub get..."
flutter pub get

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Dependencies installed successfully${NC}"
else
    echo -e "${RED}❌ Failed to install dependencies${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}Step 2: Setting up Environment File${NC}"
echo "------------------------------------"
echo ""

if [ ! -f ".env" ]; then
    if [ -f ".env.example" ]; then
        cp .env.example .env
        echo -e "${GREEN}✅ Created .env from .env.example${NC}"
        echo ""
        echo -e "${YELLOW}⚠️  IMPORTANT: Edit .env and add your Mapbox token!${NC}"
        echo ""
        echo "Get your token from: https://account.mapbox.com/access-tokens/"
        echo ""
        echo "To edit: code .env  (or use nano .env)"
        echo ""
    else
        echo -e "${YELLOW}Creating .env file...${NC}"
        cat > .env << 'EOF'
# Mapbox Access Token
# Get from: https://account.mapbox.com/access-tokens/
MAPBOX_ACCESS_TOKEN=your_mapbox_public_token_here
EOF
        echo -e "${GREEN}✅ Created .env file${NC}"
        echo -e "${YELLOW}⚠️  Please edit .env and add your Mapbox token!${NC}"
    fi
else
    echo -e "${GREEN}✅ .env file already exists${NC}"
    
    # Check if token is set
    if grep -q "your_mapbox_public_token_here" .env; then
        echo -e "${YELLOW}⚠️  Warning: Mapbox token not configured${NC}"
        echo "   Edit .env and replace 'your_mapbox_public_token_here'"
    fi
fi

echo ""
echo -e "${BLUE}Step 3: Updating .gitignore${NC}"
echo "----------------------------"
echo ""

if [ ! -f ".gitignore" ]; then
    echo ".env" > .gitignore
    echo -e "${GREEN}✅ Created .gitignore with .env${NC}"
else
    if ! grep -q "^\.env$" .gitignore; then
        echo ".env" >> .gitignore
        echo -e "${GREEN}✅ Added .env to .gitignore${NC}"
    else
        echo -e "${GREEN}✅ .env already in .gitignore${NC}"
    fi
fi

echo ""
echo -e "${BLUE}Step 4: iOS Configuration${NC}"
echo "-------------------------"
echo ""

if [ -d "ios" ]; then
    INFO_PLIST="ios/Runner/Info.plist"
    if [ -f "$INFO_PLIST" ]; then
        if ! grep -q "NSLocationWhenInUseUsageDescription" "$INFO_PLIST"; then
            echo -e "${YELLOW}Adding location permissions to Info.plist...${NC}"
            
            # Create backup
            cp "$INFO_PLIST" "$INFO_PLIST.bak"
            
            # Use perl for cross-platform sed-like editing
            perl -i -pe 's|</dict>\s*</plist>|	<key>NSLocationWhenInUseUsageDescription</key>\n	<string>Your location helps us provide better address suggestions</string>\n	<key>NSLocationAlwaysUsageDescription</key>\n	<string>Your location helps us provide better address suggestions</string>\n</dict>\n</plist>|' "$INFO_PLIST"
            
            echo -e "${GREEN}✅ iOS location permissions added${NC}"
        else
            echo -e "${GREEN}✅ iOS already configured${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  Info.plist not found${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  iOS directory not found${NC}"
    echo "   Run: flutter create . (to generate platform files)"
fi

echo ""
echo -e "${BLUE}Step 5: Android Configuration${NC}"
echo "-----------------------------"
echo ""

if [ -d "android" ]; then
    MANIFEST="android/app/src/main/AndroidManifest.xml"
    if [ -f "$MANIFEST" ]; then
        if ! grep -q "ACCESS_FINE_LOCATION" "$MANIFEST"; then
            echo -e "${YELLOW}Adding location permissions to AndroidManifest.xml...${NC}"
            
            # Create backup
            cp "$MANIFEST" "$MANIFEST.bak"
            
            # Add permissions after <manifest> tag
            perl -i -pe 's|(<manifest[^>]*>)|$1\n    <uses-permission android:name="android.permission.INTERNET"/>\n    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>\n    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>|' "$MANIFEST"
            
            echo -e "${GREEN}✅ Android location permissions added${NC}"
        else
            echo -e "${GREEN}✅ Android already configured${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  AndroidManifest.xml not found${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  Android directory not found${NC}"
    echo "   Run: flutter create . (to generate platform files)"
fi

echo ""
echo -e "${BLUE}Step 6: Verifying Files${NC}"
echo "----------------------"
echo ""

# Check service file
if [ -f "lib/services/address_autofill_service.dart" ]; then
    echo -e "${GREEN}✅ Service file exists${NC}"
else
    echo -e "${RED}❌ Service file missing${NC}"
fi

# Check widget file
if [ -f "lib/widgets/address_autofill_field.dart" ]; then
    echo -e "${GREEN}✅ Widget file exists${NC}"
else
    echo -e "${RED}❌ Widget file missing${NC}"
fi

echo ""
echo "================================================================"
echo -e "${GREEN}✅ Installation Complete!${NC}"
echo "================================================================"
echo ""
echo -e "${BLUE}📝 Next Steps:${NC}"
echo ""
echo "1️⃣  Get your Mapbox token:"
echo "   https://account.mapbox.com/access-tokens/"
echo "   - Create token with SEARCH:READ + GEOCODING:READ scopes"
echo ""
echo "2️⃣  Edit .env file and add your token:"
echo "   ${YELLOW}code .env${NC}  (or: nano .env)"
echo ""
echo "3️⃣  Add initialization to main.dart:"
echo "   See: lib/examples/address_autofill_integration_example.dart"
echo ""
echo "4️⃣  Test the implementation:"
echo "   ${YELLOW}flutter run${NC}"
echo ""
echo "5️⃣  Navigate to: Register → Business Information"
echo "   Type in address field to see suggestions!"
echo ""
echo "📚 Documentation:"
echo "   - Quick Start: ../QUICK_START_ADDRESS_AUTOFILL.md"
echo "   - Full Guide: ../ADDRESS_AUTOFILL_FLUTTER_GUIDE.md"
echo "   - Checklist: ../ADDRESS_AUTOFILL_CHECKLIST.md"
echo ""
echo "🧪 Testing:"
echo "   ${YELLOW}./test_address_autofill.sh${NC}"
echo ""
