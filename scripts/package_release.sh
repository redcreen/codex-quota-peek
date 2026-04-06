#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
RELEASE_DIR="$ROOT_DIR/release"
VERSION="$(tr -d '[:space:]' < "$ROOT_DIR/VERSION")"
APP_NAME="CodexQuotaPeek.app"
DMG_NAME="CodexQuotaPeek-$VERSION.dmg"
ZIP_NAME="CodexQuotaPeek-$VERSION.zip"
RELEASE_NOTES_NAME="RELEASE_NOTES.md"
DMG_STAGING_DIR="$RELEASE_DIR/.dmg-root"

"$ROOT_DIR/scripts/build_app.sh"
"$ROOT_DIR/scripts/generate_release_notes.sh"

mkdir -p "$RELEASE_DIR"
rm -rf "$DMG_STAGING_DIR"
mkdir -p "$DMG_STAGING_DIR"
rm -f "$RELEASE_DIR/$ZIP_NAME"
rm -f "$RELEASE_DIR/$DMG_NAME"

cp -R "$DIST_DIR/$APP_NAME" "$DMG_STAGING_DIR/$APP_NAME"
ln -s /Applications "$DMG_STAGING_DIR/Applications"

/usr/bin/ditto -c -k --sequesterRsrc --keepParent \
  "$DIST_DIR/$APP_NAME" \
  "$RELEASE_DIR/$ZIP_NAME"

/usr/bin/hdiutil create \
  -volname "CodexQuotaPeek $VERSION" \
  -srcfolder "$DMG_STAGING_DIR" \
  -format UDZO \
  "$RELEASE_DIR/$DMG_NAME" >/dev/null

rm -rf "$DMG_STAGING_DIR"

cp "$ROOT_DIR/CHANGELOG.md" "$RELEASE_DIR/CHANGELOG.md"

echo "Packaged release at: $RELEASE_DIR/$DMG_NAME"
echo "Packaged release at: $RELEASE_DIR/$ZIP_NAME"
echo "Release notes at: $RELEASE_DIR/$RELEASE_NOTES_NAME"
