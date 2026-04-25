#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="$ROOT_DIR/dist/CodexQuotaPeek.app"
TARGET_PATH="/Applications/CodexQuotaPeek.app"
PROCESS_PATH="$TARGET_PATH/Contents/MacOS/CodexQuotaPeek"

"$ROOT_DIR/scripts/build_app.sh"

pkill -x CodexQuotaPeek >/dev/null 2>&1 || true
pkill -9 -f "$PROCESS_PATH" >/dev/null 2>&1 || true

for _ in {1..20}; do
  if ! pgrep -x CodexQuotaPeek >/dev/null 2>&1 && ! pgrep -f "$PROCESS_PATH" >/dev/null 2>&1; then
    break
  fi
  sleep 0.2
done

/usr/bin/ditto "$APP_PATH" "$TARGET_PATH"
echo "Installed app to: $TARGET_PATH"

open "$TARGET_PATH"
echo "Restarted app after install."
