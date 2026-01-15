#!/usr/bin/env python3
"""
Fix Missing AppLogger Imports
Adds AppLogger import to files that use it but don't import it.
"""

import subprocess
import re
from pathlib import Path

def get_files_needing_applogger():
    """Get list of files with AppLogger errors."""
    result = subprocess.run(
        ['flutter', 'analyze'],
        capture_output=True,
        text=True,
        cwd='.'
    )
    
    files_with_errors = set()
    for line in result.stdout.split('\n'):
        if "Undefined name 'AppLogger'" in line:
            # Extract file path
            match = re.search(r'• ([^ ]+\.dart):', line)
            if match:
                files_with_errors.add(match.group(1))
    
    return list(files_with_errors)

def add_applogger_import(filepath):
    """Add AppLogger import to a file if it doesn't already have it."""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Check if already imported
        if "app_logger.dart" in content or "AppLogger" not in content:
            return False
        
        # Find the right place to add the import
        lines = content.split('\n')
        
        # Find last import line
        last_import_idx = -1
        for i, line in enumerate(lines):
            if line.strip().startswith('import '):
                last_import_idx = i
        
        if last_import_idx == -1:
            return False
        
        # Determine the correct relative path
        # Count ../ needed based on depth
        depth = filepath.count('/') - 1  # -1 for lib/
        if 'lib/' in filepath:
            depth = filepath.split('lib/')[1].count('/')
        
        relative_path = '../' * depth + 'core/utils/app_logger.dart'
        import_line = f"import '{relative_path}';"
        
        # Insert after last import
        lines.insert(last_import_idx + 1, import_line)
        
        # Write back
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write('\n'.join(lines))
        
        return True
        
    except Exception as e:
        print(f"Error processing {filepath}: {e}")
        return False

def main():
    files = get_files_needing_applogger()
    
    if not files:
        print("✨ No files need AppLogger import!")
        return
    
    print(f"🔍 Found {len(files)} files needing AppLogger import:")
    
    fixed = 0
    for filepath in files:
        if add_applogger_import(filepath):
            print(f"✅ {filepath}")
            fixed += 1
        else:
            print(f"⚠️  Skipped {filepath}")
    
    print(f"\n✨ Fixed {fixed}/{len(files)} files")

if __name__ == '__main__':
    main()
