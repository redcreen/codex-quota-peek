#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
RELEASE_DIR="$ROOT_DIR/release"
APP_NAME="CodexQuotaPeek.app"
ZIP_NAME="CodexQuotaPeek-mac.zip"

"$ROOT_DIR/scripts/build_app.sh"

mkdir -p "$RELEASE_DIR"
rm -f "$RELEASE_DIR/$ZIP_NAME"

/usr/bin/ditto -c -k --sequesterRsrc --keepParent \
  "$DIST_DIR/$APP_NAME" \
  "$RELEASE_DIR/$ZIP_NAME"

echo "Packaged release at: $RELEASE_DIR/$ZIP_NAME"
