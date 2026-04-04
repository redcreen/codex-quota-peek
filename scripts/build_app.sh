#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
APP_DIR="$ROOT_DIR/dist/CodexQuotaPeek.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
EXECUTABLE="$MACOS_DIR/CodexQuotaPeek"

mkdir -p "$BUILD_DIR" "$MACOS_DIR" "$RESOURCES_DIR"

/usr/bin/swiftc \
  -O \
  -framework AppKit \
  "$ROOT_DIR/Sources/main.swift" \
  "$ROOT_DIR/Sources/AppDelegate.swift" \
  "$ROOT_DIR/Sources/CodexQuotaSnapshot.swift" \
  "$ROOT_DIR/Sources/CodexQuotaProvider.swift" \
  "$ROOT_DIR/Sources/StatusBadgeView.swift" \
  -o "$EXECUTABLE"

cat > "$CONTENTS_DIR/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>CodexQuotaPeek</string>
  <key>CFBundleIdentifier</key>
  <string>local.codexquotapeek</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>CodexQuotaPeek</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

echo "Built app at: $APP_DIR"
