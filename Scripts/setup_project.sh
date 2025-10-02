#!/bin/bash
# Agiliton Project Setup Script
# Version: 1.0.0
#
# This script sets up a new or existing Agiliton project with shared infrastructure:
# - Git hooks (pre-commit tests)
# - Fastlane configuration templates
# - Test configuration utilities
# - CI/CD workflows
#
# Usage: ./setup_project.sh [project-path]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Determine paths
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SHARED_ROOT="$(dirname "$SCRIPT_DIR")"
PROJECT_DIR="${1:-.}"

cd "$PROJECT_DIR"
PROJECT_NAME=$(basename "$PWD")

echo -e "${BLUE}🚀 Agiliton Project Setup${NC}"
echo -e "${BLUE}=========================${NC}"
echo ""
echo "Project: $PROJECT_NAME"
echo "Location: $PWD"
echo ""

# Check if this is a git repository
if [ ! -d ".git" ]; then
  echo -e "${RED}❌ Not a git repository: $PROJECT_DIR${NC}"
  echo "Run 'git init' first to initialize a git repository."
  exit 1
fi

# Function to install git hooks
install_git_hooks() {
  echo -e "${YELLOW}📦 Installing git hooks...${NC}"

  mkdir -p .git/hooks

  # Copy pre-commit hook
  cp "$SHARED_ROOT/Scripts/GitHooks/pre-commit" .git/hooks/pre-commit
  chmod +x .git/hooks/pre-commit

  echo -e "${GREEN}✅ Git hooks installed${NC}"
  echo "   • pre-commit - Runs tests before each commit"
  echo ""
}

# Function to setup Fastlane
setup_fastlane() {
  echo -e "${YELLOW}📦 Setting up Fastlane...${NC}"

  # Create fastlane directory if it doesn't exist
  mkdir -p fastlane

  # Check if Fastfile already exists
  if [ -f "fastlane/Fastfile" ]; then
    echo -e "${YELLOW}⚠️  Fastfile already exists${NC}"
    read -p "Do you want to add shared lane imports? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      # Add import at the top of Fastfile if not already present
      if ! grep -q "AgilitonShared/Scripts/Fastlane" fastlane/Fastfile; then
        echo "" >> fastlane/Fastfile
        echo "# Agiliton Shared Infrastructure" >> fastlane/Fastfile
        echo "import \"#{ENV['HOME']}/VisualStudio/AgilitonShared/Scripts/Fastlane/shared_config.rb\"" >> fastlane/Fastfile
        echo "import \"#{ENV['HOME']}/VisualStudio/AgilitonShared/Scripts/Fastlane/shared_lanes.rb\"" >> fastlane/Fastfile
        echo -e "${GREEN}✅ Added shared lane imports to existing Fastfile${NC}"
      else
        echo -e "${GREEN}✅ Fastfile already imports shared lanes${NC}"
      fi
    fi
  else
    # Detect platform
    if [ -f "*.xcodeproj/project.pbxproj" ]; then
      # Check if it's iOS or macOS
      if grep -q "IPHONEOS_DEPLOYMENT_TARGET" *.xcodeproj/project.pbxproj; then
        PLATFORM="ios"
      else
        PLATFORM="mac"
      fi
    else
      echo "Platform (ios/mac):"
      read PLATFORM
    fi

    # Create Fastfile template
    cat > fastlane/Fastfile <<EOF
# This file contains the fastlane.tools configuration
# You can find the documentation at https://docs.fastlane.tools

# Agiliton Shared Infrastructure
import "#{ENV['HOME']}/VisualStudio/AgilitonShared/Scripts/Fastlane/shared_config.rb"
import "#{ENV['HOME']}/VisualStudio/AgilitonShared/Scripts/Fastlane/shared_lanes.rb"

default_platform(:$PLATFORM)

platform :$PLATFORM do
  desc "Deploy to TestFlight"
  lane :testflight do
    # TODO: Configure for your project
    # For iOS:
    # AgilitonLanes.testflight_ios(
    #   scheme: "YourScheme",
    #   xcodeproj: "YourProject.xcodeproj",
    #   changelog: "Bug fixes and improvements"
    # )
    #
    # For macOS:
    # AgilitonLanes.testflight_macos(
    #   scheme: "YourScheme",
    #   xcodeproj: "YourProject.xcodeproj",
    #   app_identifier: "com.agiliton.yourapp",
    #   changelog: "Bug fixes and improvements"
    # )
  end

  desc "Run tests with coverage"
  lane :test do
    # TODO: Configure for your project
    # AgilitonLanes.run_ios_tests(scheme: "YourScheme")
  end
end
EOF

    echo -e "${GREEN}✅ Created Fastfile template${NC}"
    echo -e "${YELLOW}⚠️  Remember to configure the lanes for your specific project${NC}"
  fi

  echo ""
}

