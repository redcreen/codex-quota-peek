# Changelog

[English](CHANGELOG.md) | [中文](CHANGELOG.zh-CN.md)

All notable changes to `Codex Quota Peek` are documented here.

## 0.2.0 - 2026-05-07

- Published the current menu bar app, CLI, and OpenClaw integration as the next public release.
- Added a stable GitHub Release install path via `releases/latest/download/CodexQuotaPeek-latest.dmg`.
- Added local refresh diagnostics logging to `~/.codex/codex-quota-peek.log` for timer/API/display troubleshooting.
- Hardened automatic refresh, manual API refresh, and open-menu refresh handling to reduce stale or missing data.
- Expanded regression coverage around menu contracts, refresh policies, marker math, daily usage rendering, and display state handling.
- Refactored menu construction and update paths into smaller tested components.

## 0.1.0 - 2026-04-06

- First tagged public build for GitHub release distribution.
- Added bilingual README structure organized around quick start, download, and user-facing usage.
- Updated the dropdown header copy to `Codex Quota Usage` / `Codex 用量`.
- Improved quota help interaction so the explanation panel stays open until the next click.

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
