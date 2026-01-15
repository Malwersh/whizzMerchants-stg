#!/bin/zsh

echo "🔄 Restarting Flutter App with Login Persistence Fix..."
echo ""

# Step 1: Kill all Flutter processes
echo "1️⃣ Stopping all Flutter processes..."
pkill -9 -f "flutter_tools.snapshot run" 2>/dev/null
pkill -9 -f "dart.*frontend_server" 2>/dev/null
pkill -9 flutter 2>/dev/null
pkill -9 dart 2>/dev/null
sleep 2
echo "   ✅ Flutter processes stopped"
echo ""

# Step 2: Clean build
echo "2️⃣ Cleaning build cache..."
cd /Users/ghaythallaheebi/WhizzEcoSystem/whizzEcosystem/whizzMerchants/frontend
flutter clean > /dev/null 2>&1
echo "   ✅ Build cache cleaned"
echo ""

# Step 3: Get dependencies
echo "3️⃣ Getting dependencies..."
flutter pub get
echo "   ✅ Dependencies updated"
echo ""

# Step 4: Check available devices
echo "4️⃣ Checking available devices..."
flutter devices
echo ""

# Step 5: Ask user which device to run on
echo "5️⃣ Select a device to run the app:"
echo "   1) Chrome (Web)"
echo "   2) iOS Simulator"
echo "   3) Android Emulator"
echo "   4) macOS Desktop"
echo ""
read "choice?Enter your choice (1-4): "

case $choice in
    1)
        echo ""
        echo "🚀 Starting Flutter app in Chrome..."
        echo "   Watch for login persistence logs:"
        echo "   - 'Storing authentication tokens...'"
        echo "   - 'All authentication tokens stored successfully'"
        echo "   - 'Checking for stored session...'"
        echo "   - 'Session restored successfully'"
        echo ""
        flutter run -d chrome
        ;;
    2)
        echo ""
        echo "🚀 Starting Flutter app in iOS Simulator..."
        flutter run -d ios
        ;;
    3)
        echo ""
        echo "🚀 Starting Flutter app in Android Emulator..."
        flutter run -d android
        ;;
    4)
        echo ""
        echo "🚀 Starting Flutter app on macOS..."
        flutter run -d macos
        ;;
    *)
        echo ""
        echo "❌ Invalid choice. Starting in Chrome by default..."
        flutter run -d chrome
        ;;
esac
