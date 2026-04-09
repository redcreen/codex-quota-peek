#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
APP_DIR="$ROOT_DIR/dist/CodexQuotaPeek.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
EXECUTABLE="$MACOS_DIR/CodexQuotaPeek"
ICON_PNG="$BUILD_DIR/AppIcon.png"
ICONSET_DIR="$BUILD_DIR/AppIcon.iconset"
ICON_ICNS="$RESOURCES_DIR/AppIcon.icns"
APP_VERSION="$(tr -d '[:space:]' < "$ROOT_DIR/VERSION")"
BUILD_NUMBER="$(git -C "$ROOT_DIR" rev-list --count HEAD 2>/dev/null || echo 1)"

mkdir -p "$BUILD_DIR" "$MACOS_DIR" "$RESOURCES_DIR"

/usr/bin/swift "$ROOT_DIR/scripts/generate_icon.swift" "$ICON_PNG"

rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"
/usr/bin/sips -z 16 16 "$ICON_PNG" --out "$ICONSET_DIR/icon_16x16.png" >/dev/null
/usr/bin/sips -z 32 32 "$ICON_PNG" --out "$ICONSET_DIR/icon_16x16@2x.png" >/dev/null
/usr/bin/sips -z 32 32 "$ICON_PNG" --out "$ICONSET_DIR/icon_32x32.png" >/dev/null
/usr/bin/sips -z 64 64 "$ICON_PNG" --out "$ICONSET_DIR/icon_32x32@2x.png" >/dev/null
/usr/bin/sips -z 128 128 "$ICON_PNG" --out "$ICONSET_DIR/icon_128x128.png" >/dev/null
/usr/bin/sips -z 256 256 "$ICON_PNG" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null
/usr/bin/sips -z 256 256 "$ICON_PNG" --out "$ICONSET_DIR/icon_256x256.png" >/dev/null
/usr/bin/sips -z 512 512 "$ICON_PNG" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null
/usr/bin/sips -z 512 512 "$ICON_PNG" --out "$ICONSET_DIR/icon_512x512.png" >/dev/null
cp "$ICON_PNG" "$ICONSET_DIR/icon_512x512@2x.png"
/usr/bin/iconutil -c icns "$ICONSET_DIR" -o "$ICON_ICNS"

/usr/bin/swiftc \
  -O \
  -framework AppKit \
  "$ROOT_DIR/Sources/main.swift" \
  "$ROOT_DIR/Sources/AppDelegate.swift" \
  "$ROOT_DIR/Sources/AccountMenuBuilder.swift" \
  "$ROOT_DIR/Sources/AppLanguage.swift" \
  "$ROOT_DIR/Sources/CodexAuthSnapshotStore.swift" \
  "$ROOT_DIR/Sources/MenuTag.swift" \
  "$ROOT_DIR/Sources/MenuFactory.swift" \
  "$ROOT_DIR/Sources/CodexQuotaSnapshot.swift" \
  "$ROOT_DIR/Sources/CodexQuotaProvider.swift" \
  "$ROOT_DIR/Sources/DailyUsageLedger.swift" \
  "$ROOT_DIR/Sources/DailyUsageChartRenderer.swift" \
  "$ROOT_DIR/Sources/DailyUsageChartStylePolicy.swift" \
  "$ROOT_DIR/Sources/QuotaExplanationBuilder.swift" \
  "$ROOT_DIR/Sources/QuotaRowLayout.swift" \
  "$ROOT_DIR/Sources/QuotaRowTextRenderer.swift" \
  "$ROOT_DIR/Sources/PreferencesWindowController.swift" \
  "$ROOT_DIR/Sources/QuotaDisplayPolicy.swift" \
  "$ROOT_DIR/Sources/QuotaNotificationPolicy.swift" \
  "$ROOT_DIR/Sources/QuotaRefreshPolicy.swift" \
  "$ROOT_DIR/Sources/RefreshRequestGate.swift" \
  "$ROOT_DIR/Sources/WeeklyPaceMath.swift" \
  "$ROOT_DIR/Sources/StatusBadgeView.swift" \
  -o "$EXECUTABLE"

cat > "$CONTENTS_DIR/Info.plist" <<PLIST
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
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleName</key>
  <string>CodexQuotaPeek</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>${APP_VERSION}</string>
  <key>CFBundleVersion</key>
  <string>${BUILD_NUMBER}</string>
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
