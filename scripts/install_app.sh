#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="$ROOT_DIR/dist/CodexQuotaPeek.app"
TARGET_PATH="/Applications/CodexQuotaPeek.app"

"$ROOT_DIR/scripts/build_app.sh"

/usr/bin/ditto "$APP_PATH" "$TARGET_PATH"
echo "Installed app to: $TARGET_PATH"
