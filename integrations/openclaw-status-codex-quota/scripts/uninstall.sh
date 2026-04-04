#!/usr/bin/env bash
set -euo pipefail

openclaw plugins disable status-codex-quota || true
echo "Disabled: status-codex-quota"
