#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

APP_NAME="NotchHUD"
BUNDLE_ID="com.ashwaryeyadav.notchhud"

echo "Building (release)…"
swift build -c release

BIN_PATH=".build/release/${APP_NAME}"
if [[ ! -f "$BIN_PATH" ]]; then
  echo "Error: built binary not found at $BIN_PATH" >&2
  exit 1
fi

OUT_DIR="dist"
APP_DIR="${OUT_DIR}/${APP_NAME}.app"

echo "Creating app bundle at ${APP_DIR}"
rm -rf "$APP_DIR"
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"

cp "$BIN_PATH" "${APP_DIR}/Contents/MacOS/${APP_NAME}"

cat > "${APP_DIR}/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>
  <string>${APP_NAME}</string>
  <key>CFBundleDisplayName</key>
  <string>${APP_NAME}</string>
  <key>CFBundleIdentifier</key>
  <string>${BUNDLE_ID}</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleExecutable</key>
  <string>${APP_NAME}</string>

  <!-- Menu-bar only (no Dock icon) -->
  <key>LSUIElement</key>
  <true/>

  <!-- Shown in the Automation consent prompt -->
  <key>NSAppleEventsUsageDescription</key>
  <string>NotchHUD needs permission to control apps like Safari, Spotify, and Music to fetch now playing info and integrate with your workflow.</string>
</dict>
</plist>
EOF

echo "Ad-hoc codesigning…"
codesign --force --deep --sign - "${APP_DIR}"

echo "Done."
echo "Run it with: open \"${APP_DIR}\""

