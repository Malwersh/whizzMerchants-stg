#!/bin/zsh

# Quick Flutter Restart Script for WhizzMerchants
# Applies the Settings Screen Text Visibility Fix

echo "🔄 Flutter App Restart"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

cd /Users/ghaythallaheebi/WhizzEcoSystem/whizzEcosystem/whizzMerchants/frontend

# Check if Flutter is already running
FLUTTER_PROCESS=$(ps aux | grep "flutter run" | grep -v grep)

if [ ! -z "$FLUTTER_PROCESS" ]; then
    echo "✅ Flutter is already running!"
    echo ""
    echo "📝 Quick Actions:"
    echo "   R - Hot restart (applies all code changes)"
    echo "   r - Hot reload (applies UI changes only)"
    echo "   q - Quit the app"
    echo ""
    echo "💡 TIP: Press 'R' in your Flutter terminal to restart"
    echo ""
    exit 0
fi

# Start Flutter
echo "🚀 Starting Flutter app..."
echo ""
echo "📱 After app launches, test the fix:"
echo "   1. Open Settings tab (5th icon, bottom navigation)"
echo "   2. Verify all text is visible:"
echo "      ✓ Account Settings"
echo "      ✓ Change Password"
echo "      ✓ Language Settings"
echo "      ✓ POS Settings"
echo "      ✓ Location Settings"
echo "      ✓ GPS Settings"
echo "      ✓ Working Hours Settings"
echo "      ✓ About App"
echo "      ✓ Logout button"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

flutter run
