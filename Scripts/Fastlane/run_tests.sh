#!/bin/bash

# Agiliton Test Suite Runner
# Runs all tests for the deployment system

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
TESTS_DIR="${SCRIPT_DIR}/tests"

echo "================================"
echo "Agiliton Deployment Test Suite"
echo "================================"
echo ""

# Set UTF-8 encoding
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8

# Track overall results
FAILED=0

# Run unit tests
echo "Running Unit Tests..."
echo "--------------------"
if ruby "${TESTS_DIR}/test_deployment.rb"; then
    echo "✅ Unit tests passed"
else
    echo "❌ Unit tests failed"
    FAILED=1
fi

echo ""

# Run integration tests for each project if specified
if [ "$1" == "--integration" ]; then
    echo "Running Integration Tests..."
    echo "---------------------------"

    # Test projects
    PROJECTS=(
        "$HOME/VisualStudio/Assist for Jira/worktrees/main"
        "$HOME/VisualStudio/SmartTranslate/worktrees/main"
        "$HOME/VisualStudio/Amphetamine Enhancer"
    )

    for PROJECT in "${PROJECTS[@]}"; do
        if [ -d "$PROJECT" ]; then
            echo ""
            echo "Testing: $(basename "$PROJECT")"
            if ruby "${TESTS_DIR}/test_integration.rb" "$PROJECT"; then
                echo "✅ Integration tests passed for $(basename "$PROJECT")"
            else
                echo "❌ Integration tests failed for $(basename "$PROJECT")"
                FAILED=1
            fi
        else
            echo "⚠️  Skipping: $PROJECT (not found)"
        fi
    done
fi

echo ""
echo "================================"

if [ $FAILED -eq 0 ]; then
    echo "✅ All tests passed!"
    exit 0
else
    echo "❌ Some tests failed"
    exit 1
fi