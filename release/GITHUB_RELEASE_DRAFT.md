# Codex Quota Peek v1.1.0

## Summary

Paste the generated release notes below into the GitHub Release body.

## Assets

- `release/CodexQuotaPeek-mac.zip`

## Notes

- macOS only
- Minimum supported version: macOS 13.0

## Release Notes

## 1.1.0 - 2026-04-04

- Added an in-app `English / 中文` language switch with English as the default.
- Added deduplicated macOS notifications for low quota, pace warnings, and upcoming reset windows.
- Added separate notification category toggles for low quota, pace, and reset reminders.
- Added recent trend sparklines and low-water marks, including when the recent low occurred.
- Added a standalone `Preferences...` window with display, source strategy, workload pacing, notifications, and app behavior settings.
- Added configurable source strategy options: `Auto`, `Prefer API`, and `Prefer local logs`.
- Added account snapshot saving and local account switching support.
- Added a CLI with `status`, `--refresh`, JSON output, and account snapshot commands.
- Added regression tests for parsing, refresh policies, language switching, trend formatting, and notification behavior.

