[English](README.md) | [中文](README.zh-CN.md)

[English](README.md) | [中文](README.zh-CN.md)

# Codex Quota Peek

> macOS menu bar app and local CLI for checking Codex quota quickly, with the same quota data exposed to first-party integrations.

![Codex Quota Peek menu demo](/Users/redcreen/project/codex%20limit/docs/screenshots/menu-demo.png)

## Who This Is For

- people who use Codex heavily and want `5h / 7d` quota visible without reopening the app
- macOS users who want both a menu bar experience and a scriptable local CLI
- maintainers who need the same quota semantics in integrations such as the OpenClaw status plugin

## Quick Start

Fastest install:

```bash
open "https://github.com/redcreen/codex-quota-peek/releases/latest/download/CodexQuotaPeek-latest.dmg"
```

Then:

- open the DMG
- drag `CodexQuotaPeek.app` into `Applications`
- open `/Applications/CodexQuotaPeek.app`

If macOS blocks the unsigned build, either use Finder `Right Click -> Open`, or install from source:

```bash
git clone https://github.com/redcreen/codex-quota-peek.git
cd codex-quota-peek
./scripts/install_app.sh
```

Optional CLI install:

```bash
./scripts/install_cli.sh
```

## Install

Requirements:

- macOS only
- menu bar app requires macOS 13+
- local Codex usage data under `~/.codex`
- Xcode command-line tools available for local Swift builds

App install:

```bash
./scripts/install_app.sh
```

CLI install:

```bash
./scripts/install_cli.sh
```

Local validation:

```bash
./scripts/test.sh
codexQuotaPeek status --json
```

## Minimal Configuration

No extra configuration is required for the default workflow.

Default behavior:

- launch shows the latest locally readable quota first
- startup follows with an async API refresh for freshness
- automatic refresh watches local Codex logs and auth state
- manual `Refresh Now (API)` prefers the official API
- app language defaults to macOS language until explicitly changed

The only user-facing configuration surface today is inside the app:

- source strategy: `Auto`, `Prefer API`, `Prefer local logs`
- weekly pace mode: `40h`, `56h`, `70h`
- notification toggles: low quota, pace alerts, reset reminders
- app language: `English / 中文`

## Core Capabilities

- menu bar badge for current `5h` and `7d` remaining quota
- dropdown details for resets, freshness, source, credits, and pace explanations
- clickable `?` help for quota semantics
- daily usage chart and weekly pace selector
- manual API refresh
- account switching and local snapshot support
- local CLI via `codexQuotaPeek`
- first-party OpenClaw integration under [`integrations/`](integrations/)

## Common Workflows

Check quota from the CLI:

```bash
codexQuotaPeek status
codexQuotaPeek status --refresh
codexQuotaPeek status --json
codexQuotaPeek accounts list
```

Build everything from source:

```bash
./scripts/test.sh
./scripts/build_app.sh
./scripts/build_cli.sh
./scripts/package_release.sh
```

Use the OpenClaw integration:

- [Integrations index](integrations/README.md)
- [OpenClaw status plugin](integrations/openclaw-status-codex-quota/README.md)

## Documentation Map

- [Docs Home](docs/README.md)
- [Architecture](docs/architecture.md)
- [Requirements](docs/requirements.md)
- [Test Plan](docs/test-plan.md)
- [Signing and Notarization Plan](docs/signing-and-notarization-plan.md)
- [Release Guide](RELEASE.md)
- [Changelog](CHANGELOG.md)

## Development

- app entry points live in [`Sources/main.swift`](Sources/main.swift) and [`Sources/AppDelegate.swift`](Sources/AppDelegate.swift)
- quota loading and freshness selection live around [`Sources/CodexQuotaProvider.swift`](Sources/CodexQuotaProvider.swift) and [`Sources/QuotaRefreshPolicy.swift`](Sources/QuotaRefreshPolicy.swift)
- CLI entry lives in [`Sources/cli_main.swift`](Sources/cli_main.swift)
- regression coverage lives in [`Tests/TestRunner.swift`](Tests/TestRunner.swift)
- release automation lives under [`scripts/`](scripts/)
- maintainer control state lives under [`.codex/`](.codex/)

## License

MIT
