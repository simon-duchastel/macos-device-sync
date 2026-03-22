#!/bin/bash

set -e

echo "Building MacOsDeviceSync..."

APP_NAME="MacOsDeviceSync"
BUILD_DIR="build"
CONTENTS_DIR="$BUILD_DIR/$APP_NAME.app/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

rm -rf "$BUILD_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

echo "Compiling..."
swiftc \
    -o "$MACOS_DIR/$APP_NAME" \
    -sdk $(xcrun --sdk macosx --show-sdk-path) \
    -target arm64-apple-macos12 \
    -framework Foundation \
    -framework Cocoa \
    -framework CoreBluetooth \
    -framework IOBluetooth \
    -framework UserNotifications \
    *.swift

cp "Info.plist" "$CONTENTS_DIR/Info.plist"

# Apply entitlements (required for IOBluetooth to work)
if [ -f "MacOsDeviceSync.entitlements" ]; then
    echo "Applying entitlements..."
    codesign --force --deep --entitlements MacOsDeviceSync.entitlements --sign - "$BUILD_DIR/$APP_NAME.app"
fi

chmod +x "$MACOS_DIR/$APP_NAME"

echo "Built: $BUILD_DIR/$APP_NAME.app"
