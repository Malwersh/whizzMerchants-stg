#!/usr/bin/env python3
"""
Print Statement Converter
Converts print() statements to AppLogger calls for production-ready code.
"""

import re
import os
import sys
from pathlib import Path

# Mapping of emoji prefixes to AppLogger methods
EMOJI_MAP = {
    '✅': 'success',
    '❌': 'error',
    '⚠️': 'warning',
    '🔍': 'debug',
    '🌐': 'api',
    '💥': 'error',
    '🔄': 'info',
    '📦': 'info',
    '📥': 'info',
    '📊': 'debug',
    '🏷️': 'debug',
    'ℹ️': 'info',
}

def detect_logger_type(content):
    """Detect appropriate logger type based on content."""
    content_lower = content.lower()
    
    # Check for emoji first
    for emoji, log_type in EMOJI_MAP.items():
        if emoji in content:
            return log_type
    
    # Check for keywords
    if any(word in content_lower for word in ['error', 'failed', 'exception']):
        return 'error'
    elif any(word in content_lower for word in ['warning', 'warn']):
        return 'warning'
    elif any(word in content_lower for word in ['debug', 'trace']):
        return 'debug'
    elif any(word in content_lower for word in ['api', 'http', 'request', 'response']):
        return 'api'
    elif any(word in content_lower for word in ['success', 'complete', 'done']):
        return 'success'
    else:
        return 'info'

def clean_message(message):
    """Remove emoji prefixes and clean up the message."""
    # Remove leading emoji and spaces
    for emoji in EMOJI_MAP.keys():
        message = message.replace(emoji, '').strip()
    
    # Remove common DEBUG prefixes
    message = re.sub(r'^DEBUG[:\s]+', '', message, flags=re.IGNORECASE)
    
    return message.strip()

def convert_print_to_logger(line):
    """Convert a print statement to AppLogger call."""
    # Match print('...') or print("...")
    match = re.match(r'(\s*)print\(([\'"])(.+?)\2\);?\s*$', line)
    if not match:
        return line
    
    indent = match.group(1)
    message = match.group(3)
    
    # Detect logger type
    log_type = detect_logger_type(message)
    
    # Clean message
    cleaned_message = clean_message(message)
    
    # Handle string interpolation
    if '$' in cleaned_message:
        # Convert to proper string interpolation
        new_line = f"{indent}AppLogger.{log_type}('{cleaned_message}');\n"
    else:
        new_line = f"{indent}AppLogger.{log_type}('{cleaned_message}');\n"
    
    return new_line

def needs_import(content):
    """Check if file needs AppLogger import."""
    return 'import' in content and 'AppLogger' not in content

def add_import(content):
    """Add AppLogger import to file."""
    lines = content.split('\n')
    
    # Find the last import statement
    last_import_idx = -1
    for i, line in enumerate(lines):
        if line.strip().startswith('import '):
            last_import_idx = i
    
    if last_import_idx >= 0:
        # Add after last import
        lines.insert(last_import_idx + 1, "import '../core/utils/app_logger.dart';")
    else:
        # Add at the beginning after any comments
        insert_idx = 0
        for i, line in enumerate(lines):
            if not line.strip().startswith('//') and line.strip():
                insert_idx = i
                break
        lines.insert(insert_idx, "import '../core/utils/app_logger.dart';")
    
    return '\n'.join(lines)

def process_file(file_path, dry_run=True):
    """Process a single Dart file."""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        original_content = content
        lines = content.split('\n')
        modified = False
        
        # Convert print statements
        new_lines = []
        for line in lines:
            if 'print(' in line and not line.strip().startswith('//'):
                new_line = convert_print_to_logger(line)
                new_lines.append(new_line)
                if new_line != line:
                    modified = True
                    print(f"  - {line.strip()}")
                    print(f"  + {new_line.strip()}")
            else:
                new_lines.append(line)
        
        if modified:
            new_content = '\n'.join(new_lines)
            
            # Add import if needed
            if needs_import(new_content) and 'AppLogger' in new_content:
                new_content = add_import(new_content)
                print(f"  + Added AppLogger import")
            
            if not dry_run:
                with open(file_path, 'w', encoding='utf-8') as f:
                    f.write(new_content)
                print(f"✅ Modified: {file_path}")
            else:
                print(f"📝 Would modify: {file_path}")
            
            return True
        
        return False
    
    except Exception as e:
        print(f"❌ Error processing {file_path}: {e}")
        return False

def find_dart_files(directory):
    """Find all Dart files with print statements."""
    dart_files = []
    lib_path = Path(directory) / 'lib'
    
    for dart_file in lib_path.rglob('*.dart'):
        with open(dart_file, 'r', encoding='utf-8') as f:
            content = f.read()
            if 'print(' in content:
                # Count prints
                count = content.count('print(')
                dart_files.append((str(dart_file), count))
    
    return sorted(dart_files, key=lambda x: x[1], reverse=True)

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 convert_prints.py [--dry-run] <directory>")
        print("       python3 convert_prints.py <file.dart>")
        sys.exit(1)
    
    dry_run = '--dry-run' in sys.argv
    path_arg = sys.argv[-1]
    
    if os.path.isfile(path_arg):
        # Process single file
        print(f"\n🔄 Processing {path_arg}...")
        process_file(path_arg, dry_run)
    elif os.path.isdir(path_arg):
        # Process directory
        print(f"\n🔍 Scanning {path_arg} for Dart files with print statements...")
        files = find_dart_files(path_arg)
        
        if not files:
            print("✅ No files with print statements found!")
            return
        
        print(f"\n📋 Found {len(files)} files with print statements:")
        for file_path, count in files:
            rel_path = os.path.relpath(file_path, path_arg)
            print(f"  - {rel_path} ({count} prints)")
        
        print(f"\n{'🧪 DRY RUN MODE - No files will be modified' if dry_run else '⚠️  LIVE MODE - Files will be modified'}")
        
        if not dry_run:
            response = input("\nProceed with conversion? (yes/no): ")
            if response.lower() not in ['yes', 'y']:
                print("❌ Cancelled")
                return
        
        print("\n🔄 Processing files...\n")
        modified_count = 0
        
        for file_path, _ in files:
            if process_file(file_path, dry_run):
                modified_count += 1
            print()
        
        print(f"\n{'📝 Would modify' if dry_run else '✅ Modified'} {modified_count} files")
        
        if dry_run:
            print("\n💡 Run without --dry-run to apply changes")
    else:
        print(f"❌ Invalid path: {path_arg}")
        sys.exit(1)

if __name__ == '__main__':
    main()
