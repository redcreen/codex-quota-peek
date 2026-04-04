# Architecture

This document explains how Codex Quota Peek is implemented today and why the
main design decisions were made.

## Product shape

Codex Quota Peek currently has three product surfaces:

- a macOS menu bar app
- a local CLI: `codexQuotaPeek`
- first-party integrations, currently including the OpenClaw status plugin

The shared product goal is simple:

- show Codex quota quickly
- stay useful even when the official UI is not open
- prefer local and lightweight reads during normal operation
- still allow explicit API refresh when the user asks for the latest value

## High-level architecture

The codebase is still small enough to stay in one target, but the internal
responsibilities are already separated by role.

### App shell

- [main.swift](/Users/redcreen/Project/codex%20limit/Sources/main.swift)
- [AppDelegate.swift](/Users/redcreen/Project/codex%20limit/Sources/AppDelegate.swift)
- [PreferencesWindowController.swift](/Users/redcreen/Project/codex%20limit/Sources/PreferencesWindowController.swift)

Responsibilities:

- create the menu bar app lifecycle
- render the menu
- coordinate refreshes
- apply settings
- open external resources
- route menu actions to the provider and policy layers

### Data sources

- [CodexQuotaProvider.swift](/Users/redcreen/Project/codex%20limit/Sources/CodexQuotaProvider.swift)
- [CodexAuthSnapshotStore.swift](/Users/redcreen/Project/codex%20limit/Sources/CodexAuthSnapshotStore.swift)

Responsibilities:

- read quota snapshots from the official usage API
- read realtime quota events from `~/.codex/logs_1.sqlite`
- fall back to archived sessions when needed
- read account and auth information from `~/.codex/auth.json`
- persist and load local account snapshots for switching

### Presentation and formatting

- [CodexQuotaSnapshot.swift](/Users/redcreen/Project/codex%20limit/Sources/CodexQuotaSnapshot.swift)
- [AppLanguage.swift](/Users/redcreen/Project/codex%20limit/Sources/AppLanguage.swift)
- [QuotaDisplayPolicy.swift](/Users/redcreen/Project/codex%20limit/Sources/QuotaDisplayPolicy.swift)
- [StatusBadgeView.swift](/Users/redcreen/Project/codex%20limit/Sources/StatusBadgeView.swift)

Responsibilities:

- convert raw quota snapshots into menu-ready and badge-ready presentation
- compute labels, reset text, relative update time, colors, and pace markers
- localize all app-facing strings
- keep the status bar badge compact and readable

### Behavior and safety policies

- [QuotaRefreshPolicy.swift](/Users/redcreen/Project/codex%20limit/Sources/QuotaRefreshPolicy.swift)
- [QuotaNotificationPolicy.swift](/Users/redcreen/Project/codex%20limit/Sources/QuotaNotificationPolicy.swift)
- [RefreshRequestGate.swift](/Users/redcreen/Project/codex%20limit/Sources/RefreshRequestGate.swift)

Responsibilities:

- decide which source should be preferred for a given refresh mode
- prevent stale refreshes from overwriting newer accepted data
- decide when notifications should fire
- deduplicate repeated warning/reset notifications

### CLI

- [cli_main.swift](/Users/redcreen/Project/codex%20limit/Sources/cli_main.swift)
- [CliFormatter.swift](/Users/redcreen/Project/codex%20limit/Sources/CliFormatter.swift)

Responsibilities:

- expose the shared quota/account behavior through `codexQuotaPeek`
- support human-readable output and JSON output
- support manual API refresh and local account switching commands

## Data flow

The main app refresh path works like this:

1. The app launches and renders a placeholder badge immediately.
2. It performs a startup refresh using local data first so the menu bar is not empty.
3. It then performs an async API refresh to align with the latest official value.
4. File watchers on `~/.codex/logs_1.sqlite` and `~/.codex/auth.json` trigger lightweight refreshes.
5. A fixed `20s` fallback timer still runs in case file events are missed.
6. Manual `Refresh Now (API)` forces an API read.
7. The accepted snapshot is converted into `StatusPresentation`.
8. The badge and menu rows are redrawn from that presentation.

## Quota source strategy

There are three practical data sources:

### API

Source:

- `https://chatgpt.com/backend-api/wham/usage`

Strengths:

- usually closest to the official Codex UI
- best for manual refresh

Tradeoffs:

- should not be polled too aggressively
- may fail independently of local logs

### Realtime local logs

Source:

- `~/.codex/logs_1.sqlite`

Strengths:

- lightweight and local
- good fit for automatic refresh
- available even when the official UI is not open

Tradeoffs:

- can lag behind the official UI by one event
- contains many non-quota logs, so filtering must stay precise

### Archived sessions

Source:

- `~/.codex/archived_sessions/*.jsonl`

