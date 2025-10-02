# Agiliton Shared Fastlane Lanes
# Version: 2.0.0
#
# This file contains common lanes used across all Agiliton projects.
# Import this in your Fastfile with:
#   import "#{ENV['HOME']}/VisualStudio/AgilitonShared/Scripts/Fastlane/shared_config.rb"
#   import "#{ENV['HOME']}/VisualStudio/AgilitonShared/Scripts/Fastlane/shared_lanes.rb"
#
# Changelog:
# v2.0.0 - Fixed working directory issue in increment_build
#        - Added versioning verification
#        - Renamed testflight_ios to deploy_testflight_ios (avoid conflicts)
#        - Enhanced error handling and validation

# Load shared configuration
require_relative 'shared_config'

module AgilitonLanes
  class << self
    # Setup App Store Connect API key
    # @return [Hash] Configured API key
    def setup_api_key
      AgilitonConfig.api_key
    end

    # Verify Apple Generic Versioning is enabled
    # @param xcodeproj [String] Path to .xcodeproj file
    # @raise [UI.user_error!] If versioning is not enabled
    def verify_apple_generic_versioning(xcodeproj:)
      pbxproj_path = File.join(xcodeproj, "project.pbxproj")

      unless File.exist?(pbxproj_path)
        UI.user_error!("❌ Project file not found: #{pbxproj_path}")
      end

      content = File.read(pbxproj_path)

      unless content.include?('VERSIONING_SYSTEM = "apple-generic"')
        UI.error("❌ Apple Generic Versioning is not enabled in #{xcodeproj}")
        UI.error("")
        UI.error("📋 To fix this, add to your build settings:")
        UI.error('   VERSIONING_SYSTEM = "apple-generic";')
        UI.error("")
        UI.error("📚 See: https://developer.apple.com/library/content/qa/qa1827/")
        UI.user_error!("Project not configured for automated versioning")
      end

      UI.success("✅ Apple Generic Versioning enabled")
    end

    # Increment build number in Xcode project
    # @param xcodeproj [String] Path to .xcodeproj file
    # @note CRITICAL: This method changes directory to ensure agvtool works correctly
    def increment_build(xcodeproj:)
      # Get absolute paths to avoid issues
      xcodeproj_abs = File.expand_path(xcodeproj)
      project_dir = File.dirname(xcodeproj_abs)
      project_name = File.basename(xcodeproj_abs)

      UI.message("📦 Incrementing build number for #{project_name}")
      UI.message("📂 Project directory: #{project_dir}")

      # CRITICAL: agvtool requires being in the project directory
      # Save current directory
      original_dir = Dir.pwd

      begin
        # Change to project directory
        Dir.chdir(project_dir) do
          Fastlane::Actions::IncrementBuildNumberAction.run(
            xcodeproj: project_name
          )
        end
      ensure
        # Always return to original directory
        Dir.chdir(original_dir)
      end

      UI.success("✅ Build number incremented successfully")
    end

    # Run tests with coverage for iOS projects
    # @param scheme [String] Xcode scheme name
    # @param devices [Array<String>] List of device names to test on
    # @param output_dir [String] Directory for test output (default: ./fastlane/test_output)
    def run_ios_tests(scheme:, devices: ["iPhone 17 Pro"], output_dir: "./fastlane/test_output")
      Fastlane::Actions::RunTestsAction.run(
        scheme: scheme,
        devices: devices,
        code_coverage: true,
        output_directory: output_dir,
        output_types: "html,junit",
        result_bundle: true
      )
    end

    # Upload to TestFlight with standard Agiliton settings
    # @param changelog [String] What's new in this build
    # @param groups [Array<String>] Tester groups to distribute to
    # @param app_identifier [String] Bundle identifier (for macOS apps)
    # @param uses_non_exempt_encryption [Boolean] Whether app uses encryption
    def upload_testflight(
      changelog:,
      groups: [AgilitonConfig::STANDARD_TESTER_GROUP],
      app_identifier: nil,
      uses_non_exempt_encryption: false
    )
      options = {
        skip_waiting_for_build_processing: false,
        skip_submission: false,
        distribute_external: true,
        groups: groups,
        notify_external_testers: true,
        changelog: changelog
      }

      # Add optional parameters
      options[:app_identifier] = app_identifier if app_identifier
      options[:uses_non_exempt_encryption] = uses_non_exempt_encryption

      Fastlane::Actions::UploadToTestflightAction.run(options)
    end

    # Build iOS app for App Store distribution
    # @param scheme [String] Xcode scheme name
    # @param clean [Boolean] Whether to clean before building
    # @param xcargs [String] Additional xcodebuild arguments
    def build_ios_app(scheme:, clean: true, xcargs: "DEVELOPMENT_TEAM=#{AgilitonConfig::TEAM_ID}")
      Fastlane::Actions::BuildAppAction.run(
        scheme: scheme,
        export_method: AgilitonConfig::EXPORT_METHOD,
        xcargs: xcargs,
        clean: clean,
        export_options: AgilitonConfig.ios_export_options
      )
    end

    # Build macOS app for App Store distribution using gym
    # @param scheme [String] Xcode scheme name
    # @param output_directory [String] Where to save the build
    # @param xcodeproj [String] Path to .xcodeproj file (optional)
    def build_macos_app(
      scheme:,
      output_directory: "./build",
      xcodeproj: nil
    )
      options = {
        scheme: scheme,
        export_method: AgilitonConfig::EXPORT_METHOD,
        export_options: AgilitonConfig.macos_export_options,
        configuration: "Release",
        output_directory: output_directory,
        build_path: output_directory,
        derived_data_path: "./DerivedData"
      }

      options[:project] = xcodeproj if xcodeproj

      Fastlane::Actions::GymAction.run(options)
    end

    # Send Slack notification (if SLACK_URL is configured)
    # @param message [String] Message to send
    # @param success [Boolean] Whether this is a success or failure message
    def notify_slack(message:, success: true)
      return unless ENV["SLACK_URL"]

      Fastlane::Actions::SlackAction.run(
        message: message,
        success: success
      )
    end

    # Clean derived data to ensure fresh build
    def clean_build
      Fastlane::Actions::ClearDerivedDataAction.run
    end

    # Setup certificates and provisioning profiles using match
    # @param types [Array<String>] Profile types (development, appstore)
    def setup_certificates(types: ["development", "appstore"])
      types.each do |type|
        Fastlane::Actions::MatchAction.run(type: type)
      end
    end

    # Deploy iOS app to TestFlight - standardized deployment lane
    # This can be called from individual Fastfiles
    # @param scheme [String] Xcode scheme name
    # @param xcodeproj [String] Path to .xcodeproj file
    # @param changelog [String] What's new in this build
    # @param groups [Array<String>] Tester groups
    # @param run_tests [Boolean] Whether to run tests before building
    # @param verify_versioning [Boolean] Whether to verify Apple Generic Versioning is enabled
    # @note Renamed from testflight_ios to avoid conflicts with Fastlane action
    def deploy_testflight_ios(
      scheme:,
      xcodeproj:,
      changelog:,
      groups: [AgilitonConfig::STANDARD_TESTER_GROUP],
      run_tests: false,
      verify_versioning: true
    )
      UI.header("🚀 Deploying #{scheme} to TestFlight")

      # Verify project setup
      if verify_versioning
        UI.message("🔍 Verifying project configuration...")
        verify_apple_generic_versioning(xcodeproj: xcodeproj)
      end

      # Run tests if requested
      if run_tests
        UI.message("🧪 Running tests...")
        run_ios_tests(scheme: scheme)
      end

      # Increment build number
      increment_build(xcodeproj: xcodeproj)

      # Clean derived data
      UI.message("🧹 Cleaning derived data...")
      clean_build

      # Build the app
      UI.message("🔨 Building app...")
      build_ios_app(scheme: scheme)

      # Upload to TestFlight
      UI.message("☁️  Uploading to TestFlight...")
      upload_testflight(changelog: changelog, groups: groups)

      # Send success notification
      notify_slack(message: "Successfully deployed #{scheme} to TestFlight! 🚀")
      UI.success("✅ Deployment complete!")
    end

    # Legacy alias for backward compatibility
    # @deprecated Use deploy_testflight_ios instead
    def testflight_ios(
      scheme:,
      xcodeproj:,
      changelog:,
      groups: [AgilitonConfig::STANDARD_TESTER_GROUP],
      run_tests: false
    )
      UI.important("⚠️  testflight_ios is deprecated. Use deploy_testflight_ios instead.")
      deploy_testflight_ios(
        scheme: scheme,
        xcodeproj: xcodeproj,
        changelog: changelog,
        groups: groups,
        run_tests: run_tests
      )
    end

    # Deploy macOS app to TestFlight - standardized deployment lane
    # @param scheme [String] Xcode scheme name
    # @param xcodeproj [String] Path to .xcodeproj file
    # @param app_identifier [String] Bundle identifier
    # @param changelog [String] What's new in this build
    # @param groups [Array<String>] Tester groups
    # @param verify_versioning [Boolean] Whether to verify Apple Generic Versioning is enabled
    def deploy_testflight_macos(
      scheme:,
      xcodeproj:,
      app_identifier:,
      changelog:,
      groups: [AgilitonConfig::STANDARD_TESTER_GROUP],
      verify_versioning: true
    )
      UI.header("🚀 Deploying #{scheme} to TestFlight (macOS)")

      # Setup API key
      api_key = setup_api_key

      # Verify project setup
      if verify_versioning
        UI.message("🔍 Verifying project configuration...")
        verify_apple_generic_versioning(xcodeproj: xcodeproj)
      end

      # Increment build number
      increment_build(xcodeproj: xcodeproj)

      # Build the app
      UI.message("🔨 Building macOS app...")
      build_macos_app(scheme: scheme, xcodeproj: xcodeproj)

      # Upload to TestFlight
      UI.message("☁️  Uploading to TestFlight...")
      upload_testflight(
        changelog: changelog,
        groups: groups,
        app_identifier: app_identifier,
        uses_non_exempt_encryption: false
      )

      # Send success notification
      notify_slack(message: "Successfully deployed #{scheme} to TestFlight! 🚀")
      UI.success("✅ Deployment complete!")
    end

    # Legacy alias for backward compatibility
    # @deprecated Use deploy_testflight_macos instead
    def testflight_macos(
      scheme:,
      xcodeproj:,
      app_identifier:,
      changelog:,
      groups: [AgilitonConfig::STANDARD_TESTER_GROUP]
    )
      UI.important("⚠️  testflight_macos is deprecated. Use deploy_testflight_macos instead.")
      deploy_testflight_macos(
        scheme: scheme,
        xcodeproj: xcodeproj,
        app_identifier: app_identifier,
        changelog: changelog,
        groups: groups
      )
    end
  end
end

# Make lanes available as private lanes that can be called from project Fastfiles
# Example usage in project Fastfile:
#
#   import "#{ENV['HOME']}/VisualStudio/AgilitonShared/Scripts/Fastlane/shared_config.rb"
#   import "#{ENV['HOME']}/VisualStudio/AgilitonShared/Scripts/Fastlane/shared_lanes.rb"
#
#   platform :ios do
#     desc "Deploy to TestFlight"
#     lane :testflight do
#       AgilitonLanes.deploy_testflight_ios(
#         scheme: "MyApp",
#         xcodeproj: "MyApp.xcodeproj",
#         changelog: "Bug fixes and improvements"
#       )
#     end
#   end
#
# Prerequisites:
# 1. Apple Generic Versioning must be enabled in your Xcode project
#    Add to build settings: VERSIONING_SYSTEM = "apple-generic";
#
# 2. Set CURRENT_PROJECT_VERSION in build settings
#
# 3. Configure App Store Connect API key (see shared_config.rb)
#
# For setup help, run: ~/VisualStudio/AgilitonShared/Scripts/verify_project_setup.sh MyApp.xcodeproj
