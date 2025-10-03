# Agiliton Unified Fastfile Template
#
# This template provides a standardized Fastfile for all Agiliton projects.
# Copy this to your project's fastlane/Fastfile and customize the project-specific values.
#
# Version: 2.0

# Import Agiliton shared infrastructure
import "#{ENV['HOME']}/VisualStudio/AgilitonShared/Scripts/Fastlane/shared_config.rb"
import "#{ENV['HOME']}/VisualStudio/AgilitonShared/Scripts/Fastlane/agiliton_deployment_v2.rb"

# ================================
# PROJECT CONFIGURATION - CUSTOMIZE THESE
# ================================

# Your project settings
PROJECT_CONFIG = {
  scheme: "YourAppScheme",                              # Your Xcode scheme name
  xcodeproj: "YourApp.xcodeproj",                      # Path to xcodeproj
  app_identifier: "com.agiliton.yourapp",              # Bundle identifier
  platform: :mac,                                      # :mac or :ios
  app_name: "Your App Name"                            # Display name
}

# ================================
# LANES - Standard deployment lanes
# ================================

default_platform(PROJECT_CONFIG[:platform])

platform PROJECT_CONFIG[:platform] do

  # --------------------------------
  # Main TestFlight deployment lane
  # --------------------------------
  desc "Deploy to TestFlight with all safety checks"
  lane :testflight do |options|
    # Use the unified deployment system
    AgilitonDeployment.deploy(
      platform: PROJECT_CONFIG[:platform],
      scheme: PROJECT_CONFIG[:scheme],
      xcodeproj: PROJECT_CONFIG[:xcodeproj],
      app_identifier: PROJECT_CONFIG[:app_identifier],
      changelog: options[:changelog] || "Bug fixes and improvements",
      groups: options[:groups] || ["Beta Testers"],
      increment_build: options[:increment_build] != false,
      clean_artifacts: true
    )
  end

  # --------------------------------
  # Quick upload (no build increment)
  # --------------------------------
  desc "Quick TestFlight upload without incrementing build"
  lane :quick_upload do |options|
    testflight(
      increment_build: false,
      changelog: options[:changelog] || "Quick update"
    )
  end

  # --------------------------------
  # Add testers to existing build
  # --------------------------------
  desc "Add all tester groups to the latest build"
  lane :add_testers do |options|
    api_key = AgilitonConfig.api_key

    UI.message("Adding tester groups to latest #{PROJECT_CONFIG[:app_name]} build...")

    pilot(
      api_key: api_key,
      app_identifier: PROJECT_CONFIG[:app_identifier],
      app_platform: PROJECT_CONFIG[:platform] == :mac ? "osx" : "ios",
      distribute_only: true,
      distribute_external: true,
      groups: options[:groups] || ["Beta Testers", "Testers External"],
      notify_external_testers: true,
      changelog: options[:changelog] || "Build now available for testing"
    )

    UI.success("Successfully distributed to tester groups!")
  end

  # --------------------------------
  # Cleanup old artifacts
  # --------------------------------
  desc "Clean up old build artifacts"
  lane :cleanup do
    AgilitonDeployment.cleanup_old_artifacts(project_root: Dir.pwd)
  end

  # --------------------------------
  # Check build status
  # --------------------------------
  desc "Check build status and logs"
  lane :check_status do
    AgilitonDeployment.check_altool_logs
    UI.message("Check App Store Connect: https://appstoreconnect.apple.com/")
  end

  # --------------------------------
  # Emergency fixes
  # --------------------------------
  desc "Fix common deployment issues"
  lane :fix_deployment do
    UI.header("🔧 Running deployment fixes")

    # 1. Clean old artifacts
    cleanup

    # 2. Reset build number to match App Store Connect
    if UI.confirm("Reset build number to sync with App Store Connect?")
      build_number = UI.input("Enter the current highest build number from App Store Connect:")
      sh("agvtool new-version -all #{build_number.to_i + 1}")
      UI.success("Build number set to #{build_number.to_i + 1}")
    end

    # 3. Clear derived data
    if UI.confirm("Clear derived data?")
      sh("rm -rf DerivedData")
      sh("rm -rf ~/Library/Developer/Xcode/DerivedData/*")
      UI.success("Derived data cleared")
    end

    UI.success("Fixes applied. Try running 'fastlane testflight' again.")
  end

  # --------------------------------
  # Development/testing lanes
  # --------------------------------
  desc "Build without uploading (for testing)"
  lane :build_only do
    AgilitonDeployment.build_app(
      platform: PROJECT_CONFIG[:platform],
      scheme: PROJECT_CONFIG[:scheme],
      xcodeproj: PROJECT_CONFIG[:xcodeproj],
      app_identifier: PROJECT_CONFIG[:app_identifier]
    )

    UI.success("Build complete. Check the build/ directory for output.")
  end

end

# ================================
# Error handling
# ================================

error do |lane, exception|
  UI.error("❌ Error in lane #{lane}: #{exception.message}")

  # Check for common errors and provide guidance
  if exception.message.include?("bundle version must be higher")
    UI.important("💡 Solution: Run 'fastlane fix_deployment' to sync build numbers")
  elsif exception.message.include?("Code signing")
    UI.important("💡 Solution: Check your certificates in Xcode")
  elsif exception.message.include?("2FA")
    UI.important("💡 Solution: Make sure API key is configured correctly")
  end

  # Always check altool logs on upload failures
  if lane.to_s.include?("upload") || lane.to_s.include?("testflight")
    AgilitonDeployment.check_altool_logs
  end
end

# ================================
# Notifications (optional)
# ================================

after_all do |lane|
  # Success notification
  if lane != :cleanup && lane != :check_status
    notification(
      title: "#{PROJECT_CONFIG[:app_name]} Deployment",
      message: "Lane #{lane} completed successfully! 🎉"
    ) rescue nil
  end
end