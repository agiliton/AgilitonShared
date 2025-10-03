# Agiliton Fastlane v2.0 Migration Guide

## Overview
This guide helps migrate all Agiliton projects to the unified deployment system v2.0.

## Key Problems Solved

### 1. **Old PKG Files Causing Silent Upload Failures**
- **Problem**: Old .pkg files in project root were being uploaded instead of new builds
- **Solution**: Automatic cleanup of old artifacts before each build

### 2. **Build Number Conflicts**
- **Error**: "The bundle version must be higher than the previously uploaded version"
- **Solution**: Build number verification and sync with App Store Connect

### 3. **Silent Upload Failures**
- **Problem**: Fastlane reports success but build doesn't appear in App Store Connect
- **Solution**: Enhanced error checking of altool logs

### 4. **UTF-8 Encoding Issues**
- **Problem**: Emoji characters in shared lanes causing encoding errors
- **Solution**: Proper UTF-8 configuration and environment setup

### 5. **Inconsistent Output Paths**
- **Problem**: Different projects using different build output locations
- **Solution**: Standardized `build/` directory for all projects

## Migration Steps

### Step 1: Backup Current Fastfile
```bash
cd your-project/fastlane
cp Fastfile Fastfile.backup.$(date +%Y%m%d)
```

### Step 2: Create New Fastfile
Copy the template and customize:
```bash
cp ~/VisualStudio/AgilitonShared/Scripts/Fastlane/fastfile_template.rb Fastfile
```

### Step 3: Update Project Configuration
Edit your new Fastfile and update the PROJECT_CONFIG section:
```ruby
PROJECT_CONFIG = {
  scheme: "YourAppScheme",               # Your actual scheme name
  xcodeproj: "YourApp.xcodeproj",       # Your xcodeproj path
  app_identifier: "com.agiliton.yourapp", # Your bundle ID
  platform: :mac,                        # or :ios
  app_name: "Your App Name"             # Display name
}
```

### Step 4: Clean Up Old Artifacts
```bash
# Remove old pkg files from project root
fastlane cleanup

# Or manually:
mv *.pkg *.pkg.old 2>/dev/null
rm -f *.dSYM.zip
```

### Step 5: Test the New Configuration
```bash
# Test build without upload
fastlane build_only

# If successful, test full deployment
fastlane testflight
```

## Common Issues and Solutions

### Issue 1: Build Number Too Low
```bash
# Fix: Sync with App Store Connect
fastlane fix_deployment
# Enter the current highest build number when prompted
```

### Issue 2: UTF-8 Errors
```bash
# Fix: Set locale in your shell profile
echo 'export LC_ALL=en_US.UTF-8' >> ~/.zshrc
echo 'export LANG=en_US.UTF-8' >> ~/.zshrc
source ~/.zshrc
```

### Issue 3: Old PKG Being Uploaded
```bash
# Fix: Clean all old artifacts
find . -name "*.pkg" -mtime +1 -exec mv {} {}.old \;
fastlane cleanup
```

### Issue 4: 2FA Prompts Despite API Key
```bash
# Fix: Ensure API key is properly configured
ls -la ~/.fastlane/agiliton/credentials/AuthKey_29D5LPCY4W.p8

# If missing, copy from backup:
mkdir -p ~/.fastlane/agiliton/credentials
cp /path/to/backup/AuthKey_29D5LPCY4W.p8 ~/.fastlane/agiliton/credentials/
```

## Project-Specific Configurations

### Assist for Jira
```ruby
PROJECT_CONFIG = {
  scheme: "JiraMacApp",
  xcodeproj: "JiraMacApp.xcodeproj",
  app_identifier: "com.agiliton.jiraassist.desktop",
  platform: :mac,
  app_name: "Assist for Jira"
}
```

### SmartTranslate
```ruby
PROJECT_CONFIG = {
  scheme: "SmartTranslate",
  xcodeproj: "SmartTranslate.xcodeproj",
  app_identifier: "com.agiliton.smarttranslate",
  platform: :mac,
  app_name: "SmartTranslate"
}
```

### Of Bulls And Bears
```ruby
PROJECT_CONFIG = {
  scheme: "Bulls & Bears",
  xcodeproj: "Bulls & Bears.xcodeproj",
  app_identifier: "com.agiliton.bullsandbears",
  platform: :ios,
  app_name: "Of Bulls And Bears"
}
```

### BestGPT
```ruby
PROJECT_CONFIG = {
  scheme: "AgilitonBestGPT",
  xcodeproj: "AgilitonBestGPT.xcodeproj",
  app_identifier: "com.agiliton.bestgpt",
  platform: :ios,
  app_name: "BestGPT"
}
```

## New Features Available

### 1. Quick Upload (No Build Increment)
```bash
fastlane quick_upload changelog:"Quick fix"
```

### 2. Add Testers to Existing Build
```bash
fastlane add_testers groups:["Beta Testers","VIP Testers"]
```

### 3. Check Upload Status
```bash
fastlane check_status
```

### 4. Fix Common Issues
```bash
fastlane fix_deployment
```

### 5. Build Only (No Upload)
```bash
fastlane build_only
```

## Best Practices

1. **Always run cleanup before major releases**
   ```bash
   fastlane cleanup
   fastlane testflight
   ```

2. **Use descriptive changelogs**
   ```bash
   fastlane testflight changelog:"Fixed crash on startup, improved performance"
   ```

3. **Check status if upload seems stuck**
   ```bash
   fastlane check_status
   ```

4. **Keep local build numbers in sync**
   ```bash
   # If you get build number errors
   fastlane fix_deployment
   ```

5. **Use version control for Fastfile**
   ```bash
   git add fastlane/Fastfile
   git commit -m "Migrate to Agiliton Fastlane v2.0"
   ```

## Environment Setup

Add to your `~/.zshrc` or `~/.bash_profile`:
```bash
# Fastlane UTF-8 support
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8

# Fastlane alias for quick access
alias ft="fastlane testflight"
alias fts="fastlane check_status"
alias ftc="fastlane cleanup"
```

## Monitoring Deployments

Check these locations for issues:
1. **App Store Connect**: https://appstoreconnect.apple.com/
2. **Altool Logs**: `~/Library/Logs/ContentDelivery/com.apple.itunes.altool/`
3. **Fastlane Reports**: `./fastlane/report.xml`

## Support

If you encounter issues:
1. Run `fastlane check_status` to diagnose
2. Check the altool logs for detailed errors
3. Run `fastlane fix_deployment` for automatic fixes
4. Check this guide's Common Issues section

## Changelog

### v2.0 (2025-10-03)
- Added automatic artifact cleanup
- Enhanced error detection from altool logs
- Standardized build output paths
- Fixed UTF-8 encoding issues
- Added build number validation
- Created unified deployment system

### v1.0 (Original)
- Basic TestFlight upload
- Manual build number management
- No error detection for silent failures