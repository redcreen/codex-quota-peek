# Codex Quota Peek v0.2.0

## Summary

Paste the generated release notes below into the GitHub Release body.

## Assets

- `release/CodexQuotaPeek-0.2.0.dmg`
- `release/CodexQuotaPeek-0.2.0.zip`
- `release/CodexQuotaPeek-latest.dmg`
- `release/CodexQuotaPeek-latest.zip`

## Notes

- macOS only
- Minimum supported version: macOS 13.0

## Release Notes

## 0.2.0 - 2026-05-07

- Published the current menu bar app, CLI, and OpenClaw integration as the next public release.
- Added a stable GitHub Release install path via `releases/latest/download/CodexQuotaPeek-latest.dmg`.
- Added local refresh diagnostics logging to `~/.codex/codex-quota-peek.log` for timer/API/display troubleshooting.
- Hardened automatic refresh, manual API refresh, and open-menu refresh handling to reduce stale or missing data.
- Expanded regression coverage around menu contracts, refresh policies, marker math, daily usage rendering, and display state handling.
- Refactored menu construction and update paths into smaller tested components.

