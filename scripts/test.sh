#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build/tests"
EXECUTABLE="$BUILD_DIR/CodexQuotaPeekTests"

mkdir -p "$BUILD_DIR"

/usr/bin/swiftc \
  "$ROOT_DIR/Sources/CliFormatter.swift" \
  "$ROOT_DIR/Sources/AppLanguage.swift" \
  "$ROOT_DIR/Sources/CodexAuthSnapshotStore.swift" \
  "$ROOT_DIR/Sources/CodexQuotaSnapshot.swift" \
  "$ROOT_DIR/Sources/CodexQuotaProvider.swift" \
  "$ROOT_DIR/Sources/QuotaDisplayPolicy.swift" \
  "$ROOT_DIR/Sources/QuotaNotificationPolicy.swift" \
  "$ROOT_DIR/Sources/QuotaRefreshPolicy.swift" \
  "$ROOT_DIR/Sources/RefreshRequestGate.swift" \
  "$ROOT_DIR/Tests/TestRunner.swift" \
  -o "$EXECUTABLE"

"$EXECUTABLE"

CLI_EXECUTABLE="$ROOT_DIR/build/cli/codexQuotaPeek"
"$ROOT_DIR/scripts/build_cli.sh" >/dev/null
"$CLI_EXECUTABLE" help >/dev/null
"$CLI_EXECUTABLE" status --json >/dev/null
