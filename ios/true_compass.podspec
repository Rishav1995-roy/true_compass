#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint true_compass.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'true_compass'
  s.version          = '0.0.1'
  s.summary          = 'Compass heading with magnetic and true north for Flutter.'
  s.description      = <<-DESC
Compass heading with magnetic and true north, accuracy events and screen rotation.
                       DESC
  s.homepage         = 'https://github.com/Rishav1995-roy/true_compass'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Rishav Deb Roy' => 'debroyrishab@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files = 'true_compass/Sources/true_compass/**/*'
  s.dependency 'Flutter'
  s.frameworks = 'CoreLocation'
  s.platform = :ios, '15.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # If your plugin requires a privacy manifest, for example if it uses any
  # required reason APIs, update the PrivacyInfo.xcprivacy file to describe your
  # plugin's privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  s.resource_bundles = {'true_compass_privacy' => ['true_compass/Sources/true_compass/PrivacyInfo.xcprivacy']}
end
