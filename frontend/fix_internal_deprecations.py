#!/usr/bin/env python3
"""
Fix Internal Deprecation Warnings
Replaces deprecated color names with their modern equivalents.

Replacements:
- brandBluePrimary → secondary
- brandBlueDark → secondary
- brandYellow → primary
- brandYellowAlt → primary
- AppColors → WhizzColors
"""

import re
import os
import sys
from pathlib import Path

# Replacement mappings
REPLACEMENTS = [
    # Brand color deprecations (WhizzColors.X → WhizzColors.Y)
    (r'\bWhizzColors\.brandBluePrimary\b', 'WhizzColors.secondary'),
    (r'\bWhizzColors\.brandBlueDark\b', 'WhizzColors.secondary'),
    (r'\bWhizzColors\.brandBlueMedium\b', 'WhizzColors.secondary'),
    (r'\bWhizzColors\.brandYellow\b', 'WhizzColors.primary'),
    (r'\bWhizzColors\.brandYellowAlt\b', 'WhizzColors.primary'),
    
    # AppColors deprecation (AppColors → WhizzColors)
    (r'\bAppColors\b', 'WhizzColors'),
]

def fix_file(filepath):
    """Fix deprecations in a single file."""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
        
        original_content = content
        changes_made = 0
        
        # Apply all replacements
        for pattern, replacement in REPLACEMENTS:
            matches = len(re.findall(pattern, content))
            if matches > 0:
                changes_made += matches
                content = re.sub(pattern, replacement, content)
        
        # Only write if changes were made
        if content != original_content:
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(content)
            return changes_made
        
        return 0
        
    except Exception as e:
        print(f"Error processing {filepath}: {e}", file=sys.stderr)
        return 0

def main():
    """Main entry point."""
    lib_dir = Path('lib')
    
    if not lib_dir.exists():
        print("Error: 'lib' directory not found. Run from project root.")
        sys.exit(1)
    
    # Find all Dart files
    dart_files = list(lib_dir.rglob('*.dart'))
    
    # Exclude generated files and theme files that define these colors
    exclude_patterns = [
        'app_colors.dart',
        'whizz_colors.dart',
        '*.g.dart',
        '*.freezed.dart',
    ]
    
    dart_files = [
        f for f in dart_files 
        if not any(pattern.replace('*', '') in str(f) for pattern in exclude_patterns)
    ]
    
    print(f"🔍 Found {len(dart_files)} Dart files to check")
    print("🔧 Fixing internal deprecations...\n")
    
    total_changes = 0
    files_modified = 0
    
    for filepath in dart_files:
        changes = fix_file(filepath)
        if changes > 0:
            files_modified += 1
            total_changes += changes
            print(f"✅ {filepath.relative_to(lib_dir)}: {changes} changes")
    
    print(f"\n{'='*60}")
    print(f"✨ Summary:")
    print(f"   Files modified: {files_modified}")
    print(f"   Total changes: {total_changes}")
    print(f"{'='*60}")
    
    if files_modified > 0:
        print("\n✅ Internal deprecations fixed!")
        print("💡 Run 'flutter analyze' to verify.")
    else:
        print("\n✨ No internal deprecations found!")

if __name__ == '__main__':
    main()
