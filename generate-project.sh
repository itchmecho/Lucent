#!/bin/bash

# PhotoKeepSafe - Project Generation Script
# This script helps you create the Xcode project

set -e

echo "PhotoKeepSafe - Project Setup"
echo "=============================="
echo ""

# Check if xcodegen is installed
if command -v xcodegen &> /dev/null; then
    echo "✓ xcodegen is installed"
    echo ""
    echo "Generating Xcode project from project.yml..."
    xcodegen generate
    echo ""
    echo "✓ Project generated successfully!"
    echo ""
    echo "You can now:"
    echo "  1. Open PhotoKeepSafe.xcodeproj in Xcode"
    echo "  2. Select a scheme (iOS or macOS)"
    echo "  3. Build and run (Cmd+R)"
    echo ""
else
    echo "✗ xcodegen is not installed"
    echo ""
    echo "You have two options:"
    echo ""
    echo "Option 1: Install xcodegen (Recommended)"
    echo "-----------------------------------------"
    echo "Run: brew install xcodegen"
    echo "Then run this script again"
    echo ""
    echo "Option 2: Create project manually in Xcode"
    echo "-------------------------------------------"
    echo "Follow the instructions in SETUP-INSTRUCTIONS.md"
    echo ""
    echo "To view instructions: cat SETUP-INSTRUCTIONS.md"
    echo ""
fi