Strengths:

- final fallback when realtime logs are unavailable

Tradeoffs:

- not ideal for freshness

## Refresh modes

The app does not treat all refreshes the same.

### Startup

- local-first to get something on screen quickly
- followed by async API refresh for freshness

### Automatic

- usually local-first
- can be influenced by the selected source strategy in preferences

### Manual refresh

- always tries to get the latest API value
- if API succeeds, that result becomes the temporary freshness baseline

## Why stale data protection exists

Several bugs during development came from older results racing newer ones.
The current behavior protects against that in three ways:

1. Only the newest issued refresh request may update the UI.
2. An older reset window is never allowed to replace a newer accepted window.
3. Within the same reset window, obviously older quota regressions are rejected.

This is why the app can survive:

- delayed API responses
- delayed log writes
- out-of-order background refresh completions

## Trend logic

The trend section is intentionally conservative now.

### Current window only

Trend analysis only uses rows from the current reset window:

- `5 hours` trends only use the current 5-hour window
- `7 days` trends only use the current weekly reset window

This prevents historical values from a previous reset period from leaking into
the current trend.

### Meaningful-only display

Trend rows are only shown when they communicate something useful:

- very small moves are hidden
- weak `steady` labels are hidden
- low points that are too close to the current value are hidden

The goal is for the trend section to behave like a risk explanation, not like a
debug stream.

## Pace marker logic

`!` and `!!` do not mean “low quota”. They mean:

- usage is ahead of the selected pace for that window

The app keeps two separate concepts:

- `% left`: how much quota remains
- `! / !!`: whether consumption pace is ahead of plan

For weekly pace, the user can choose a workload preset such as:

- `40h/week`
- `56h/week`
- `70h/week`

Those presets only change pace sensitivity. They do not change the underlying
remaining quota percentage.

## Notifications

The app supports notification categories instead of one global noisy stream:

- low quota
- pace alerts
- reset reminders

The policy layer deduplicates repeated alerts so the same state does not fire on
every refresh tick.

## Language model

App language now behaves like this:

- first launch follows the macOS system language
- once the user selects a language explicitly, that choice is stored

The menu, preferences window, and most presentation text flow through
[AppLanguage.swift](/Users/redcreen/Project/codex%20limit/Sources/AppLanguage.swift).

## Account switching model

The app distinguishes between:

- the current active auth state
- locally saved auth snapshots
- history-only accounts seen in logs

This matters because not every account visible in logs is actually available
for instant local switching.

The current model is:

- saved snapshots can switch locally
- history-only identities require re-login

## CLI architecture

The CLI is not a separate product with separate logic. It reuses the same core
provider and policy behavior.

Important commands include:

- `codexQuotaPeek status`
- `codexQuotaPeek status --refresh`
- `codexQuotaPeek status --json`
- `codexQuotaPeek accounts list`
- `codexQuotaPeek accounts save`
- `codexQuotaPeek accounts switch ...`

That shared architecture is intentional: app, CLI, and integrations should
describe the same quota truth.

## Integrations

First-party integrations live under:

- [integrations/README.md](/Users/redcreen/Project/codex%20limit/integrations/README.md)

Current integration:

- [openclaw-status-codex-quota](/Users/redcreen/Project/codex%20limit/integrations/openclaw-status-codex-quota)

Design goal:

- integration code may adapt the output shape
- but it should continue using `codexQuotaPeek` as the source of truth

## Testing strategy

Regression tests live in:

- [Tests/TestRunner.swift](/Users/redcreen/Project/codex%20limit/Tests/TestRunner.swift)

The test suite focuses on the bugs that have already happened in real usage:

- sqlite row parsing
- stale refresh protection
- startup API fallback behavior
- pace thresholds
- trend window correctness
- localization-sensitive presentation
- notification deduplication

This is deliberate: the tests are not abstract coverage padding, they are there
to stop known regressions from returning.

## Release architecture

Release flow is built around these files:

- [VERSION](/Users/redcreen/Project/codex%20limit/VERSION)
- [CHANGELOG.md](/Users/redcreen/Project/codex%20limit/CHANGELOG.md)
- [RELEASE.md](/Users/redcreen/Project/codex%20limit/RELEASE.md)
- [scripts/prepare_release.sh](/Users/redcreen/Project/codex%20limit/scripts/prepare_release.sh)

The release pipeline currently handles:

- tests
- app build
- CLI build
- zip packaging
- release notes generation
- GitHub release draft text generation

## Practical guiding principles

The project has gradually settled on a few implementation rules:

- local-first during passive refresh
- API-first during explicit refresh
- never let stale results overwrite fresher accepted state
- only show UI details that help a real decision
- prefer product explanations over debug-looking output
- add regression tests for every real bug that reaches the UI
