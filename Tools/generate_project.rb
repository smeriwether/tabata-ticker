require "fileutils"
require "xcodeproj"

ROOT = File.expand_path("..", __dir__)
PROJECT_PATH = File.join(ROOT, "Tabata.xcodeproj")
BUNDLE_ID = "com.merimerimeri.Tabata"

FileUtils.rm_rf(PROJECT_PATH)

project = Xcodeproj::Project.new(PROJECT_PATH)

ios_target = project.new_target(:application, "Tabata", :ios, "26.0")
watch_target = project.new_target(:application, "Tabata Watch App", :watchos, "26.0")
test_target = project.new_target(:unit_test_bundle, "TabataTests", :osx, "26.0")

def add_sources(project, target, paths)
  paths.each do |path|
    ref = project.files.find { |file| file.path == path } || project.new_file(path)
    target.add_file_references([ref])
  end
end

def add_package_product(project, target, package, product_name)
  dependency = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
  dependency.product_name = product_name
  dependency.package = package
  target.package_product_dependencies << dependency

  build_file = project.new(Xcodeproj::Project::Object::PBXBuildFile)
  build_file.product_ref = dependency
  target.frameworks_build_phase.files << build_file
end

shared_sources = [
  "Shared/TabataCore.swift"
]

ios_sources = shared_sources + [
  "iOS/TabataApp.swift",
  "iOS/ContentView.swift",
  "iOS/WorkoutViewModel.swift",
  "iOS/PhoneConnectivity.swift"
]

watch_sources = shared_sources + [
  "Watch/TabataWatchApp.swift",
  "Watch/WatchContentView.swift",
  "Watch/WatchWorkoutViewModel.swift",
  "Watch/WatchConnectivity.swift"
]

test_sources = [
  "Tests/TabataCoreTests.swift"
]

add_sources(project, ios_target, ios_sources)
add_sources(project, watch_target, watch_sources)
add_sources(project, test_target, test_sources)

package_ref = project.new(Xcodeproj::Project::Object::XCLocalSwiftPackageReference)
package_ref.relative_path = "."
project.root_object.package_references << package_ref
add_package_product(project, test_target, package_ref, "TabataCore")

asset_ref = project.new_file("Assets.xcassets")
legacy_icon_refs = Dir["Resources/*.png"].sort.map { |path| project.new_file(path) }
ios_target.add_resources([asset_ref] + legacy_icon_refs)

def configure_common(target)
  target.build_configurations.each do |config|
    settings = config.build_settings
    settings["CODE_SIGN_STYLE"] = "Automatic"
    settings["DEVELOPMENT_TEAM"] = ""
    settings["GENERATE_INFOPLIST_FILE"] = "YES"
    settings["MARKETING_VERSION"] = "1.0"
    settings["CURRENT_PROJECT_VERSION"] = "1"
    settings["PRODUCT_NAME"] = "$(TARGET_NAME)"
    settings["SWIFT_VERSION"] = "6.0"
    settings.delete("ASSETCATALOG_COMPILER_APPICON_NAME")
    settings.delete("ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME")
  end
end

[ios_target, watch_target, test_target].each { |target| configure_common(target) }

ios_target.build_configurations.each do |config|
  settings = config.build_settings
  settings["GENERATE_INFOPLIST_FILE"] = "NO"
  settings["INFOPLIST_FILE"] = "iOS/Info.plist"
  settings["PRODUCT_BUNDLE_IDENTIFIER"] = BUNDLE_ID
  settings["IPHONEOS_DEPLOYMENT_TARGET"] = "26.0"
  settings["SDKROOT"] = config.name == "Debug" ? "iphonesimulator" : "iphoneos"
  settings["TARGETED_DEVICE_FAMILY"] = "1,2"
  settings["ASSETCATALOG_COMPILER_APPICON_NAME"] = "AppIcon" if config.name == "Release"
  settings["SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD"] = "NO"
  settings["SUPPORTS_XR_DESIGNED_FOR_IPHONE_IPAD"] = "NO"
end

watch_target.build_configurations.each do |config|
  settings = config.build_settings
  settings["PRODUCT_BUNDLE_IDENTIFIER"] = "#{BUNDLE_ID}.watchkitapp"
  settings["WATCHOS_DEPLOYMENT_TARGET"] = "26.0"
  settings["SDKROOT"] = config.name == "Debug" ? "watchsimulator" : "watchos"
  settings["TARGETED_DEVICE_FAMILY"] = "4"
  settings["INFOPLIST_KEY_CFBundleDisplayName"] = "Tabata Ticker"
  settings["INFOPLIST_KEY_WKCompanionAppBundleIdentifier"] = BUNDLE_ID
  settings["SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD"] = "NO"
end

test_target.build_configurations.each do |config|
  settings = config.build_settings
  settings["PRODUCT_BUNDLE_IDENTIFIER"] = "#{BUNDLE_ID}.tests"
  settings["MACOSX_DEPLOYMENT_TARGET"] = "26.0"
  settings["SDKROOT"] = "macosx"
  settings["TEST_HOST"] = ""
end

project.save

ios_scheme = Xcodeproj::XCScheme.new
ios_scheme.add_build_target(ios_target)
ios_scheme.set_launch_target(ios_target)
ios_scheme.save_as(PROJECT_PATH, "Tabata", true)

watch_scheme = Xcodeproj::XCScheme.new
watch_scheme.add_build_target(watch_target)
watch_scheme.set_launch_target(watch_target)
watch_scheme.save_as(PROJECT_PATH, "Tabata Watch App", true)

test_scheme = Xcodeproj::XCScheme.new
test_scheme.add_build_target(test_target)
test_scheme.add_test_target(test_target)
test_scheme.save_as(PROJECT_PATH, "TabataTests", true)