# Function to setup test configuration
setup_test_config() {
  echo -e "${YELLOW}📦 Setting up test configuration...${NC}"

  # Find Xcode project
  XCODEPROJ=$(find . -maxdepth 1 -name "*.xcodeproj" -type d | head -n 1)

  if [ -z "$XCODEPROJ" ]; then
    echo -e "${YELLOW}⚠️  No Xcode project found, skipping test configuration${NC}"
    echo ""
    return
  fi

  SCHEME=$(basename "$XCODEPROJ" .xcodeproj)

  echo "Found Xcode project: $SCHEME"
  echo ""
  echo "Would you like to run the test configuration checker? (y/n)"
  read -r response

  if [[ "$response" =~ ^[Yy]$ ]]; then
    # Try to auto-detect test target
    TEST_TARGET="${SCHEME}Tests"

    echo "Detecting issues for test target: $TEST_TARGET"
    ruby "$SHARED_ROOT/Scripts/Xcode/test_configuration.rb" \
      --project "$XCODEPROJ" \
      --test-target "$TEST_TARGET" \
      --detect || true

    echo ""
    echo "Would you like to automatically fix detected issues? (y/n)"
    read -r fix_response

    if [[ "$fix_response" =~ ^[Yy]$ ]]; then
      ruby "$SHARED_ROOT/Scripts/Xcode/test_configuration.rb" \
        --project "$XCODEPROJ" \
        --test-target "$TEST_TARGET"
      echo -e "${GREEN}✅ Test configuration fixed${NC}"
    fi
  fi

  echo ""
}

# Function to create CI workflow
setup_ci_workflow() {
  echo -e "${YELLOW}📦 Setting up CI/CD workflow...${NC}"

  mkdir -p .github/workflows

  if [ -f ".github/workflows/ci.yml" ]; then
    echo -e "${YELLOW}⚠️  CI workflow already exists${NC}"
  else
    # Find Xcode project for scheme name
    XCODEPROJ=$(find . -maxdepth 1 -name "*.xcodeproj" -type d | head -n 1)
    SCHEME=$(basename "$XCODEPROJ" .xcodeproj)

    # Detect platform
    if [ -f "$XCODEPROJ/project.pbxproj" ]; then
      if grep -q "IPHONEOS_DEPLOYMENT_TARGET" "$XCODEPROJ/project.pbxproj"; then
        PLATFORM="iOS Simulator"
        DESTINATION="platform=iOS Simulator,name=iPhone 17 Pro"
      else
        PLATFORM="macOS"
        DESTINATION="platform=macOS"
      fi
    fi

    cat > .github/workflows/ci.yml <<EOF
name: CI

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main, develop ]

jobs:
  test:
    name: Run Tests
    runs-on: macos-latest

    steps:
    - uses: actions/checkout@v3

    - name: Select Xcode version
      run: sudo xcode-select -s /Applications/Xcode_15.2.app

    - name: Run tests
      run: |
        xcodebuild test \\
          -project $SCHEME.xcodeproj \\
          -scheme $SCHEME \\
          -destination '$DESTINATION' \\
          -enableCodeCoverage YES \\
          CODE_SIGN_IDENTITY="" \\
          CODE_SIGNING_REQUIRED=NO

    - name: Upload coverage reports
      uses: codecov/codecov-action@v3
      with:
        fail_ci_if_error: false
EOF

    echo -e "${GREEN}✅ Created CI workflow${NC}"
  fi

  echo ""
}

# Main setup flow
echo -e "${BLUE}What would you like to set up?${NC}"
echo "1. Everything (recommended for new projects)"
echo "2. Git hooks only"
echo "3. Fastlane only"
echo "4. Test configuration only"
echo "5. CI/CD workflow only"
echo ""
read -p "Choice (1-5): " -n 1 -r choice
echo ""
echo ""

case $choice in
  1)
    install_git_hooks
    setup_fastlane
    setup_test_config
    setup_ci_workflow
    ;;
  2)
    install_git_hooks
    ;;
  3)
    setup_fastlane
    ;;
  4)
    setup_test_config
    ;;
  5)
    setup_ci_workflow
    ;;
  *)
    echo -e "${RED}Invalid choice${NC}"
    exit 1
    ;;
esac

echo -e "${GREEN}✅ Setup complete!${NC}"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "1. Review and customize Fastfile for your project"
echo "2. Run tests: xcodebuild test -scheme YourScheme"
echo "3. Deploy to TestFlight: fastlane testflight"
echo ""
echo -e "${BLUE}Documentation:${NC}"
echo "Shared infrastructure docs: $SHARED_ROOT/Docs/Setup/README.md"
echo ""
