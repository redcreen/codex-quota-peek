#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
RELEASE_DIR="$ROOT_DIR/release"
APP_NAME="CodexQuotaPeek.app"
ZIP_NAME="CodexQuotaPeek-mac.zip"
RELEASE_NOTES_NAME="RELEASE_NOTES.md"

"$ROOT_DIR/scripts/build_app.sh"
"$ROOT_DIR/scripts/generate_release_notes.sh"

mkdir -p "$RELEASE_DIR"
rm -f "$RELEASE_DIR/$ZIP_NAME"

/usr/bin/ditto -c -k --sequesterRsrc --keepParent \
  "$DIST_DIR/$APP_NAME" \
  "$RELEASE_DIR/$ZIP_NAME"

cp "$ROOT_DIR/CHANGELOG.md" "$RELEASE_DIR/CHANGELOG.md"

echo "Packaged release at: $RELEASE_DIR/$ZIP_NAME"
echo "Release notes at: $RELEASE_DIR/$RELEASE_NOTES_NAME"
