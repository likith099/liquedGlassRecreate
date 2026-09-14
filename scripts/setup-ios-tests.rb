require 'xcodeproj'
project_path = File.expand_path('../example/ios/LiquidGlassLab.xcodeproj', __dir__)
project = Xcodeproj::Project.open(project_path)
app = project.targets.find { |t| t.name == 'LiquidGlassLab' }
app.build_configurations.each { |c| c.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '16.4' }
target = project.targets.find { |t| t.name == 'LiquidGlassLabUITests' }
unless target
  target = project.new_target(:ui_test_bundle, 'LiquidGlassLabUITests', :ios, '16.4')
  target.add_dependency(app)
  group = project.main_group.new_group('LiquidGlassLabUITests', 'LiquidGlassLabUITests')
  target.add_file_references([group.new_file('GlassInteractionTests.swift')])
end
target.build_configurations.each do |config|
  config.build_settings.merge!({
    'PRODUCT_BUNDLE_IDENTIFIER' => 'org.local.LiquidGlassLabUITests',
    'PRODUCT_NAME' => '$(TARGET_NAME)',
    'GENERATE_INFOPLIST_FILE' => 'YES', 'SWIFT_VERSION' => '5.0',
    'TEST_TARGET_NAME' => 'LiquidGlassLab', 'CODE_SIGN_STYLE' => 'Automatic'
  })
end
project.save
scheme_path = File.join(project_path, 'xcshareddata/xcschemes/LiquidGlassLab.xcscheme')
scheme = Xcodeproj::XCScheme.new(scheme_path)
scheme.test_action.testables.each { |t| t.xml_element.remove }
scheme.add_test_target(target)
scheme.save_as(project_path, 'LiquidGlassLab')
