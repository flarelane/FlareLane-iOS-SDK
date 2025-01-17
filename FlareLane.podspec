#
# Be sure to run `pod lib lint FlareLane.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'FlareLane'
  s.version          = '1.7.2'
  s.summary          = 'FlareLane iOS SDK'

  s.homepage         = 'https://github.com/flarelane/FlareLane-iOS-SDK'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'FlareLane' => 'admin@flarelane.com' }
  s.source           = { :git => 'https://github.com/flarelane/FlareLane-iOS-SDK.git', :tag => s.version.to_s }

  s.ios.deployment_target = '12.0'

  s.source_files = 'FlareLane/Classes/**/*'

  # by default
  s.swift_versions = '5.0'

end
