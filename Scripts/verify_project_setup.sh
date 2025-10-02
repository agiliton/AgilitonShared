#!/bin/bash
# Agiliton Project Setup Verification Script
# Version: 1.0.0
#
# This script verifies that an Xcode project is properly configured
# for Agiliton shared infrastructure, especially TestFlight deployment.
#
# Usage: ./verify_project_setup.sh path/to/Project.xcodeproj

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Emoji for better visibility
CHECK="✅"
CROSS="❌"
WARNING="⚠️"
INFO="ℹ️"
ROCKET="🚀"

# Script configuration
XCODEPROJ=$1
SCRIPT_VERSION="1.0.0"

# ==============================================================================
# Helper Functions
# ==============================================================================

print_header() {
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

print_success() {
    echo -e "${GREEN}${CHECK}${NC} $1"
}

print_error() {
    echo -e "${RED}${CROSS}${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}${WARNING}${NC} $1"
}

print_info() {
    echo -e "${BLUE}${INFO}${NC} $1"
}

print_fix() {
    echo -e "${YELLOW}   Fix: $1${NC}"
}

# ==============================================================================
# Validation Functions
# ==============================================================================

check_usage() {
    if [ -z "$XCODEPROJ" ]; then
        echo -e "${RED}Error: Missing Xcode project path${NC}\n"
        echo "Usage: $0 path/to/Project.xcodeproj"
        echo ""
        echo "Example:"
        echo "  $0 ~/VisualStudio/MyApp/MyApp.xcodeproj"
        echo ""
        exit 1
    fi
}

check_project_exists() {
    if [ ! -d "$XCODEPROJ" ]; then
        print_error "Xcode project not found: $XCODEPROJ"
        exit 1
    fi
    print_success "Found Xcode project: $(basename "$XCODEPROJ")"
}

check_pbxproj_exists() {
    PBXPROJ="$XCODEPROJ/project.pbxproj"
    if [ ! -f "$PBXPROJ" ]; then
        print_error "project.pbxproj not found in $XCODEPROJ"
        exit 1
    fi
}

check_apple_generic_versioning() {
    print_info "Checking Apple Generic Versioning..."

    if grep -q 'VERSIONING_SYSTEM = "apple-generic"' "$PBXPROJ"; then
        print_success "Apple Generic Versioning is enabled"
        return 0
    else
        print_error "Apple Generic Versioning is NOT enabled"
        print_fix "Add to both Debug and Release build settings:"
        print_fix 'VERSIONING_SYSTEM = "apple-generic";'
        print_fix ""
        print_fix "Reference: https://developer.apple.com/library/content/qa/qa1827/"
        return 1
    fi
}

check_current_project_version() {
    print_info "Checking CURRENT_PROJECT_VERSION..."

    if grep -q 'CURRENT_PROJECT_VERSION' "$PBXPROJ"; then
        # Extract the version
        VERSION=$(grep -m 1 'CURRENT_PROJECT_VERSION' "$PBXPROJ" | sed 's/.*= \(.*\);/\1/')
        print_success "CURRENT_PROJECT_VERSION is set: $VERSION"
        return 0
    else
        print_warning "CURRENT_PROJECT_VERSION not found"
        print_fix "Add to build settings (usually set to 1):"
        print_fix 'CURRENT_PROJECT_VERSION = 1;'
        return 1
    fi
}

check_marketing_version() {
    print_info "Checking MARKETING_VERSION..."

    if grep -q 'MARKETING_VERSION' "$PBXPROJ"; then
        VERSION=$(grep -m 1 'MARKETING_VERSION' "$PBXPROJ" | sed 's/.*= \(.*\);/\1/')
        print_success "MARKETING_VERSION is set: $VERSION"
        return 0
    else
        print_warning "MARKETING_VERSION not found"
        print_fix "Add to build settings:"
        print_fix 'MARKETING_VERSION = 1.0;'
        return 1
    fi
}

check_development_team() {
    print_info "Checking DEVELOPMENT_TEAM..."

    if grep -q 'DEVELOPMENT_TEAM' "$PBXPROJ"; then
        TEAM=$(grep -m 1 'DEVELOPMENT_TEAM' "$PBXPROJ" | sed 's/.*= \(.*\);/\1/')
        print_success "DEVELOPMENT_TEAM is set: $TEAM"

        # Check if it's Agiliton's team
        if [[ "$TEAM" == "4S7KX75F3B" ]]; then
            print_success "Using Agiliton team ID"
        else
            print_warning "Using non-Agiliton team ID: $TEAM"
        fi
        return 0
    else
        print_error "DEVELOPMENT_TEAM not set"
        print_fix "Add to build settings:"
        print_fix 'DEVELOPMENT_TEAM = 4S7KX75F3B;  // Agiliton Ltd.'
        return 1
    fi
}

check_fastlane_setup() {
    print_info "Checking Fastlane configuration..."

    PROJECT_DIR=$(dirname "$XCODEPROJ")
    FASTFILE="$PROJECT_DIR/fastlane/Fastfile"

    if [ -f "$FASTFILE" ]; then
        print_success "Fastfile found"

        # Check if using shared lanes
        if grep -q 'AgilitonLanes' "$FASTFILE"; then
            print_success "Using AgilitonShared lanes"

            # Check for deprecated testflight_ios
            if grep -q 'AgilitonLanes.testflight_ios' "$FASTFILE"; then
                print_warning "Using deprecated testflight_ios method"
                print_fix "Update to: AgilitonLanes.deploy_testflight_ios"
            elif grep -q 'AgilitonLanes.deploy_testflight_ios' "$FASTFILE"; then
                print_success "Using current deploy_testflight_ios method"
            fi
        else
            print_warning "Not using AgilitonShared lanes"
            print_fix "Consider importing shared lanes for consistency"
        fi
        return 0
    else
        print_warning "No Fastfile found"
        print_fix "Run 'fastlane init' to set up Fastlane"
        return 1
    fi
}

check_info_plist() {
    print_info "Checking Info.plist configuration..."

    PROJECT_DIR=$(dirname "$XCODEPROJ")

    # Try to find Info.plist
    INFO_PLIST=$(find "$PROJECT_DIR" -name "Info.plist" -type f | head -1)

    if [ -z "$INFO_PLIST" ]; then
        print_warning "Info.plist not found (might be using target property list)"
        return 1
    fi

    print_success "Found Info.plist: $(basename $(dirname "$INFO_PLIST"))/$(basename "$INFO_PLIST")"

    # Check for version placeholders
    if grep -q 'CFBundleShortVersionString' "$INFO_PLIST"; then
        print_success "CFBundleShortVersionString configured"
    fi

    if grep -q 'CFBundleVersion' "$INFO_PLIST"; then
        print_success "CFBundleVersion configured"
    fi

    return 0
}

generate_summary() {
    echo ""
    print_header "📋 Summary"

    local all_passed=true

    if [ $VERSIONING_OK -ne 0 ]; then
        all_passed=false
        print_error "Apple Generic Versioning: Not enabled (CRITICAL)"
    else
        print_success "Apple Generic Versioning: Enabled"
    fi

    if [ $PROJECT_VERSION_OK -ne 0 ]; then
        all_passed=false
        print_warning "CURRENT_PROJECT_VERSION: Not set"
    else
        print_success "CURRENT_PROJECT_VERSION: Set"
    fi

    if [ $TEAM_OK -ne 0 ]; then
        all_passed=false
        print_error "DEVELOPMENT_TEAM: Not set (CRITICAL)"
    else
        print_success "DEVELOPMENT_TEAM: Set"
    fi

    echo ""

    if [ "$all_passed" = true ]; then
        echo -e "${GREEN}${ROCKET} Project is ready for TestFlight deployment!${NC}"
        echo ""
        echo "Next steps:"
        echo "  1. cd $(dirname "$XCODEPROJ")"
        echo "  2. fastlane testflight"
        echo ""
        exit 0
    else
        echo -e "${RED}${CROSS} Project needs configuration before TestFlight deployment${NC}"
        echo ""
        echo "Please fix the issues above and run this script again."
        echo ""
        exit 1
    fi
}

# ==============================================================================
# Main Execution
# ==============================================================================

main() {
    print_header "🔧 Agiliton Project Setup Verification v${SCRIPT_VERSION}"

    # Basic checks
    check_usage
    check_project_exists
    check_pbxproj_exists

    echo ""
    print_header "🔍 Configuration Checks"

    # Critical checks
    check_apple_generic_versioning
    VERSIONING_OK=$?

    check_current_project_version
    PROJECT_VERSION_OK=$?

    check_development_team
    TEAM_OK=$?

    # Optional checks
    check_marketing_version
    check_fastlane_setup
    check_info_plist

    # Generate summary
    generate_summary
}

# Run main function
main
