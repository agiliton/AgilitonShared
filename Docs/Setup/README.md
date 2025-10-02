# Agiliton Shared Infrastructure

Version: 1.0.0

This repository contains shared development infrastructure for all Agiliton projects, eliminating redundancy and ensuring consistency across projects like BestGPT, SmartTranslate, and future applications.

## 📚 Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Components](#components)
  - [Git Hooks](#git-hooks)
  - [Fastlane Lanes](#fastlane-lanes)
  - [Xcode Configuration](#xcode-configuration)
  - [CI/CD Workflows](#cicd-workflows)
- [Usage Examples](#usage-examples)
- [Troubleshooting](#troubleshooting)

## Overview

The shared infrastructure provides:

- **Git Hooks**: Automated pre-commit testing across all projects
- **Fastlane Configuration**: Reusable deployment lanes for iOS and macOS
- **Xcode Utilities**: Ruby scripts for test target configuration
- **CI/CD Templates**: GitHub Actions workflows
- **Project Setup**: One-command project initialization

## Quick Start

### Setting Up a New Project

```bash
cd /path/to/your/project
~/VisualStudio/AgilitonShared/Scripts/setup_project.sh
```

The setup script will guide you through:
1. Installing git hooks
2. Configuring Fastlane
3. Setting up test configuration
4. Creating CI/CD workflows

### Setting Up an Existing Project

Same as above! The setup script detects existing configuration and offers to update it.

## Components

### Git Hooks

Located in: `Scripts/GitHooks/`

#### Pre-Commit Hook

Automatically runs tests before each commit to catch issues early.

**Features:**
- Auto-detects Xcode project and scheme
- Finds available simulators (iPhone 15/16/17 Pro)
- Runs tests and blocks commit if they fail
- Can be skipped with `git commit --no-verify`

**Installation:**

```bash
~/VisualStudio/AgilitonShared/Scripts/GitHooks/install-hooks.sh
```

**Manual Installation:**

```bash
cp ~/VisualStudio/AgilitonShared/Scripts/GitHooks/pre-commit .git/hooks/
chmod +x .git/hooks/pre-commit
```

### Fastlane Lanes

Located in: `Scripts/Fastlane/`

#### Shared Configuration (`shared_config.rb`)

Common configuration values:

```ruby
AgilitonConfig.api_key              # App Store Connect API key
AgilitonConfig.ios_export_options   # iOS export settings
AgilitonConfig.macos_export_options # macOS export settings
AgilitonConfig.testflight_options   # TestFlight upload settings
```

#### Shared Lanes (`shared_lanes.rb`)

Reusable deployment lanes:

**iOS Projects:**

```ruby
AgilitonLanes.testflight_ios(
  scheme: "MyApp",
  xcodeproj: "MyApp.xcodeproj",
  changelog: "Bug fixes and improvements",
  run_tests: true
)
```

**macOS Projects:**

```ruby
AgilitonLanes.testflight_macos(
  scheme: "MyApp",
  xcodeproj: "MyApp.xcodeproj",
  app_identifier: "com.agiliton.myapp",
  changelog: "Bug fixes and improvements"
)
```

**Running Tests:**

```ruby
AgilitonLanes.run_ios_tests(
  scheme: "MyApp",
  devices: ["iPhone 17 Pro"]
)
```

#### Using Shared Lanes in Your Project

Add to your `fastlane/Fastfile`:

```ruby
# Import shared infrastructure
import "#{ENV['HOME']}/VisualStudio/AgilitonShared/Scripts/Fastlane/shared_config.rb"
import "#{ENV['HOME']}/VisualStudio/AgilitonShared/Scripts/Fastlane/shared_lanes.rb"

default_platform(:ios)

platform :ios do
  desc "Deploy to TestFlight"
  lane :testflight do
    AgilitonLanes.testflight_ios(
      scheme: "AgilitonBestGPT",
      xcodeproj: "AgilitonBestGPT.xcodeproj",
      changelog: "Bug fixes and improvements"
    )
  end

  desc "Run tests"
  lane :test do
    AgilitonLanes.run_ios_tests(scheme: "AgilitonBestGPT")
  end
end
```

### Xcode Configuration

Located in: `Scripts/Xcode/`

#### Test Configuration Utility (`test_configuration.rb`)

Fixes common Xcode test target configuration issues:

- Empty PRODUCT_NAME causing invalid test bundle names
- Deployment target mismatches between app and test targets
- Duplicate files in test target causing symbol conflicts
- Missing TEST_HOST configuration

**Command Line Usage:**

```bash
# Detect issues
ruby ~/VisualStudio/AgilitonShared/Scripts/Xcode/test_configuration.rb \
  --project MyApp.xcodeproj \
  --test-target MyAppTests \
  --detect

# Fix all issues
ruby ~/VisualStudio/AgilitonShared/Scripts/Xcode/test_configuration.rb \
  --project MyApp.xcodeproj \
  --test-target MyAppTests

# Fix and remove duplicate files
ruby ~/VisualStudio/AgilitonShared/Scripts/Xcode/test_configuration.rb \
  --project MyApp.xcodeproj \
  --test-target MyAppTests \
  --remove LoggingService.swift,NetworkManager.swift
```

**Programmatic Usage:**

```ruby
require_relative 'path/to/test_configuration'

# Fix all issues automatically
TestConfig.fix_all(
  project_path: 'MyApp.xcodeproj',
  test_target_name: 'MyAppTests',
  files_to_remove: ['LoggingService.swift']
)

# Or fix individual issues
project = Xcodeproj::Project.open('MyApp.xcodeproj')
test_target = project.targets.find { |t| t.name == 'MyAppTests' }
main_target = project.targets.find { |t| t.name == 'MyApp' }

TestConfig.fix_product_name(project: project, test_target: test_target, main_target: main_target)
TestConfig.fix_deployment_target(project: project, test_target: test_target, main_target: main_target)
project.save
```

### CI/CD Workflows

Located in: `Scripts/CI/`

The setup script can generate GitHub Actions workflows for your project with:
- Automatic testing on push/PR
- Code coverage reporting
- Platform-specific configurations (iOS/macOS)

## Usage Examples

### Example 1: BestGPT (iOS App)

**Fastfile:**

```ruby
import "#{ENV['HOME']}/VisualStudio/AgilitonShared/Scripts/Fastlane/shared_config.rb"
import "#{ENV['HOME']}/VisualStudio/AgilitonShared/Scripts/Fastlane/shared_lanes.rb"

default_platform(:ios)

platform :ios do
  desc "Deploy to TestFlight"
  lane :testflight do
    AgilitonLanes.testflight_ios(
      scheme: "AgilitonBestGPT",
      xcodeproj: "AgilitonBestGPT.xcodeproj",
      changelog: "Comprehensive test infrastructure added (125 tests). Bug fixes and improvements.",
      run_tests: false  # Tests run via pre-commit hook
    )
  end

  desc "Run tests"
  lane :test do
    AgilitonLanes.run_ios_tests(
      scheme: "AgilitonBestGPT",
      devices: ["iPhone 17 Pro"]
    )
  end
end
```

**Deployment:**

```bash
cd ~/VisualStudio/BestGPT
fastlane testflight
```

### Example 2: SmartTranslate (macOS App)

**Fastfile:**

```ruby
import "#{ENV['HOME']}/VisualStudio/AgilitonShared/Scripts/Fastlane/shared_config.rb"
import "#{ENV['HOME']}/VisualStudio/AgilitonShared/Scripts/Fastlane/shared_lanes.rb"

default_platform(:mac)

platform :mac do
  desc "Deploy to TestFlight"
  lane :testflight do
    AgilitonLanes.testflight_macos(
      scheme: "SmartTranslate",
      xcodeproj: "SmartTranslate.xcodeproj",
      app_identifier: "eu.agiliton.smarttranslate",
      changelog: "Settings UI improvements and bug fixes"
    )
  end
end
```

**Deployment:**

```bash
cd ~/VisualStudio/SmartTranslate
fastlane testflight
```

### Example 3: Fixing Test Configuration Issues

```bash
cd ~/VisualStudio/MyNewApp

# Detect issues
ruby ~/VisualStudio/AgilitonShared/Scripts/Xcode/test_configuration.rb \
  --project MyNewApp.xcodeproj \
  --test-target MyNewAppTests \
  --detect

# Fix issues
ruby ~/VisualStudio/AgilitonShared/Scripts/Xcode/test_configuration.rb \
  --project MyNewApp.xcodeproj \
  --test-target MyNewAppTests

# Run tests to verify
xcodebuild test -scheme MyNewApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

## Directory Structure

```
AgilitonShared/
├── Scripts/
│   ├── GitHooks/
│   │   ├── pre-commit              # Auto-testing hook
│   │   └── install-hooks.sh        # Hook installer
│   ├── Fastlane/
│   │   ├── shared_config.rb        # Common configuration
│   │   └── shared_lanes.rb         # Reusable lanes
│   ├── Xcode/
│   │   └── test_configuration.rb   # Test target utilities
│   ├── CI/
│   │   └── (CI/CD templates)
│   └── setup_project.sh            # Project setup script
└── Docs/
    └── Setup/
        └── README.md               # This file
```

## Troubleshooting

### Git Hook Not Running

**Problem:** Pre-commit hook doesn't execute

**Solutions:**
1. Check hook is executable: `ls -l .git/hooks/pre-commit`
2. Make executable: `chmod +x .git/hooks/pre-commit`
3. Verify hook location: `.git/hooks/pre-commit` (not `.git/hooks/pre-commit.sh`)

### Fastlane Import Errors

**Problem:** `cannot load such file -- shared_config`

**Solutions:**
1. Verify path in Fastfile: `import "#{ENV['HOME']}/VisualStudio/AgilitonShared/Scripts/Fastlane/shared_config.rb"`
2. Check file exists: `ls ~/VisualStudio/AgilitonShared/Scripts/Fastlane/`
3. Use absolute path if needed

### Test Configuration Not Working

**Problem:** Tests still failing after running fix script

**Solutions:**
1. Clean build folder: `rm -rf ~/Library/Developer/Xcode/DerivedData`
2. Verify Xcode project: `xcodebuild -list`
3. Check test target name: Open project in Xcode and verify exact name
4. Run with verbose output: `ruby script.rb --project ... --test-target ... -v`

### Simulator Not Found

**Problem:** Pre-commit hook can't find simulator

**Solutions:**
1. List available simulators: `xcrun simctl list devices available`
2. Update hook to use available simulator
3. Install iOS 17 runtime if needed

## Credentials Setup

### App Store Connect API Key

Required for TestFlight deployments.

**Location:** `~/.fastlane/agiliton/credentials/AuthKey_29D5LPCY4W.p8`

**Setup:**
1. Download API key from App Store Connect
2. Create directory: `mkdir -p ~/.fastlane/agiliton/credentials`
3. Copy key: `cp ~/Downloads/AuthKey_*.p8 ~/.fastlane/agiliton/credentials/`

### Team Configuration

All Agiliton projects use:
- **Team ID:** 4S7KX75F3B
- **Team Name:** Agiliton Ltd.
- **API Key ID:** 29D5LPCY4W
- **Issuer ID:** f5fba1cb-a516-4756-83b5-2860edef9f08

These are configured automatically in `shared_config.rb`.

## Contributing

When updating shared infrastructure:

1. **Version Bump:** Update version in file headers
2. **Test:** Test changes in at least 2 projects (iOS + macOS)
3. **Document:** Update this README
4. **Communicate:** Notify all project teams of breaking changes

## Support

For issues or questions:
- Check this documentation
- Review example projects (BestGPT, SmartTranslate)
- Contact: christian.gick@icloud.com

---

**Last Updated:** 2025-10-02
**Version:** 1.0.0
**Maintainer:** Christian Gick
