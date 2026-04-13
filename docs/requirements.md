# Requirements

[English](requirements.md) | [中文](requirements.zh-CN.md)

This document turns the current product behavior into an explicit requirements
baseline so future changes can be validated against something stable instead of
memory.

## 1. Product Goal

Codex Quota Peek is a macOS-first quota companion for Codex.

It should let users:

- see current `5h` and `7d` quota quickly from the menu bar
- understand resets, remaining quota, and usage pace without reopening Codex
- force a fresh API read when they want the latest official value
- keep using the same quota data from a CLI and integrations

## 2. Supported Surfaces

The product currently has three supported surfaces:

1. macOS menu bar app
2. local CLI: `codexQuotaPeek`
3. first-party integrations under `integrations/`

The menu bar app is the primary experience. CLI and integrations must stay
consistent with the same quota semantics where possible.

## 3. Core User Requirements

### R1. Fast quota visibility

- The menu bar badge must show `H` and `W` remaining quota.
- The dropdown must show `5h` and `7d` quota rows.
- Each row must show:
  - label
  - visual bar
  - reset text
  - remaining percentage

### R2. Freshness and source behavior

- App launch must not leave the badge empty if local data exists.
- Launch must trigger a background API refresh after initial local display.
- Manual `Refresh Now (API)` must prefer the official API.
- Opening the menu should trigger an API refresh when the current display is:
  - sourced from local logs, or
  - sourced from an API snapshot that has gone stale
- Background refresh failure must not replace a valid displayed snapshot with
  `--` or `Source: unavailable`.

### R3. Data source strategy

Supported source strategies:

- `Auto`
- `Prefer API`
- `Prefer local logs`

Rules:

- manual refresh is always API-first
- startup refresh must remain API-first for freshness
- automatic refresh can vary with the selected strategy

### R4. Quota semantics

- `% left` always means actual remaining quota from the current snapshot
- `! / !! / !!!` mean pace risk, not low quota by itself
- pace indicators must never change the underlying remaining percentage

### R5. Weekly workload presets

Weekly pace presets must exist and remain selectable:

- `40h`
- `56h`
- `70h`

The selected preset affects:

- weekly pace severity
- weekly explanation text
- weekly marker calculations
- daily usage chart interpretation

It must not change the actual `7d` remaining percentage.

### R6. Menu structure

The dropdown must preserve a stable structure:

1. title
2. account line
3. `5h` row
4. `7d` row
5. weekly workload selector
6. weekly explanation
7. credits
8. daily usage
9. updated/source line
10. actions

Core actions that must remain visible:

- `Refresh Now (API)`
- `Switch Account...`
- `Usage Dashboard`
- `Status Page`
- `Copy Details`
- `Open Codex Folder`
- `Reveal Logs Database`
- `Preferences...`
- `About Codex Quota Peek`
- `Quit`

### R7. Language behavior

- The app must support English and Chinese
- First launch must follow macOS system language
- Once changed explicitly, the chosen language must persist
- Core menu structure must remain stable in both languages

### R8. Account display

- The dropdown must show the current account in one compact line
- Expected format:
  - English: `Account <value> (<plan>)`
  - Chinese: `账号 <value> (<plan>)`

### R9. Daily usage chart

- The chart must always render a full seven-day week
- It must include:
  - title
  - y-axis
  - x-axis baseline
  - date labels
  - bar glyphs
- The chart may evolve visually, but it must remain structurally testable

### R10. Notifications

Notification categories must be independently configurable:

- low quota
- pace alerts
- reset reminders

Requirements:

- duplicate notifications must be suppressed
- disabling a category must suppress that category only

### R11. CLI behavior

The CLI must support:

- `codexQuotaPeek`
- `codexQuotaPeek status`
- `codexQuotaPeek status --refresh`
- `codexQuotaPeek status --json`
- `codexQuotaPeek accounts list`
- `codexQuotaPeek accounts save`
- `codexQuotaPeek accounts switch ...`

CLI help output must remain stable enough to validate documented flags.

## 4. Non-Functional Requirements

### N1. Stability over novelty

- Automatic refresh must not wipe valid quota state on transient failures.
- Older or stale snapshots must not overwrite newer accepted snapshots.
- UI regressions must be guarded by tests, not only manual inspection.

### N2. Deterministic tests

- Default test runs must not depend on unstable live Codex data.
- Logic and contract tests must stay runnable in a clean local environment.
- Optional live smoke checks should be explicit, not silently required.

### N3. Menu contract protection

Changes to menu structure, language labels, or critical actions must be caught
by tests before shipping.

## 5. Current Acceptance Baseline

The following are considered release-blocking regressions:

- `5h` or `7d` row disappears
- weekly selector disappears
- title/account line disappears
- source/update line disappears unexpectedly
- startup/menu-open API freshness path silently stops working
- automatic refresh failure wipes a valid displayed snapshot
- English and Chinese menu labels drift away from expected contract

## 6. Test Coverage Map

### Logic / policy

- realtime log parsing
- API vs logs freshness selection
- startup/menu-open refresh policy
- stale snapshot rejection
- automatic refresh failure retention
- weekly pace severity
- marker calculations
- notification deduplication

### Presentation / contract

- badge line formatting
- `5h / 7d` labels
- account line formatting
- weekly selector options
- action titles in both languages
- updated/source visibility rules
- daily usage chart shape

### CLI

- help output
- deterministic build smoke
- optional live status smoke only when explicitly requested
