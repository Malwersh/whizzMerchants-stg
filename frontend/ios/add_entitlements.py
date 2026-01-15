#!/usr/bin/env python3
"""
Script to add Runner.entitlements to Xcode project
"""

import sys

def add_entitlements_to_project():
    project_file = 'Runner.xcodeproj/project.pbxproj'
    
    # Read the project file
    with open(project_file, 'r') as f:
        lines = f.readlines()
    
    # UUID for the entitlements file reference
    file_ref_uuid = 'E7F2A4B1C9D3E5F7A1B2C3D4'
    
    modified = False
    
    # Process line by line
    for i, line in enumerate(lines):
        # 1. Add to PBXFileReference section (after the first file reference)
        if '/* Begin PBXFileReference section */' in line and file_ref_uuid not in ''.join(lines):
            lines.insert(i + 1, f'\t\t{file_ref_uuid} /* Runner.entitlements */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = Runner.entitlements; sourceTree = "<group>"; }};\n')
            modified = True
            print("✅ Added to PBXFileReference section")
            continue
        
        # 2. Add to Runner group children (look for the Runner group)
        if '97C146F01CF9000F007C117D /* Runner */ = {' in line:
            # Find the children array
            j = i
            while j < len(lines) and 'children = (' not in lines[j]:
                j += 1
            # Find the closing of children array
            while j < len(lines) and ');' not in lines[j]:
                j += 1
            # Insert before the closing
            if file_ref_uuid not in ''.join(lines[i:j]):
                lines.insert(j, f'\t\t\t\t{file_ref_uuid} /* Runner.entitlements */,\n')
                modified = True
                print("✅ Added to Runner group children")
        
        # 3. Add CODE_SIGN_ENTITLEMENTS to all build configurations
        if 'buildSettings = {' in line and i > 0:
            # Check if this is a configuration section
            prev_lines = ''.join(lines[max(0, i-10):i])
            if ('Debug' in prev_lines or 'Release' in prev_lines or 'Profile' in prev_lines) and 'CODE_SIGN_ENTITLEMENTS' not in ''.join(lines[i:min(i+30, len(lines))]):
                # Find where to insert (after buildSettings = {)
                j = i + 1
                # Skip to find a good insertion point (after existing CODE_SIGN_ entries or at start)
                while j < len(lines) and j < i + 30:
                    if 'CODE_SIGN_IDENTITY' in lines[j]:
                        # Insert after CODE_SIGN_IDENTITY
                        lines.insert(j + 1, '\t\t\t\tCODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;\n')
                        modified = True
                        print(f"✅ Added CODE_SIGN_ENTITLEMENTS to build configuration")
                        break
                    j += 1
    
    if modified:
        # Write back
        with open(project_file, 'w') as f:
            f.writelines(lines)
        print(f"\n✅ Successfully added Runner.entitlements to Xcode project")
        print(f"   File Reference UUID: {file_ref_uuid}")
    else:
        print("ℹ️  Entitlements already present or no modifications needed")

if __name__ == '__main__':
    try:
        add_entitlements_to_project()
    except Exception as e:
        print(f"❌ Error: {e}")
        sys.exit(1)
