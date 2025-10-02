# AgilitonShared

**Version:** 1.0.0

Shared infrastructure and Swift packages for all Agiliton iOS/macOS applications.

## 🎯 What's Included

### Swift Packages

- **AgilitonCore**: Core functionality including logging and utilities
- **AgilitonUI**: Shared UI components
- **AgilitonNetworking**: Networking layer with URLSession
- **AgilitonTesting**: Testing utilities

### Development Infrastructure (New!)

- **Git Hooks**: Pre-commit testing that auto-detects your project
- **Fastlane Lanes**: Reusable deployment lanes for iOS and macOS
- **Xcode Utilities**: Ruby scripts to fix test target configuration
- **Project Setup**: One-command initialization for new projects
- **CI/CD Templates**: GitHub Actions workflow generation

## 🚀 Quick Start

### Set Up Development Infrastructure

```bash
cd /path/to/your/project
~/VisualStudio/AgilitonShared/Scripts/setup_project.sh
```

### Use Shared Fastlane Lanes

Add to your `fastlane/Fastfile`:

```ruby
import "#{ENV['HOME']}/VisualStudio/AgilitonShared/Scripts/Fastlane/shared_config.rb"
import "#{ENV['HOME']}/VisualStudio/AgilitonShared/Scripts/Fastlane/shared_lanes.rb"

platform :ios do
  lane :testflight do
    AgilitonLanes.testflight_ios(
      scheme: "MyApp",
      xcodeproj: "MyApp.xcodeproj",
      changelog: "Bug fixes and improvements"
    )
  end
end
```

### Use Swift Packages

Add to your `Package.swift`:

```swift
dependencies: [
    .package(path: "../AgilitonShared")
]
```

## 📚 Documentation

- **Development Infrastructure**: [Docs/Setup/README.md](Docs/Setup/README.md)
- **Swift Packages**: See individual package documentation

## 🏗️ Directory Structure

```
AgilitonShared/
├── Scripts/                # Development infrastructure
│   ├── GitHooks/          # Pre-commit hooks
│   ├── Fastlane/          # Shared Fastlane lanes
│   ├── Xcode/             # Xcode configuration utilities
│   ├── CI/                # CI/CD templates
│   └── setup_project.sh   # Project setup script
├── Sources/               # Swift package sources
│   ├── AgilitonCore/
│   ├── AgilitonUI/
│   ├── AgilitonNetworking/
│   └── AgilitonTesting/
├── Tests/                 # Swift package tests
└── Docs/                  # Documentation
    └── Setup/
        └── README.md      # Infrastructure documentation
```

## 🎯 Projects Using AgilitonShared

- **BestGPT** (iOS): AI chat app with 113 tests
- **SmartTranslate** (macOS): Translation tool with 131 tests

## 🔧 Common Tasks

**Deploy to TestFlight:**
```bash
fastlane testflight
```

**Fix Test Configuration:**
```bash
~/VisualStudio/AgilitonShared/Scripts/Xcode/test_configuration.rb \
  --project MyApp.xcodeproj --test-target MyAppTests
```

**Install Git Hooks:**
```bash
~/VisualStudio/AgilitonShared/Scripts/GitHooks/install-hooks.sh
```

## 📞 Support

- Full Documentation: [Docs/Setup/README.md](Docs/Setup/README.md)
- Contact: christian.gick@icloud.com

---

**Maintainer:** Christian Gick
**Last Updated:** 2025-10-02