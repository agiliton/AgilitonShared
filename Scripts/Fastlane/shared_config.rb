# Agiliton Shared Fastlane Configuration
# Version: 1.0.0
#
# This file contains common configuration values used across all Agiliton projects.
# Import this at the top of your Fastfile with:
#   import_from_git(url: 'file:///Users/christian.gick/VisualStudio/AgilitonShared')

module AgilitonConfig
  # App Store Connect API Credentials
  API_KEY_ID = "29D5LPCY4W"
  API_ISSUER_ID = "f5fba1cb-a516-4756-83b5-2860edef9f08"
  API_KEY_PATH = "~/.fastlane/agiliton/credentials/AuthKey_29D5LPCY4W.p8"

  # Team Information
  TEAM_ID = "4S7KX75F3B"
  TEAM_NAME = "Agiliton Ltd."

  # TestFlight Configuration
  STANDARD_TESTER_GROUP = "Beta Testers"
  BETA_FEEDBACK_EMAIL = "christian.gick@icloud.com"

  # Common Build Settings
  EXPORT_METHOD = "app-store"

  class << self
    # Returns configured App Store Connect API key
    def api_key
      Fastlane::Actions::AppStoreConnectApiKeyAction.run(
        key_id: API_KEY_ID,
        issuer_id: API_ISSUER_ID,
        key_filepath: API_KEY_PATH
      )
    end

    # Common export options for iOS apps
    def ios_export_options
      {
        manageAppVersionAndBuildNumber: true,
        teamID: TEAM_ID
      }
    end

    # Common export options for macOS apps
    def macos_export_options
      {
        ITSAppUsesNonExemptEncryption: false,
        manageAppVersionAndBuildNumber: false,
        teamID: TEAM_ID
      }
    end

    # Common TestFlight upload options
    def testflight_options(changelog:, groups: [STANDARD_TESTER_GROUP])
      {
        api_key: api_key,
        skip_waiting_for_build_processing: false,
        skip_submission: false,
        distribute_external: true,
        groups: groups,
        notify_external_testers: true,
        changelog: changelog,
        beta_app_feedback_email: BETA_FEEDBACK_EMAIL
      }
    end
  end
end
