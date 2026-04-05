#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="$ROOT_DIR/dist/CodexQuotaPeek.app"
TARGET_PATH="/Applications/CodexQuotaPeek.app"
PROCESS_PATH="$TARGET_PATH/Contents/MacOS/CodexQuotaPeek"

"$ROOT_DIR/scripts/build_app.sh"

was_running=0
if pgrep -f "$PROCESS_PATH" >/dev/null 2>&1; then
  was_running=1
  pkill -9 -f "$PROCESS_PATH" || true
  sleep 1
fi

/usr/bin/ditto "$APP_PATH" "$TARGET_PATH"
echo "Installed app to: $TARGET_PATH"

if [[ "$was_running" -eq 1 ]]; then
  open "$TARGET_PATH"
  echo "Restarted app after install."
fi
