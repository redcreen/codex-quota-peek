#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build/cli"
EXECUTABLE="$BUILD_DIR/codexQuotaPeek"

mkdir -p "$BUILD_DIR"

/usr/bin/swiftc \
  -O \
  "$ROOT_DIR/Sources/CliFormatter.swift" \
  "$ROOT_DIR/Sources/AppLanguage.swift" \
  "$ROOT_DIR/Sources/cli_main.swift" \
  "$ROOT_DIR/Sources/CodexAuthSnapshotStore.swift" \
  "$ROOT_DIR/Sources/CodexQuotaSnapshot.swift" \
  "$ROOT_DIR/Sources/CodexQuotaProvider.swift" \
  "$ROOT_DIR/Sources/QuotaDisplayPolicy.swift" \
  "$ROOT_DIR/Sources/QuotaRefreshPolicy.swift" \
  "$ROOT_DIR/Sources/RefreshRequestGate.swift" \
  -o "$EXECUTABLE"

echo "Built CLI at: $EXECUTABLE"
