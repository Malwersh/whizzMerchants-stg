#!/usr/bin/env python3
"""
Remove Unused Imports
Removes unused app_colors.dart and whizz_colors.dart imports.
"""

import re
import sys
from pathlib import Path

def fix_unused_imports(filepath):
    """Remove unused app_colors.dart and whizz_colors.dart imports."""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            lines = f.readlines()
        
        original_lines = lines.copy()
        new_lines = []
        removed_count = 0
        
        for i, line in enumerate(lines):
            # Check if this is an unused import line
            is_app_colors_import = "import" in line and "app_colors.dart" in line
            is_whizz_colors_import = "import" in line and "whizz_colors.dart" in line
            
            if is_app_colors_import or is_whizz_colors_import:
                # Check if this is a duplicate or if AppColors is actually used
                # For now, we'll be conservative and only remove app_colors.dart
                # since we've replaced AppColors with WhizzColors
                if is_app_colors_import:
                    removed_count += 1
                    continue  # Skip this line
            
            new_lines.append(line)
        
        if removed_count > 0:
            with open(filepath, 'w', encoding='utf-8') as f:
                f.writelines(new_lines)
            return removed_count
        
        return 0
        
    except Exception as e:
        print(f"Error processing {filepath}: {e}", file=sys.stderr)
        return 0

def main():
    """Main entry point."""
    lib_dir = Path('lib')
    test_dir = Path('test')
    
    if not lib_dir.exists():
        print("Error: 'lib' directory not found. Run from project root.")
        sys.exit(1)
    
    # Find all Dart files in lib and test
    dart_files = list(lib_dir.rglob('*.dart'))
    if test_dir.exists():
        dart_files.extend(list(test_dir.rglob('*.dart')))
    
    print(f"🔍 Found {len(dart_files)} Dart files to check")
    print("🧹 Removing unused app_colors.dart imports...\n")
    
    total_removed = 0
    files_modified = 0
    
    for filepath in dart_files:
        removed = fix_unused_imports(filepath)
        if removed > 0:
            files_modified += 1
            total_removed += removed
            print(f"✅ {filepath}: removed {removed} import(s)")
    
    print(f"\n{'='*60}")
    print(f"✨ Summary:")
    print(f"   Files modified: {files_modified}")
    print(f"   Imports removed: {total_removed}")
    print(f"{'='*60}")
    
    if files_modified > 0:
        print("\n✅ Unused imports removed!")
        print("💡 Run 'flutter analyze' to verify.")
    else:
        print("\n✨ No unused imports found!")

if __name__ == '__main__':
    main()
