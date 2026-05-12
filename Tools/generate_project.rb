require "fileutils"
require "xcodeproj"

ROOT = File.expand_path("..", __dir__)
PROJECT_PATH = File.join(ROOT, "Tabata.xcodeproj")
APP_DISPLAY_NAME = "Tabata Ticker"
APPLE_TEAM_ID = "8G4H6268W7"
BUNDLE_ID = "com.merimerimeri.tabataticker"
WATCH_BUNDLE_ID = "#{BUNDLE_ID}.watchkitapp"

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
watch_target.add_resources([asset_ref])

embed_watch_phase = ios_target.new_copy_files_build_phase("Embed Watch Content")
embed_watch_phase.symbol_dst_subfolder_spec = :products_directory
watch_build_file = project.new(Xcodeproj::Project::Object::PBXBuildFile)
watch_build_file.file_ref = watch_target.product_reference
watch_build_file.settings = { "ATTRIBUTES" => ["RemoveHeadersOnCopy"] }
embed_watch_phase.files << watch_build_file

def configure_common(target)
  target.build_configurations.each do |config|
    settings = config.build_settings
    settings["CODE_SIGN_STYLE"] = "Automatic"
    settings["DEVELOPMENT_TEAM"] = APPLE_TEAM_ID
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
  settings["SUPPORTED_PLATFORMS"] = config.name == "Debug" ? "iphonesimulator" : "iphoneos"
  settings["TARGETED_DEVICE_FAMILY"] = "1,2"
  if config.name == "Release"
    settings["ASSETCATALOG_COMPILER_APPICON_NAME"] = "AppIcon"
    settings["CODE_SIGN_STYLE"] = "Manual"
    settings["CODE_SIGN_IDENTITY"] = "Apple Distribution"
    settings["PROVISIONING_PROFILE_SPECIFIER"] = "$(IOS_PROFILE_NAME)"
  end
  settings["INFOPLIST_KEY_CFBundleDisplayName"] = APP_DISPLAY_NAME
  settings["SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD"] = "NO"
  settings["SUPPORTS_XR_DESIGNED_FOR_IPHONE_IPAD"] = "NO"
end

watch_target.build_configurations.each do |config|
  settings = config.build_settings
  if config.name == "Release"
    settings["ASSETCATALOG_COMPILER_APPICON_NAME"] = "AppIcon"
    settings["CODE_SIGN_STYLE"] = "Manual"
    settings["CODE_SIGN_IDENTITY"] = "Apple Distribution"
    settings["PROVISIONING_PROFILE_SPECIFIER"] = "$(WATCH_PROFILE_NAME)"
  end
  settings["PRODUCT_BUNDLE_IDENTIFIER"] = WATCH_BUNDLE_ID
  settings["WATCHOS_DEPLOYMENT_TARGET"] = "26.0"
  settings["SDKROOT"] = config.name == "Debug" ? "watchsimulator" : "watchos"
  settings["SUPPORTED_PLATFORMS"] = config.name == "Debug" ? "watchsimulator" : "watchos"
  settings["TARGETED_DEVICE_FAMILY"] = "4"
  settings["INFOPLIST_KEY_CFBundleDisplayName"] = APP_DISPLAY_NAME
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
