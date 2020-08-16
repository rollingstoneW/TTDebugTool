#
# Be sure to run `pod lib lint TTDebugTool.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'TTDebugTool'
  s.version          = '0.0.1'
  s.summary          = '开发调试工具'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
开发调试工具，包含视图检测，日志、webview、页面、接口、基础信息展示，对象检查器等功能。
                       DESC

  s.homepage         = 'https://git.zuoyebang.cc/native/TTDebugtool.git'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'rollingstoneW' => 'rollingstoneW@zuoyebang.com' }
  s.source           = { :git => 'git@git.zuoyebang.cc:native/TTDebugtool.git', :tag => s.version.to_s }

  s.ios.deployment_target = '9.0'


  s.source_files = 'TTDebugTool/Classes/**/*'
  s.prefix_header_contents = "#import <Masonry/Masonry.h>", '#import "TTDebugUtils.h"'
  
  s.subspec 'Base' do |sp|
      sp.source_files = 'TTDebugTool/Classes/Base/**/*.{h,m,mm,c,cpp}'
      sp.resource_bundles = {
          'TTDebugToolResource' => ['TTDebugTool/Assets/**/*.*']
      }
     sp.dependency 'TNAlertView'
      sp.dependency 'Masonry'
      sp.dependency 'YYModel'
      # sp.dependency 'TNAlertView'
      sp.frameworks = 'WebKit'
  end
  
  s.subspec 'H5Action' do |sp|
      sp.source_files = 'TTDebugTool/Classes/H5Action/**/*.{h,m,mm,c,cpp}'
      sp.dependency 'ZYBWebBundle'
      sp.dependency 'TTDebugTool/Base'
  end

  s.subspec 'ViewHierarchy' do |sp|
      sp.source_files = 'TTDebugTool/Classes/ViewHierarchy/**/*.{h,m,mm,c,cpp}'
      sp.dependency 'TTDebugTool/Base'
  end
  
  s.subspec 'Log' do |sp|
      sp.source_files = 'TTDebugTool/Classes/Log/**/*.{h,m,mm,c,cpp}'
      sp.dependency 'TTDebugTool/Base'
      sp.frameworks = 'CoreTelephony'
      sp.dependency 'AFNetworking'
#      sp.dependency 'ZYBLcsConnection'
  end
  
  s.subspec 'RuntimeInspector' do |sp|
      sp.source_files = 'TTDebugTool/Classes/RuntimeInspector/**/*.{h,m,mm,c,cpp}'
      sp.dependency 'TTDebugTool/Base'
  end
  
  s.default_subspecs = 'H5Action', 'ViewHierarchy', 'Log', 'RuntimeInspector'

  s.frameworks = 'UIKit'
  
end
