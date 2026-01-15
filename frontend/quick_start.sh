#!/bin/bash

# 🚀 Quick Start Guide - WhizzMerchants App Store Preparation

echo "╔════════════════════════════════════════════════════════════╗"
echo "║  WhizzMerchants App Store Preparation - Quick Start       ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Check if we're in the right directory
if [ ! -f "pubspec.yaml" ]; then
    echo "❌ Error: Must run from Flutter project root"
    exit 1
fi

echo "📊 Phase 1: Cleanup Status"
echo "══════════════════════════════════════════════════════════════"
echo "✅ Development documentation removed (70+ files)"
echo "✅ Unused imports fixed (5 files)"
echo "✅ AppLogger utility created"
echo "✅ Info.plist enhanced"
echo "✅ .gitignore updated"
echo ""

echo "📋 Available Tools"
echo "══════════════════════════════════════════════════════════════"
echo ""
echo "1. 📄 Documentation:"
echo "   - README_APP_STORE_PREP.md ........... Main summary"
echo "   - APP_STORE_SUBMISSION_CHECKLIST.md .. Complete checklist"
echo "   - APP_STORE_CLEANUP_REPORT.md ........ Initial analysis"
echo ""
echo "2. 🛠️  Scripts:"
echo "   - prepare_app_store.sh ............... Full analysis"
echo "   - convert_prints.py .................. Auto-convert prints"
echo "   - this file (quick_start.sh) ......... This menu"
echo ""

echo "🎯 Quick Actions"
echo "══════════════════════════════════════════════════════════════"
echo ""
echo "What would you like to do?"
echo ""
echo "  1) Run full analysis"
echo "  2) Preview print statement conversion"
echo "  3) Convert print statements (LIVE)"
echo "  4) Check deprecation warnings"
echo "  5) View TODO items"
echo "  6) Clean and rebuild"
echo "  7) View summary report"
echo "  8) Exit"
echo ""
read -p "Enter choice [1-8]: " choice

case $choice in
    1)
        echo ""
        echo "🔍 Running full analysis..."
        ./prepare_app_store.sh
        ;;
    2)
        echo ""
        echo "📝 Previewing print statement conversion (dry run)..."
        python3 convert_prints.py --dry-run . | head -100
        echo ""
        echo "💡 To apply changes, run: python3 convert_prints.py ."
        ;;
    3)
        echo ""
        echo "⚠️  This will modify your Dart files!"
        read -p "Are you sure? (yes/no): " confirm
        if [ "$confirm" = "yes" ]; then
            python3 convert_prints.py .
        else
            echo "❌ Cancelled"
        fi
        ;;
    4)
        echo ""
        echo "🔍 Checking deprecation warnings..."
        flutter analyze 2>&1 | grep -i "deprecated" | head -30
        TOTAL=$(flutter analyze 2>&1 | grep -i "deprecated" | wc -l | tr -d ' ')
        echo ""
        echo "📊 Total deprecation warnings: $TOTAL"
        ;;
    5)
        echo ""
        echo "📝 TODO/FIXME items found:"
        grep -rE "TODO|FIXME" lib/ --include="*.dart" -n | head -20
        TOTAL=$(grep -rE "TODO|FIXME" lib/ --include="*.dart" | wc -l | tr -d ' ')
        echo ""
        echo "📊 Total TODO items: $TOTAL"
        ;;
    6)
        echo ""
        echo "🧹 Cleaning project..."
        flutter clean
        echo "📦 Getting dependencies..."
        flutter pub get
        echo "✅ Clean and rebuild complete"
        ;;
    7)
        echo ""
        if [ -f "README_APP_STORE_PREP.md" ]; then
            cat README_APP_STORE_PREP.md | head -100
            echo ""
            echo "... (see README_APP_STORE_PREP.md for full report)"
        else
            echo "❌ Summary report not found"
        fi
        ;;
    8)
        echo ""
        echo "👋 Goodbye!"
        exit 0
        ;;
    *)
        echo ""
        echo "❌ Invalid choice"
        exit 1
        ;;
esac

echo ""
echo "✅ Done!"
echo ""
echo "📚 For more information, read:"
echo "   - README_APP_STORE_PREP.md"
echo "   - APP_STORE_SUBMISSION_CHECKLIST.md"
echo ""
