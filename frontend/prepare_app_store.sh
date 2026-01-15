#!/bin/bash

# WhizzMerchants App Store Preparation Script
# This script helps prepare the app for App Store submission

set -e

echo "🚀 WhizzMerchants App Store Preparation"
echo "========================================"
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Step 1: Clean Flutter project
echo "📦 Step 1: Cleaning Flutter project..."
flutter clean
echo -e "${GREEN}✓ Project cleaned${NC}"
echo ""

# Step 2: Get dependencies
echo "📦 Step 2: Getting dependencies..."
flutter pub get
echo -e "${GREEN}✓ Dependencies updated${NC}"
echo ""

# Step 3: Run code analysis
echo "🔍 Step 3: Running code analysis..."
flutter analyze > analysis_output.txt 2>&1 || true
cat analysis_output.txt
echo -e "${YELLOW}⚠️  Analysis complete - review analysis_output.txt${NC}"
echo ""

# Step 4: Check for print statements
echo "🔍 Step 4: Checking for print statements..."
PRINT_COUNT=$(grep -r "print(" lib/ --include="*.dart" | wc -l | tr -d ' ')
echo -e "${YELLOW}Found $PRINT_COUNT print statements${NC}"
echo "Consider replacing with AppLogger for production builds"
echo ""

# Step 5: Check for DEBUG comments
echo "🔍 Step 5: Checking for DEBUG comments..."
DEBUG_COUNT=$(grep -r "DEBUG" lib/ --include="*.dart" | wc -l | tr -d ' ')
echo -e "${YELLOW}Found $DEBUG_COUNT DEBUG comments${NC}"
echo "Consider removing or replacing with proper logging"
echo ""

# Step 6: Check for TODO comments
echo "🔍 Step 6: Checking for TODO/FIXME comments..."
TODO_COUNT=$(grep -rE "TODO|FIXME" lib/ --include="*.dart" | wc -l | tr -d ' ')
echo -e "${YELLOW}Found $TODO_COUNT TODO/FIXME comments${NC}"
echo ""

# Step 7: Check dependencies
echo "📦 Step 7: Checking for outdated dependencies..."
flutter pub outdated > outdated_packages.txt 2>&1 || true
echo -e "${GREEN}✓ Dependency check complete - see outdated_packages.txt${NC}"
echo ""

# Step 8: Run tests
echo "🧪 Step 8: Running tests..."
if flutter test 2>&1 | tee test_output.txt; then
    echo -e "${GREEN}✓ All tests passed${NC}"
else
    echo -e "${RED}⚠️  Some tests failed - review test_output.txt${NC}"
fi
echo ""

# Step 9: Build iOS release (dry run)
echo "🏗️  Step 9: Testing iOS release build..."
if flutter build ios --release --no-codesign 2>&1 | tee build_output.txt; then
    echo -e "${GREEN}✓ iOS release build successful${NC}"
else
    echo -e "${RED}✗ iOS release build failed - review build_output.txt${NC}"
fi
echo ""

# Step 10: Generate summary
echo "📊 Generating summary report..."
cat > CLEANUP_SUMMARY.txt << EOF
WhizzMerchants App Store Preparation Summary
=============================================
Date: $(date)

Analysis Results:
- Print statements found: $PRINT_COUNT
- DEBUG comments found: $DEBUG_COUNT
- TODO/FIXME comments found: $TODO_COUNT

Files Generated:
- analysis_output.txt: Flutter analyze results
- outdated_packages.txt: Dependency update information
- test_output.txt: Test results
- build_output.txt: iOS build results

Next Steps:
1. Review and fix all issues in analysis_output.txt
2. Replace print() statements with AppLogger
3. Remove or address all DEBUG comments
4. Complete all TODO items or remove them
5. Update outdated dependencies (test after each update)
6. Add app icons and launch screens
7. Configure code signing
8. Test on physical iOS devices
9. Prepare App Store Connect metadata
10. Submit for review

EOF

echo -e "${GREEN}✓ Summary report generated: CLEANUP_SUMMARY.txt${NC}"
echo ""

echo "🎉 Preparation script complete!"
echo ""
echo "Next steps:"
echo "1. Review all generated .txt files"
echo "2. Address the issues found"
echo "3. Run this script again to verify fixes"
echo "4. Proceed with App Store submission checklist"
