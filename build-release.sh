#!/bin/bash

# Build script for creating a distributable macOS app
# This script builds a Release version and creates a DMG file

set -e  # Exit on error

PROJECT_NAME="CYOLLMA"
SCHEME="CYOLLMA"
CONFIGURATION="Release"
BUILD_DIR="./build"
DIST_DIR="./dist"
DMG_NAME="${PROJECT_NAME}.dmg"

echo "🚀 Building ${PROJECT_NAME} for distribution..."

# Clean previous builds
echo "🧹 Cleaning previous builds..."
rm -rf "${BUILD_DIR}"
rm -rf "${DIST_DIR}"
mkdir -p "${DIST_DIR}"

# Build the app
echo "📦 Building ${SCHEME} (${CONFIGURATION})..."
xcodebuild -project "${PROJECT_NAME}.xcodeproj" \
           -scheme "${SCHEME}" \
           -configuration "${CONFIGURATION}" \
           -derivedDataPath "${BUILD_DIR}" \
           CODE_SIGN_IDENTITY="" \
           CODE_SIGNING_REQUIRED=NO \
           CODE_SIGNING_ALLOWED=NO \
           clean build

# Find the built app
APP_PATH=$(find "${BUILD_DIR}" -name "${PROJECT_NAME}.app" -type d | head -n 1)

if [ -z "$APP_PATH" ]; then
    echo "❌ Error: Could not find built app"
    exit 1
fi

echo "✅ Build successful! App found at: ${APP_PATH}"

# Copy app to dist folder
echo "📋 Copying app to distribution folder..."
cp -R "${APP_PATH}" "${DIST_DIR}/"

# Create DMG
echo "💿 Creating DMG file..."

# Create a temporary directory for DMG contents
DMG_TEMP_DIR="${DIST_DIR}/dmg_temp"
mkdir -p "${DMG_TEMP_DIR}"

# Copy app to temp directory
cp -R "${DIST_DIR}/${PROJECT_NAME}.app" "${DMG_TEMP_DIR}/"

# Optionally copy README
if [ -f "README.md" ]; then
    cp "README.md" "${DMG_TEMP_DIR}/"
fi

# Create DMG
hdiutil create -volname "${PROJECT_NAME}" \
               -srcfolder "${DMG_TEMP_DIR}" \
               -ov \
               -format UDZO \
               "${DIST_DIR}/${DMG_NAME}"

# Clean up temp directory
rm -rf "${DMG_TEMP_DIR}"

echo ""
echo "✨ Distribution package created successfully!"
echo ""
echo "📁 Files created:"
echo "   - ${DIST_DIR}/${PROJECT_NAME}.app"
echo "   - ${DIST_DIR}/${DMG_NAME}"
echo ""
echo "🎉 You can now distribute ${DIST_DIR}/${DMG_NAME} to users!"
echo ""
echo "Note: Users may need to right-click and 'Open' the app the first time"
echo "      due to macOS security restrictions for unsigned apps."

