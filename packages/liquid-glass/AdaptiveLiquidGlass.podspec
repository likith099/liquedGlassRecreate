require 'json'
package = JSON.parse(File.read(File.join(__dir__, 'package.json')))
Pod::Spec.new do |s|
  s.name = 'AdaptiveLiquidGlass'
  s.version = package['version']
  s.summary = package['description']
  s.homepage = 'https://reactnative.dev'
  s.license = { :type => 'Proprietary' }
  s.author = 'Liquid Glass contributors'
  s.platforms = { :ios => '16.4' }
  # Local workspace pod; replace with the repository URL before publishing.
  s.source = { :git => 'https://localhost/adaptive-liquid-glass.git', :tag => s.version.to_s }
  s.source_files = 'ios/**/*.{h,m,mm,swift}'
  s.private_header_files = 'ios/**/*.h'
  s.swift_version = '5.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  install_modules_dependencies(s)
end
