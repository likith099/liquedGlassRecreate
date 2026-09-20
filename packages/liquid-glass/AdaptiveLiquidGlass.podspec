require 'json'
package = JSON.parse(File.read(File.join(__dir__, 'package.json')))
Pod::Spec.new do |s|
  s.name = 'AdaptiveLiquidGlass'
  s.version = package['version']
  s.summary = package['description']
  s.homepage = 'https://github.com/likith099/liquedGlassRecreate'
  s.license = { :type => 'MIT', :file => 'LICENSE' }
  s.author = 'Likith Kanneganti'
  s.platforms = { :ios => '15.1' }
  # Autolinked from node_modules; the source is declared for completeness.
  s.source = { :git => 'https://github.com/likith099/liquedGlassRecreate.git', :tag => "v#{s.version}" }
  s.source_files = 'ios/**/*.{h,m,mm,swift}'
  s.private_header_files = 'ios/**/*.h'
  s.swift_version = '5.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  install_modules_dependencies(s)
end
