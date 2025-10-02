#!/bin/bash
# Install Agiliton Shared Git Hooks
# Usage: ./install-hooks.sh [project-path]

set -e

# Determine paths
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="${1:-.}"

cd "$PROJECT_DIR"

if [ ! -d ".git" ]; then
  echo "❌ Not a git repository: $PROJECT_DIR"
  exit 1
fi

echo "📦 Installing Agiliton shared git hooks..."

# Create hooks directory if needed
mkdir -p .git/hooks

# Install pre-commit hook
cp "$SCRIPT_DIR/pre-commit" .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit

echo "✅ Git hooks installed successfully!"
echo ""
echo "Installed hooks:"
echo "  • pre-commit - Runs tests before each commit"
echo ""
echo "To skip hooks: git commit --no-verify"
