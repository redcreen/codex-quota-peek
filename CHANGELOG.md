# Changelog

All notable changes to `Codex Quota Peek` are documented here.

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

## 1.0.0 - 2026-04-04

- Initial public release of the macOS menu bar app.
- Added local Codex quota parsing from `~/.codex/logs_1.sqlite`.
- Added menu bar badge, dropdown details, manual refresh, and release packaging.
