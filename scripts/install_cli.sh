#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TARGET_DIR=""

for candidate in /opt/homebrew/bin "$HOME/.local/bin" "$HOME/bin" /usr/local/bin; do
  if [ -d "$candidate" ] && [ -w "$candidate" ]; then
    TARGET_DIR="$candidate"
    break
  fi
done

if [ -z "$TARGET_DIR" ]; then
  TARGET_DIR="$HOME/.local/bin"
  mkdir -p "$TARGET_DIR"
fi

TARGET_PATH="$TARGET_DIR/codexQuotaPeek"

"$ROOT_DIR/scripts/build_cli.sh"
mkdir -p "$TARGET_DIR"
/usr/bin/install -m 755 "$ROOT_DIR/build/cli/codexQuotaPeek" "$TARGET_PATH"
echo "Installed CLI to: $TARGET_PATH"
