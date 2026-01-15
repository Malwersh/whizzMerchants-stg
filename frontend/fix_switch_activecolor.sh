#!/bin/bash
# Fix Switch activeColor deprecations

echo "🔧 Fixing Switch activeColor deprecations..."

# Files to fix
files=(
  "lib/screens/dashboards/main_dashboard.dart"
  "lib/screens/edit_product_screen.dart"
  "lib/screens/notification_settings_page.dart"
  "lib/screens/pos_settings_page.dart"
  "lib/screens/products_management_screen.dart"
  "lib/screens/sound_notification_settings_page.dart"
  "lib/screens/working_hours_settings_screen.dart"
  "lib/widgets/modern_navigation_rail.dart"
  "lib/widgets/modern_sidebar.dart"
  "lib/widgets/top_app_bar.dart"
)

count=0
for file in "${files[@]}"; do
  if [ -f "$file" ]; then
    # Replace activeColor: with activeThumbColor: for Switch widgets
    # This is a safe replacement for Material Switch widgets
    sed -i '' 's/activeColor: \(WhizzColors\|Colors\)/activeThumbColor: \1/g' "$file"
    
    # Also replace trackColor: with inactiveTrackColor: if present
    sed -i '' 's/trackColor: \(WhizzColors\|Colors\)/inactiveTrackColor: \1/g' "$file"
    
    echo "✅ Fixed: $file"
    ((count++))
  fi
done

echo ""
echo "✨ Complete! Fixed $count files"
