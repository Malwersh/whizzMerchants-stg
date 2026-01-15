#!/usr/bin/env ruby

require 'xcodeproj'

project_path = 'Runner.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Locate Runner target and group
runner_target = project.targets.find { |t| t.name == 'Runner' } || project.targets.first
runner_group = project.main_group.find_subpath('Runner', true)

# Helper to ensure a file reference exists in the Runner group
# Returns the file reference (existing or newly created)
def ensure_file_ref(group, relative_path)
  ref = group.files.find { |f| f.path == relative_path }
  ref || group.new_reference(relative_path)
end

# 1) Ensure GoogleService-Info.plist is added to project and Resources phase
plist_ref = ensure_file_ref(runner_group, 'GoogleService-Info.plist')
resources_phase = runner_target.resources_build_phase
unless resources_phase.files_references.include?(plist_ref)
  resources_phase.add_file_reference(plist_ref)
  puts '📦 Added GoogleService-Info.plist to Resources build phase'
else
  puts 'ℹ️ GoogleService-Info.plist already present in Resources'
end

# 2) Ensure entitlements files are present in project (references only)
prod_entitlements = ensure_file_ref(runner_group, 'Runner/Runner.entitlements')
debug_entitlements = ensure_file_ref(runner_group, 'Runner/RunnerDebug.entitlements')
puts '✅ Ensured entitlements file references exist in project'

# 3) Set CODE_SIGN_ENTITLEMENTS per configuration (idempotent)
runner_target.build_configurations.each do |config|
  case config.name
  when 'Debug'
    desired = 'Runner/RunnerDebug.entitlements'
  else
    # Release, Profile, and any other
    desired = 'Runner/Runner.entitlements'
  end

  current = config.build_settings['CODE_SIGN_ENTITLEMENTS']
  if current != desired
    config.build_settings['CODE_SIGN_ENTITLEMENTS'] = desired
    puts "🔧 Set CODE_SIGN_ENTITLEMENTS for #{config.name} -> #{desired}"
  else
    puts "ℹ️ CODE_SIGN_ENTITLEMENTS already set for #{config.name}"
  end
end

# Save project
project.save

puts '✅ Xcode project updated: GoogleService-Info.plist + entitlements configured'
