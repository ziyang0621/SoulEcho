require 'xcodeproj'
project_path = 'SoulEcho.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Create File Reference for iOS
group = project.main_group.find_subpath('SoulEcho', true)
file_ref = group.new_reference('Localizable.xcstrings')
target = project.targets.find { |t| t.name == 'SoulEcho' }
target.add_file_references([file_ref])

# Create File Reference for WatchOS
group_watch = project.main_group.find_subpath('SoulEcho Watch App', true)
file_ref_watch = group_watch.new_reference('Localizable.xcstrings')
target_watch = project.targets.find { |t| t.name == 'SoulEcho Watch App' }
target_watch.add_file_references([file_ref_watch])

project.save
