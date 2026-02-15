#!/bin/bash
set -e

APP_NAME="NotchHUD"
BUILD_DIR=".build/release"
DEST_DIR="$HOME/Desktop"
APP_BUNDLE="$DEST_DIR/${APP_NAME}.app"

echo "Building ${APP_NAME} (Release)..."
swift build -c release

# Ensure the executable exists
if [ ! -f "$BUILD_DIR/$APP_NAME" ]; then
    echo "Error: Build failed or executable not found at $BUILD_DIR/$APP_NAME"
    exit 1
fi

echo "Deploying to Desktop..."
# Clean up previous build on Desktop
rm -rf "$APP_BUNDLE"

# Create directory structure
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy executable
cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# Create Info.plist
cat > "$APP_BUNDLE/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>com.createhud.${APP_NAME}</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.1</string>
    <key>CFBundleVersion</key>
    <string>2</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSAppleEventsUsageDescription</key>
    <string>NotchHUD needs to control Spotify and Apple Music to show playing info.</string>
</dict>
</plist>
EOF

chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# Ad-hoc sign the app (required for ARM64 and permissions)
codesign --force --deep --sign - "$APP_BUNDLE"

echo "Success! App deployed to $APP_BUNDLE"
open "$APP_BUNDLE"
