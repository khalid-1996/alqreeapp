# Adds the WidgetKit extension target to the generated Flutter iOS project.
# Run from the repo root after `flutter create`:  ruby ios_widget/add_widget.rb 1.0.1 2
require 'xcodeproj'
require 'fileutils'

version = ARGV[0] || '1.0.0'
build = ARGV[1] || '1'
bundle_id = 'net.alqareeapp.alqaree'
ext_name = 'AlqareeWidget'

FileUtils.cp_r('ios_widget/AlqareeWidget', 'ios/')
FileUtils.cp('ios_widget/Runner.entitlements', 'ios/Runner/Runner.entitlements')

project = Xcodeproj::Project.open('ios/Runner.xcodeproj')
runner = project.targets.find { |t| t.name == 'Runner' }
abort('Runner target not found') unless runner
abort('Widget target already exists') if project.targets.any? { |t| t.name == ext_name }

ext = project.new_target(:app_extension, ext_name, :ios, '14.0')

group = project.main_group.new_group(ext_name, ext_name)
swift = group.new_reference('AlqareeWidget.swift')
group.new_reference('Info.plist')
group.new_reference('AlqareeWidget.entitlements')
ext.add_file_references([swift])

ext.build_configurations.each do |c|
  s = c.build_settings
  s['PRODUCT_BUNDLE_IDENTIFIER'] = "#{bundle_id}.#{ext_name}"
  s['PRODUCT_NAME'] = '$(TARGET_NAME)'
  s['INFOPLIST_FILE'] = "#{ext_name}/Info.plist"
  s['CODE_SIGN_ENTITLEMENTS'] = "#{ext_name}/AlqareeWidget.entitlements"
  s['SWIFT_VERSION'] = '5.0'
  s['IPHONEOS_DEPLOYMENT_TARGET'] = '14.0'
  s['TARGETED_DEVICE_FAMILY'] = '1'
  s['MARKETING_VERSION'] = version
  s['CURRENT_PROJECT_VERSION'] = build
  s['SKIP_INSTALL'] = 'YES'
  s['GENERATE_INFOPLIST_FILE'] = 'NO'
  s['LD_RUNPATH_SEARCH_PATHS'] = '$(inherited) @executable_path/Frameworks @executable_path/../../Frameworks'
  s['APPLICATION_EXTENSION_API_ONLY'] = 'YES'
end

runner.build_configurations.each do |c|
  c.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'Runner/Runner.entitlements'
end
runner_group = project.main_group.children.find { |g| g.respond_to?(:display_name) && g.display_name == 'Runner' }
runner_group&.new_reference('Runner.entitlements')

# Embed the extension in the app, before Flutter's "Thin Binary" script to avoid a build cycle.
runner.add_dependency(ext)
embed = runner.new_copy_files_build_phase('Embed Foundation Extensions')
embed.symbol_dst_subfolder_spec = :plug_ins
build_file = embed.add_file_reference(ext.product_reference, true)
build_file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
runner.build_phases.delete(embed)
thin = runner.build_phases.index { |p| p.respond_to?(:name) && p.name == 'Thin Binary' }
if thin
  runner.build_phases.insert(thin, embed)
else
  runner.build_phases << embed
end

project.save
puts "Added #{ext_name} (#{version} build #{build})"
