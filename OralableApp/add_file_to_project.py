#!/usr/bin/env python3
"""
Script to add HealthKitPermissionView.swift to Xcode project
"""

import uuid
import re

def generate_uuid():
    """Generate a 24-character hex UUID like Xcode uses"""
    return ''.join(str(uuid.uuid4()).replace('-', ''))[:24].upper()

def add_file_to_project():
    project_file = 'OralableApp.xcodeproj/project.pbxproj'

    # Read the project file
    with open(project_file, 'r') as f:
        content = f.read()

    # Generate UUIDs for the file reference and build file
    file_ref_uuid = generate_uuid()
    build_file_uuid = generate_uuid()

    file_name = 'HealthKitPermissionView.swift'
    file_path = 'OralableApp/Views/HealthKitPermissionView.swift'

    # 1. Add PBXBuildFile entry
    build_file_entry = f'\t\t{build_file_uuid} /* {file_name} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_ref_uuid} /* {file_name} */; }};\n'

    # Find the PBXBuildFile section and add our entry
    build_file_section = re.search(r'(/\* Begin PBXBuildFile section \*/\n)', content)
    if build_file_section:
        insert_pos = build_file_section.end()
        content = content[:insert_pos] + build_file_entry + content[insert_pos:]

    # 2. Add PBXFileReference entry
    file_ref_entry = f'\t\t{file_ref_uuid} /* {file_name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {file_name}; sourceTree = "<group>"; }};\n'

    # Find the PBXFileReference section and add our entry
    file_ref_section = re.search(r'(/\* Begin PBXFileReference section \*/\n)', content)
    if file_ref_section:
        insert_pos = file_ref_section.end()
        content = content[:insert_pos] + file_ref_entry + content[insert_pos:]

    # 3. Add to Views group
    # Find the Views group (PBXGroup)
    views_group_pattern = r'(/\* Views \*/ = {[^}]+children = \(\n)'
    views_group = re.search(views_group_pattern, content)
    if views_group:
        insert_pos = views_group.end()
        group_entry = f'\t\t\t\t{file_ref_uuid} /* {file_name} */,\n'
        content = content[:insert_pos] + group_entry + content[insert_pos:]

    # 4. Add to Sources Build Phase (PBXSourcesBuildPhase)
    # Find OralableApp target's Sources build phase
    sources_pattern = r'(/\* Sources \*/ = {[^}]+isa = PBXSourcesBuildPhase;[^}]+files = \(\n)'
    sources_match = re.search(sources_pattern, content)
    if sources_match:
        insert_pos = sources_match.end()
        sources_entry = f'\t\t\t\t{build_file_uuid} /* {file_name} in Sources */,\n'
        content = content[:insert_pos] + sources_entry + content[insert_pos:]

    # Write back to file
    with open(project_file, 'w') as f:
        f.write(content)

    print(f"✅ Added {file_name} to Xcode project")
    print(f"   File Reference UUID: {file_ref_uuid}")
    print(f"   Build File UUID: {build_file_uuid}")

if __name__ == '__main__':
    add_file_to_project()
