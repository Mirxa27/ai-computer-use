#!/bin/bash

# Voice Agent Build Script
# This script builds the Voice Agent macOS application

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
APP_NAME="VoiceAgent"
BUILD_DIR=".build"
RELEASE_DIR="release"

echo -e "${GREEN}🚀 Building Voice Agent...${NC}"

# Check for Swift
if ! command -v swift &> /dev/null; then
    echo -e "${RED}❌ Swift is not installed. Please install Xcode or Swift toolchain.${NC}"
    exit 1
fi

# Clean previous builds
echo -e "${YELLOW}🧹 Cleaning previous builds...${NC}"
rm -rf $BUILD_DIR
rm -rf $RELEASE_DIR

# Build the application
echo -e "${YELLOW}🔨 Building application...${NC}"
swift build -c release --arch arm64 --arch x86_64

# Create release directory
mkdir -p $RELEASE_DIR

# Copy executable
echo -e "${YELLOW}📦 Packaging application...${NC}"
cp $BUILD_DIR/release/$APP_NAME $RELEASE_DIR/

# Create app bundle structure
APP_BUNDLE="$RELEASE_DIR/$APP_NAME.app"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy executable to bundle
cp $BUILD_DIR/release/$APP_NAME "$APP_BUNDLE/Contents/MacOS/"

# Copy Info.plist
cp Info.plist "$APP_BUNDLE/Contents/"

# Create basic icon (you can replace with actual icon)
echo -e "${YELLOW}🎨 Creating app icon...${NC}"
cat > "$APP_BUNDLE/Contents/Resources/AppIcon.icns" << 'EOF'
# Placeholder for actual icon file
EOF

# Make executable
chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# Sign the application (requires Developer ID)
if security find-identity -p codesigning &> /dev/null; then
    echo -e "${YELLOW}✍️  Signing application...${NC}"
    codesign --force --deep --sign - "$APP_BUNDLE"
else
    echo -e "${YELLOW}⚠️  No code signing identity found. App will not be signed.${NC}"
fi

# Create DMG for distribution (optional)
if command -v create-dmg &> /dev/null; then
    echo -e "${YELLOW}💿 Creating DMG...${NC}"
    create-dmg \
        --volname "$APP_NAME" \
        --window-pos 200 120 \
        --window-size 600 400 \
        --icon-size 100 \
        --icon "$APP_NAME.app" 175 190 \
        --hide-extension "$APP_NAME.app" \
        --app-drop-link 425 190 \
        "$RELEASE_DIR/$APP_NAME.dmg" \
        "$APP_BUNDLE"
fi

echo -e "${GREEN}✅ Build complete!${NC}"
echo -e "${GREEN}📍 Application bundle: $APP_BUNDLE${NC}"

# Run the application (optional)
read -p "Do you want to run the application now? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}🚀 Launching Voice Agent...${NC}"
    open "$APP_BUNDLE"
fi