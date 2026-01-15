#!/usr/bin/env python3
"""
Automated script to fix withOpacity() deprecations in Flutter code.
Replaces .withOpacity(value) with .withValues(alpha: value)
"""

import os
import re
import sys
from pathlib import Path

def fix_with_opacity_in_file(file_path):
    """Fix withOpacity calls in a single file."""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        original_content = content
        
        # Pattern to match .withOpacity(numeric_value)
        # Handles: .withOpacity(0.5), .withOpacity(0.7), etc.
        pattern = r'\.withOpacity\((\d+\.?\d*)\)'
        replacement = r'.withValues(alpha: \1)'
        
        content = re.sub(pattern, replacement, content)
        
        if content != original_content:
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(content)
            
            # Count replacements
            count = len(re.findall(pattern, original_content))
            return count
        
        return 0
        
    except Exception as e:
        print(f"Error processing {file_path}: {e}", file=sys.stderr)
        return 0

def main():
    """Main function to process all Dart files."""
    lib_dir = Path('lib')
    
    if not lib_dir.exists():
        print("Error: lib/ directory not found. Run this script from the Flutter project root.")
        sys.exit(1)
    
    print("🔧 Fixing withOpacity() deprecations...")
    print("=" * 60)
    
    total_files = 0
    total_fixes = 0
    
    # Process all .dart files
    for dart_file in lib_dir.rglob('*.dart'):
        fixes_in_file = fix_with_opacity_in_file(dart_file)
        if fixes_in_file > 0:
            total_files += 1
            total_fixes += fixes_in_file
            print(f"✅ {dart_file}: {fixes_in_file} fixes")
    
    print("=" * 60)
    print(f"✨ Complete! Fixed {total_fixes} occurrences in {total_files} files")
    
    if total_fixes > 0:
        print("\n💡 Next steps:")
        print("   1. Run: flutter analyze")
        print("   2. Verify no compilation errors")
        print("   3. Test the app")

if __name__ == '__main__':
    main()
