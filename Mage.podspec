#
# Be sure to run `pod lib lint Mage.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'Mage'
  s.version          = '1.1.1'
  s.summary          = 'Mage iOS SDK'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
Automatically and simultaneously test and optimize in-app purchase prices in 170+ app store countries. You do not need to hire data scientists to take your pricing to the next level. Just use the Mage SDK. Sign up for free!
                       DESC

  s.homepage         = 'https://github.com/getmageio/mage-ios-sdk'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Mage Labs GmbH' => 'team@getmage.io' }
  s.source           = { :git => 'https://github.com/getmageio/mage-ios-sdk.git', :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/getmage_io'

  s.ios.deployment_target = '11.0'

  s.source_files = 'Mage/Classes/**/*'
  
  # s.resource_bundles = {
  #   'Mage' => ['Mage/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  # s.dependency 'AFNetworking', '~> 2.3'
end
