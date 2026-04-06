#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RELEASE_DIR="$ROOT_DIR/release"
VERSION="$(tr -d '[:space:]' < "$ROOT_DIR/VERSION")"
RELEASE_TEMPLATE="$ROOT_DIR/release/GITHUB_RELEASE_DRAFT.md"

"$ROOT_DIR/scripts/test.sh"
"$ROOT_DIR/scripts/build_app.sh"
"$ROOT_DIR/scripts/build_cli.sh"
"$ROOT_DIR/scripts/package_release.sh"

cat > "$RELEASE_TEMPLATE" <<EOF
# Codex Quota Peek v$VERSION

## Summary

Paste the generated release notes below into the GitHub Release body.

## Assets

- \`release/CodexQuotaPeek-$VERSION.dmg\`
- \`release/CodexQuotaPeek-$VERSION.zip\`

## Notes

- macOS only
- Minimum supported version: macOS 13.0

## Release Notes

EOF

cat "$RELEASE_DIR/RELEASE_NOTES.md" >> "$RELEASE_TEMPLATE"

echo "Prepared release artifacts in: $RELEASE_DIR"
echo "GitHub release draft at: $RELEASE_TEMPLATE"
