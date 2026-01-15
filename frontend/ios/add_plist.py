#!/usr/bin/env python3
import re
import uuid

# Read the project file
with open('Runner.xcodeproj/project.pbxproj', 'r') as f:
    content = f.read()

# Check if already added
if 'GoogleService-Info.plist' in content:
    print("✅ GoogleService-Info.plist already exists in project")
    exit(0)

# Generate UUIDs for the new entries
file_ref_uuid = str(uuid.uuid4()).replace('-', '')[:24].upper()
build_file_uuid = str(uuid.uuid4()).replace('-', '')[:24].upper()

# Find the PBXFileReference section
file_ref_section = re.search(r'/\* Begin PBXFileReference section \*/(.*?)/\* End PBXFileReference section \*/', content, re.DOTALL)
if not file_ref_section:
    print("❌ Could not find PBXFileReference section")
    exit(1)

# Add the file reference
file_reference = f"\t\t{file_ref_uuid} /* GoogleService-Info.plist */ = {{isa = PBXFileReference; fileEncoding = 4; lastKnownFileType = text.plist.xml; path = \"GoogleService-Info.plist\"; sourceTree = \"<group>\"; }};\n"

# Insert before the End PBXFileReference comment
content = content.replace('/* End PBXFileReference section */', file_reference + '\t/* End PBXFileReference section */')

# Find the PBXGroup section for Runner
runner_group_match = re.search(r'97C146F01CF9000F007C117D /\* Runner \*/ = \{[^}]*?children = \((.*?)\);', content, re.DOTALL)
if runner_group_match:
    children_content = runner_group_match.group(1)
    # Add our file reference to the Runner group
    new_child = f"\n\t\t\t\t{file_ref_uuid} /* GoogleService-Info.plist */,"
    content = content.replace(children_content, children_content + new_child)
else:
    print("❌ Could not find Runner group")
    exit(1)

# Find the PBXBuildFile section
build_file_section = re.search(r'/\* Begin PBXBuildFile section \*/(.*?)/\* End PBXBuildFile section \*/', content, re.DOTALL)
if not build_file_section:
    print("❌ Could not find PBXBuildFile section")
    exit(1)

# Add the build file
build_file = f"\t\t{build_file_uuid} /* GoogleService-Info.plist in Resources */ = {{isa = PBXBuildFile; fileRef = {file_ref_uuid} /* GoogleService-Info.plist */; }};\n"
content = content.replace('/* End PBXBuildFile section */', build_file + '\t/* End PBXBuildFile section */')

# Find the PBXResourcesBuildPhase section for Runner target
resources_phase_match = re.search(r'97C146EC1CF9000F007C117D /\* Resources \*/ = \{[^}]*?files = \((.*?)\);', content, re.DOTALL)
if resources_phase_match:
    files_content = resources_phase_match.group(1)
    # Add our build file to the Resources phase
    new_file = f"\n\t\t\t\t{build_file_uuid} /* GoogleService-Info.plist in Resources */,"
    content = content.replace(files_content, files_content + new_file)
else:
    print("❌ Could not find Resources build phase")
    exit(1)

# Write the modified content back
with open('Runner.xcodeproj/project.pbxproj', 'w') as f:
    f.write(content)

print("✅ Successfully added GoogleService-Info.plist to Xcode project!")
print(f"   File Reference UUID: {file_ref_uuid}")
print(f"   Build File UUID: {build_file_uuid}")
