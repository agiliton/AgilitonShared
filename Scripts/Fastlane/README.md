# Agiliton Shared Fastlane Configuration

## Critical Export Compliance Fix

### The Problem

Builds were getting stuck in "Auf Upload warten" (Waiting for Upload) status in TestFlight because export compliance wasn't being automatically submitted.

**Root Cause**: Using `skip_waiting_for_build_processing: true` prevents fastlane from:
1. Waiting for Apple to process the build
2. Automatically submitting export compliance declarations
3. Making the build available for testing

### The Solution

All Agiliton macOS apps must use these **critical settings**:

```ruby
upload_to_testflight(
  api_key: api_key,
  uses_non_exempt_encryption: false,       # Declares no encryption
  skip_waiting_for_build_processing: false, # MUST wait for processing
  wait_for_uploaded_build: true,           # Ensures compliance submitted
  distribute_external: true,
  groups: ["Beta Testers"],
  notify_external_testers: true,
  distribute_only: false
)
```

And in gym export_options:

```ruby
export_options: {
  ITSAppUsesNonExemptEncryption: false,  # Must match upload setting
  manageAppVersionAndBuildNumber: false,
  teamID: "4S7KX75F3B"
}
```

## Usage

### Import in your Fastfile

```ruby
# At the top of your Fastfile
import "#{ENV['HOME']}/VisualStudio/AgilitonShared/Scripts/Fastlane/agiliton_testflight_config.rb"
```

### Option 1: Use Pre-configured Settings

```ruby
desc "Deploy to TestFlight"
lane :testflight do
  api_key = setup_api_key

  increment_build_number(xcodeproj: "YourApp.xcodeproj")

  # Build
  gym(agiliton_testflight_gym_config(
    scheme: "YourScheme",
    project: "./YourApp.xcodeproj"
  ))

  # Upload with automatic export compliance
  upload_to_testflight(agiliton_testflight_upload_config(
    api_key: api_key,
    app_identifier: "com.agiliton.yourapp",  # Optional
    groups: ["Beta Testers"],
    changelog: "Your changelog here"
  ))
end
```

### Option 2: Use Complete Deployment Helper

```ruby
desc "Deploy to TestFlight"
lane :testflight do
  api_key = setup_api_key

  agiliton_deploy_testflight(
    api_key: api_key,
    scheme: "YourScheme",
    app_identifier: "com.agiliton.yourapp",
    project: "./YourApp.xcodeproj",
    xcodeproj_for_build_increment: "YourApp.xcodeproj",
    groups: ["Beta Testers"],
    changelog: "Your changelog here"
  )
end
```

## Why This Matters

### Without These Settings

- ❌ Build stays in "Auf Upload warten" (Waiting for Upload)
- ❌ Export compliance must be manually submitted via web interface
- ❌ Build never becomes available to testers
- ❌ Can't add build to App Store versions

### With These Settings

- ✅ Build processes automatically
- ✅ Export compliance auto-submitted
- ✅ Build becomes available to testers immediately
- ✅ Can add build to App Store versions
- ✅ Fully automated TestFlight deployment

## Affected Projects

This fix has been applied to:
- **Assist for Jira**: Fixed critical bug where `skip_waiting_for_build_processing: true`
- **SmartTranslate**: Already had correct settings, now uses shared config

## Testing the Fix

After deploying with fixed settings:

1. Upload completes successfully
2. Check TestFlight → macOS → Builds
3. Build should show "Wird verarbeitet" (Processing) for 10-20 minutes
4. Then changes to ready with green checkmark
5. Can immediately add to App Store version

## Files Modified

- `AgilitonShared/Scripts/Fastlane/agiliton_testflight_config.rb` - New shared config
- `Assist for Jira/fastlane/Fastfile` - Fixed critical bug on line 52
- `SmartTranslate/fastlane/Fastfile` - Updated to use shared config

## References

- Apple Export Compliance: https://developer.apple.com/documentation/security/complying_with_encryption_export_regulations
- Fastlane TestFlight: https://docs.fastlane.tools/actions/upload_to_testflight/
- App Store Connect API: https://developer.apple.com/documentation/appstoreconnectapi
