# Agiliton Shared Fastlane Lanes
# Version: 1.0.0
#
# This file contains common lanes used across all Agiliton projects.
# Import this in your Fastfile with:
#   import "#{ENV['HOME']}/VisualStudio/AgilitonShared/Scripts/Fastlane/shared_config.rb"
#   import "#{ENV['HOME']}/VisualStudio/AgilitonShared/Scripts/Fastlane/shared_lanes.rb"

# Load shared configuration
require_relative 'shared_config'

module AgilitonLanes
  class << self
    # Setup App Store Connect API key
    # @return [Hash] Configured API key
    def setup_api_key
      AgilitonConfig.api_key
    end

    # Increment build number in Xcode project
    # @param xcodeproj [String] Path to .xcodeproj file
    def increment_build(xcodeproj:)
      Fastlane::Actions::IncrementBuildNumberAction.run(
        xcodeproj: xcodeproj
      )
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

    # Create standardized TestFlight lane for iOS projects
    # This can be called from individual Fastfiles
    # @param scheme [String] Xcode scheme name
    # @param xcodeproj [String] Path to .xcodeproj file
    # @param changelog [String] What's new in this build
    # @param groups [Array<String>] Tester groups
    # @param run_tests [Boolean] Whether to run tests before building
    def testflight_ios(
      scheme:,
      xcodeproj:,
      changelog:,
      groups: [AgilitonConfig::STANDARD_TESTER_GROUP],
      run_tests: false
    )
      # Run tests if requested
      run_ios_tests(scheme: scheme) if run_tests

      # Increment build number
      increment_build(xcodeproj: xcodeproj)

      # Clean derived data
      clean_build

      # Build the app
      build_ios_app(scheme: scheme)

      # Upload to TestFlight
      upload_testflight(changelog: changelog, groups: groups)

      # Send success notification
      notify_slack(message: "Successfully deployed #{scheme} to TestFlight! 🚀")
    end

    # Create standardized TestFlight lane for macOS projects
    # @param scheme [String] Xcode scheme name
    # @param xcodeproj [String] Path to .xcodeproj file
    # @param app_identifier [String] Bundle identifier
    # @param changelog [String] What's new in this build
    # @param groups [Array<String>] Tester groups
    def testflight_macos(
      scheme:,
      xcodeproj:,
      app_identifier:,
      changelog:,
      groups: [AgilitonConfig::STANDARD_TESTER_GROUP]
    )
      # Setup API key
      api_key = setup_api_key

      # Increment build number
      increment_build(xcodeproj: xcodeproj)

      # Build the app
      build_macos_app(scheme: scheme, xcodeproj: xcodeproj)

      # Upload to TestFlight
      upload_testflight(
        changelog: changelog,
        groups: groups,
        app_identifier: app_identifier,
        uses_non_exempt_encryption: false
      )

      # Send success notification
      notify_slack(message: "Successfully deployed #{scheme} to TestFlight! 🚀")
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
#       AgilitonLanes.testflight_ios(
#         scheme: "MyApp",
#         xcodeproj: "MyApp.xcodeproj",
#         changelog: "Bug fixes and improvements"
#       )
#     end
#   end
