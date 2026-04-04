#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

openclaw plugins install -l "$ROOT_DIR"
openclaw plugins enable status-codex-quota

echo "Installed and enabled: status-codex-quota"
