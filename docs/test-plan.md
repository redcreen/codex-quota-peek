# Test Plan

[English](test-plan.md) | [中文](test-plan.zh-CN.md)

## Scope and Risk

- Scope:
  - quota parsing from realtime logs, archived sessions, and API snapshots
  - refresh preference and stale-result rejection
  - menu contract, language contract, and display-state rebuild behavior
  - CLI availability and basic command paths
  - local build and packaging scripts that gate releases
- Main risks:
  - stale or lower-quality data overwrites a newer accepted snapshot
  - menu contract drifts across languages or refresh modes
  - packaging or install scripts drift away from documented behavior

## Acceptance Cases
| Case | Setup | Action | Expected Result |
| --- | --- | --- | --- |
| Realtime log parsing works | Provide a SQLite-exported pipe-delimited quota row | Parse the row through `CodexQuotaProvider` | Snapshot is produced with correct source and remaining percentages |
| Automatic refresh keeps newer API data over stale logs | Recent API snapshot exists, logs arrive with older timestamp or reset window | Resolve preferred result in automatic mode | API snapshot remains accepted |
| Automatic refresh accepts logs once they catch up | Logs are newer than the last API snapshot | Resolve preferred result in automatic mode | Realtime log snapshot replaces the older API snapshot |
| Display state rebuild stays stable | Store a snapshot, account, and source metadata | Rebuild presentation from cached inputs | Badge lines, account row, and source label stay correct |
| Invalid realtime logs fall back cleanly | Local logs are unreadable but archived sessions exist | Load automatic refresh snapshot | Archived session data is used instead of failing hard |
| CLI remains usable after build | Build the CLI | Run `codexQuotaPeek help` and `codexQuotaPeek accounts list` | Commands exit successfully |

## Automation Coverage

- `./scripts/test.sh` is the primary regression entrypoint
- current automated coverage includes:
  - realtime log parsing
  - API vs local-log freshness preference
  - stale snapshot rejection
  - display-state rebuild logic
  - archived-session fallback behavior
  - CLI build and basic smoke commands
- CI workflow template lives in [github-actions/ci.workflow.yml](github-actions/ci.workflow.yml) and mirrors build-plus-test behavior for GitHub

## Manual Checks

1. Run `./scripts/install_app.sh` and launch `/Applications/CodexQuotaPeek.app`.
2. Confirm the menu bar badge appears and shows `H / W` information instead of an empty state.
3. Open the menu and verify account line, quota rows, pace selector, daily chart, source line, and action list appear in order.
4. Trigger `Refresh Now (API)` and confirm the source/freshness line updates without breaking the menu contract.
5. Switch app language and verify the menu contract still matches the documented structure.
6. Run `./scripts/install_cli.sh`, then check `codexQuotaPeek status`, `codexQuotaPeek status --json`, and `codexQuotaPeek accounts list`.
7. If validating release packaging, run `./scripts/prepare_release.sh` and confirm DMG, ZIP, release notes, and GitHub draft files are generated.

## Test Data and Fixtures

- `Tests/TestRunner.swift` uses deterministic inline snapshots and temporary test directories
- fallback and parsing tests create temporary `.codex` fixtures under the system temp directory
- optional live smoke validation remains opt-in through `CODEX_QUOTA_PEEK_RUN_LIVE_SMOKE=1`

## Release Gate

- `./scripts/test.sh` passes
- `./scripts/build_app.sh` and `./scripts/build_cli.sh` succeed
- install scripts still match the documented quick-start flow
- menu contract, language contract, and freshness behavior remain aligned with [requirements.md](requirements.md)
- release packaging artifacts are generated successfully when a release build is prepared
