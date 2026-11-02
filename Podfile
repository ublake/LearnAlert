tiktok_enabled = ENV.fetch('LEARNALERT_ENABLE_TIKTOK', '0') == '1'
platform :ios, '26.2'

target 'LearnAlert' do
  use_frameworks!
  pod 'AnkiArchive', :path => 'Packages/AnkiArchive'
  pod 'CZstd', :path => 'Packages/AnkiArchive'
  pod 'TikTokBusinessSDK', '1.7.2' if tiktok_enabled
  target 'LearnAlertTests' do
    inherit! :search_paths
  end
end

target 'LearnAlertExtension' do
  use_frameworks!
end

post_install do |installer|
  # CocoaPods 1.17 still generates an Xcode 16 review marker. Keep the
  # project-wide security settings aligned with the targets below and record
  # the Xcode 27.1 settings review without changing dependency compiler modes.
  installer.pods_project.root_object.attributes['LastUpgradeCheck'] = '2710'
  installer.pods_project.root_object.attributes['BuildIndependentTargetsInParallel'] = '1'
  installer.pods_project.build_configurations.each do |configuration|
    configuration.build_settings['ENABLE_ENHANCED_SECURITY'] = 'YES'
    configuration.build_settings['ENABLE_HARDWARE_CHECKED_POINTER_ARITHMETIC_SLICE'] = 'YES'
    configuration.build_settings['DEAD_CODE_STRIPPING'] = 'YES'
    configuration.build_settings['STRING_CATALOG_GENERATE_SYMBOLS'] = 'YES'
    configuration.build_settings.delete('STRIP_INSTALLED_PRODUCT')
  end
  crash_source = File.join(installer.sandbox.root, 'TikTokBusinessSDK/TikTokBusinessSDK/Core/TTSDKCrash/TTSDKCrashRecordingCore/TTSDKCPU_arm64.c')
  if File.exist?(crash_source)
    source = File.read(crash_source)
    %w[fp sp pc lr].each do |register|
      source = source.gsub("context->machineContext.__ss.__#{register}", "arm_thread_state64_get_#{register}(context->machineContext.__ss)")
    end
    File.chmod(File.stat(crash_source).mode | 0200, crash_source)
    File.write(crash_source, source)
  end
  # CocoaPods emits quoted imports; CZstd's framework module requires qualified imports.
  czstd_umbrella = File.join(installer.sandbox.root, 'Target Support Files/CZstd/CZstd-umbrella.h')
  if File.exist?(czstd_umbrella)
    source = File.read(czstd_umbrella)
    %w[zstd.h zstd_errors.h].each do |header|
      source = source.gsub(%(#import "#{header}"), %(#import <CZstd/#{header}>))
    end
    File.write(czstd_umbrella, source)
  end
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |configuration|
      configuration.build_settings['ENABLE_ENHANCED_SECURITY'] = 'YES'
      configuration.build_settings['ENABLE_HARDWARE_CHECKED_POINTER_ARITHMETIC_SLICE'] = 'YES'
      deployment_target = configuration.build_settings['IPHONEOS_DEPLOYMENT_TARGET']
      # Xcode 27.1 recommends iOS 17 for dependencies with older minima.
      if deployment_target && Gem::Version.correct?(deployment_target) && Gem::Version.new(deployment_target) < Gem::Version.new('17.0')
        configuration.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '$(RECOMMENDED_IPHONEOS_DEPLOYMENT_TARGET)'
      end
      if target.product_type == 'com.apple.product-type.framework'
        %w[appletvos iphoneos watchos].each do |sdk|
          configuration.build_settings.delete("CODE_SIGN_IDENTITY[sdk=#{sdk}*]")
        end
        configuration.build_settings['CODE_SIGN_IDENTITY'] = ''
        configuration.build_settings['ENABLE_MODULE_VERIFIER'] = 'YES'
        configuration.build_settings['MODULE_VERIFIER_SUPPORTED_LANGUAGE_STANDARDS'] = 'gnu11 gnu++14'
      end
      if target.name.start_with?('Pods-')
        configuration.build_settings.delete('ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES')
        configuration.build_settings.delete('EMBEDDED_CONTENT_CONTAINS_SWIFT')
      end
      if target.name == 'ZIPFoundation'
        # Match Clang's arm64e class_ro_t signing in this mixed Swift/ObjC pod.
        flag_setting = 'OTHER_SWIFT_FLAGS[sdk=iphoneos*][arch=arm64e*]'
        flags = Array(configuration.build_settings[flag_setting] || '$(inherited)')
        flags << '-sign-class-ro' unless flags.any? { |value| value.split.include?('-sign-class-ro') }
        configuration.build_settings[flag_setting] = flags
      end
    end
  end
end

post_integrate do |installer|
  pods_project = Xcodeproj::Project.open('Pods/Pods.xcodeproj')
  privacy_path = 'LearnAlert/PrivacyInfo.xcprivacy'
  privacy = Xcodeproj::Plist.read_from_path(privacy_path)
  privacy['NSPrivacyTracking'] = tiktok_enabled
  privacy['NSPrivacyTrackingDomains'] = tiktok_enabled ? ['analytics.us.tiktok.com'] : []
  Xcodeproj::Plist.write_to_path(privacy, privacy_path)
  installer.aggregate_targets.each do |aggregate|
    project = aggregate.user_project
    unless project.reference_for_path(pods_project.path)
      project.main_group.new_file('Pods/Pods.xcodeproj')
    end
    pods_target = pods_project.targets.find { |target| target.name == aggregate.label }
    aggregate.user_targets.each do |target|
      target.add_dependency(pods_target)
      if target.name == 'LearnAlert'
        target.build_configurations.each do |configuration|
          configuration.build_settings['ENABLE_USER_SCRIPT_SANDBOXING'] = 'NO'
          configuration.build_settings['TIKTOK_TRACKING_ENABLED'] = tiktok_enabled ? 'YES' : 'NO'
          conditions = Array(configuration.build_settings['SWIFT_ACTIVE_COMPILATION_CONDITIONS'] || '$(inherited)').flat_map { |value| value.split }
          conditions.delete('TIKTOK_TRACKING_AVAILABLE')
          conditions << 'TIKTOK_TRACKING_AVAILABLE' if tiktok_enabled
          configuration.build_settings['SWIFT_ACTIVE_COMPILATION_CONDITIONS'] = conditions
          if tiktok_enabled
            configuration.build_settings['INFOPLIST_KEY_NSUserTrackingUsageDescription'] = 'LearnAlert uses tracking to measure the effectiveness of our ads.'
            configuration.build_settings['INFOPLIST_KEY_TikTokAppSecret'] = '$(TIKTOK_APP_SECRET)'
          else
            configuration.build_settings.delete('INFOPLIST_KEY_NSUserTrackingUsageDescription')
            configuration.build_settings.delete('INFOPLIST_KEY_TikTokAppSecret')
          end
          flags = configuration.build_settings['OTHER_LDFLAGS'] ||= ['$(inherited)']
          ['-ObjC', '-lc++'].each { |flag| flags.delete(flag); flags << flag if tiktok_enabled }
        end
      end
    end
    # Xcode expects a subproject's product group to contain reference proxies,
    # never the app's own PBXFileReference products. xcodeproj's new_subproject
    # currently reuses the root Products group, which crashes Xcode on autosave.
    project.root_object.project_references.each do |reference|
      next unless reference[:product_group] == project.products_group
      products = project.new(Xcodeproj::Project::Object::PBXGroup)
      products.name = 'Products'
      products.source_tree = '<group>'
      project.products_group.children.to_a.each do |product|
        next unless product.isa == 'PBXReferenceProxy'
        next unless product.remote_ref.container_portal == reference[:project_ref].uuid
        project.products_group.children.delete(product)
        products.children << product
      end
      reference[:product_group] = products
    end
    project.save
  end
end
