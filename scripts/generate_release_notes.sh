#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CHANGELOG_FILE="$ROOT_DIR/CHANGELOG.md"
VERSION_FILE="$ROOT_DIR/VERSION"
OUTPUT_DIR="$ROOT_DIR/release"
OUTPUT_FILE="$OUTPUT_DIR/RELEASE_NOTES.md"

VERSION="$(tr -d '[:space:]' < "$VERSION_FILE")"

mkdir -p "$OUTPUT_DIR"

awk -v version="$VERSION" '
  $0 ~ "^## "version" " { printing=1 }
  printing && $0 ~ "^## " && $0 !~ "^## "version" " { exit }
  printing { print }
' "$CHANGELOG_FILE" > "$OUTPUT_FILE"

if [[ ! -s "$OUTPUT_FILE" ]]; then
  echo "Could not extract release notes for version $VERSION from $CHANGELOG_FILE" >&2
  exit 1
fi

echo "Generated release notes at: $OUTPUT_FILE"
