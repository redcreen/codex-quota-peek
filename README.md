# Codex Quota Peek

A tiny macOS menu bar app that reads the latest Codex rate limit event from `~/.codex` and shows the remaining primary and weekly quota in the menu bar and a richer dropdown menu.

## Download

Download the packaged app from `release/CodexQuotaPeek-mac.zip`, unzip it, and open `CodexQuotaPeek.app`.

## Build

```bash
./scripts/build_app.sh
./scripts/package_release.sh
```

## Run

```bash
open "dist/CodexQuotaPeek.app"
```

## Display

- Menu bar badge: `P xx%` and `W xx%`
- Dropdown menu: primary window, weekly window, remaining percentage, and reset time
- Refresh interval: 60 seconds.

## Data sources

1. `~/.codex/logs_1.sqlite` realtime `codex.rate_limits` events
2. `~/.codex/archived_sessions/*.jsonl` fallback `token_count` events
