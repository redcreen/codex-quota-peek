# Codex Limit Bar

A tiny macOS menu bar app that reads the latest Codex rate limit event from `~/.codex` and shows the remaining primary and weekly quota as a two-line badge.

## Build

```bash
./scripts/build_app.sh
```

## Run

```bash
open "dist/CodexLimitBar.app"
```

## Display

- Top line: `P xx%` for the remaining primary window quota.
- Bottom line: `W xx%` for the remaining weekly quota.
- Refresh interval: 60 seconds.

## Data sources

1. `~/.codex/logs_1.sqlite` realtime `codex.rate_limits` events
2. `~/.codex/archived_sessions/*.jsonl` fallback `token_count` events
