#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build/tests"
EXECUTABLE="$BUILD_DIR/CodexQuotaPeekTests"

mkdir -p "$BUILD_DIR"

/usr/bin/swiftc \
  "$ROOT_DIR/Sources/CodexAuthSnapshotStore.swift" \
  "$ROOT_DIR/Sources/CodexQuotaSnapshot.swift" \
  "$ROOT_DIR/Sources/CodexQuotaProvider.swift" \
  "$ROOT_DIR/Sources/QuotaDisplayPolicy.swift" \
  "$ROOT_DIR/Sources/QuotaRefreshPolicy.swift" \
  "$ROOT_DIR/Tests/TestRunner.swift" \
  -o "$EXECUTABLE"

"$EXECUTABLE"
