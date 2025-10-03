#!/bin/bash

# Agiliton Fastlane Migration Script v2.0
# Automatically migrates all projects to the new unified deployment system

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Base directory
BASE_DIR="$HOME/VisualStudio"
SHARED_DIR="$BASE_DIR/AgilitonShared/Scripts/Fastlane"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Agiliton Fastlane v2.0 Migration Script${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Projects to migrate
declare -a PROJECTS=(
  "Assist for Jira/worktrees/main:JiraMacApp:JiraMacApp.xcodeproj:com.agiliton.jiraassist.desktop:mac"
  "SmartTranslate:SmartTranslate:SmartTranslate.xcodeproj:com.agiliton.smarttranslate:mac"
  "Of Bulls And Bears:Bulls & Bears:Bulls & Bears.xcodeproj:com.agiliton.bullsandbears:ios"
  "BestGPT:AgilitonBestGPT:AgilitonBestGPT.xcodeproj:com.agiliton.bestgpt:ios"
  "Bridge/bridge-1:Bridge:Bridge.xcodeproj:com.agiliton.bridge:ios"
)

# Function to migrate a project
migrate_project() {
  local project_info="$1"
  IFS=':' read -r project_path scheme xcodeproj app_id platform <<< "$project_info"

  local full_path="$BASE_DIR/$project_path"
  local fastfile_path="$full_path/fastlane/Fastfile"

  echo -e "${YELLOW}Migrating: $project_path${NC}"

  # Check if project exists
  if [ ! -d "$full_path" ]; then
    echo -e "${RED}  ✗ Project not found: $full_path${NC}"
    return 1
  fi

  # Backup existing Fastfile
  if [ -f "$fastfile_path" ]; then
    backup_name="$fastfile_path.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$fastfile_path" "$backup_name"
    echo -e "${GREEN}  ✓ Backed up Fastfile to: $(basename $backup_name)${NC}"
  fi

  # Create fastlane directory if it doesn't exist
  mkdir -p "$full_path/fastlane"

  # Generate new Fastfile from template
  cat > "$fastfile_path" <<EOF
# Agiliton Unified Fastfile - Auto-generated $(date +%Y-%m-%d)
# Project: $project_path

# Import Agiliton shared infrastructure
import "#{ENV['HOME']}/VisualStudio/AgilitonShared/Scripts/Fastlane/shared_config.rb"
import "#{ENV['HOME']}/VisualStudio/AgilitonShared/Scripts/Fastlane/agiliton_deployment_v2.rb"

# Project Configuration
PROJECT_CONFIG = {
  scheme: "$scheme",
  xcodeproj: "$xcodeproj",
  app_identifier: "$app_id",
  platform: :$platform,
  app_name: "$(basename "$project_path")"
}

default_platform(PROJECT_CONFIG[:platform])

platform PROJECT_CONFIG[:platform] do

  desc "Deploy to TestFlight with all safety checks"
  lane :testflight do |options|
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

  desc "Quick TestFlight upload without incrementing build"
  lane :quick_upload do |options|
    testflight(
      increment_build: false,
      changelog: options[:changelog] || "Quick update"
    )
  end

  desc "Add all tester groups to the latest build"
  lane :add_testers do |options|
    api_key = AgilitonConfig.api_key

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

  desc "Clean up old build artifacts"
  lane :cleanup do
    AgilitonDeployment.cleanup_old_artifacts(project_root: Dir.pwd)
  end

  desc "Check build status and logs"
  lane :check_status do
    AgilitonDeployment.check_altool_logs
    UI.message("Check App Store Connect: https://appstoreconnect.apple.com/")
  end

  desc "Fix common deployment issues"
  lane :fix_deployment do
    UI.header("🔧 Running deployment fixes")

    cleanup

    if UI.confirm("Reset build number to sync with App Store Connect?")
      build_number = UI.input("Enter the current highest build number from App Store Connect:")
      sh("agvtool new-version -all #{build_number.to_i + 1}")
      UI.success("Build number set to #{build_number.to_i + 1}")
    end

    if UI.confirm("Clear derived data?")
      sh("rm -rf DerivedData")
      sh("rm -rf ~/Library/Developer/Xcode/DerivedData/*")
      UI.success("Derived data cleared")
    end

    UI.success("Fixes applied. Try running 'fastlane testflight' again.")
  end

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

error do |lane, exception|
  UI.error("❌ Error in lane #{lane}: #{exception.message}")

  if exception.message.include?("bundle version must be higher")
    UI.important("💡 Solution: Run 'fastlane fix_deployment' to sync build numbers")
  elsif exception.message.include?("Code signing")
    UI.important("💡 Solution: Check your certificates in Xcode")
  elsif exception.message.include?("2FA")
    UI.important("💡 Solution: Make sure API key is configured correctly")
  end

  if lane.to_s.include?("upload") || lane.to_s.include?("testflight")
    AgilitonDeployment.check_altool_logs
  end
end

after_all do |lane|
  if lane != :cleanup && lane != :check_status
    notification(
      title: "#{PROJECT_CONFIG[:app_name]} Deployment",
      message: "Lane #{lane} completed successfully! 🎉"
    ) rescue nil
  end
end
EOF

  echo -e "${GREEN}  ✓ Created new Fastfile${NC}"

  # Clean up old artifacts in the project
  cd "$full_path"

  # Move old pkg files
  if ls *.pkg 2>/dev/null | grep -q .; then
    mkdir -p old_builds
    mv *.pkg old_builds/ 2>/dev/null || true
    echo -e "${GREEN}  ✓ Moved old .pkg files to old_builds/${NC}"
  fi

  # Remove old dSYM files
  rm -f *.dSYM.zip 2>/dev/null || true

  echo -e "${GREEN}  ✓ Migration complete for $project_path${NC}"
  echo ""
}

# Main migration process
echo -e "${BLUE}Starting migration process...${NC}"
echo ""

# Check if shared scripts exist
if [ ! -f "$SHARED_DIR/agiliton_deployment_v2.rb" ]; then
  echo -e "${RED}Error: Shared deployment script not found at:${NC}"
  echo -e "${RED}  $SHARED_DIR/agiliton_deployment_v2.rb${NC}"
  echo -e "${YELLOW}Please ensure AgilitonShared is up to date.${NC}"
  exit 1
fi

# Migrate each project
for project in "${PROJECTS[@]}"; do
  migrate_project "$project"
done

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Migration Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "1. Review the generated Fastfiles in each project"
echo "2. Test with: ${YELLOW}fastlane build_only${NC}"
echo "3. Deploy with: ${YELLOW}fastlane testflight${NC}"
echo ""
echo -e "${BLUE}If you encounter issues:${NC}"
echo "- Run: ${YELLOW}fastlane check_status${NC} to diagnose"
echo "- Run: ${YELLOW}fastlane fix_deployment${NC} for automatic fixes"
echo "- Check the migration guide at:"
echo "  ${YELLOW}$SHARED_DIR/MIGRATION_GUIDE.md${NC}"
echo ""
echo -e "${GREEN}Happy deploying! 🚀${NC}"