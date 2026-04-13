# Docs Home

[English](README.md) | [中文](README.zh-CN.md)

Codex Quota Peek already has several durable docs. This page routes readers by goal so they do not have to guess between product docs, release docs, and maintainer control docs.

## Start Here

- install and try the app or CLI: [README](../README.md#quick-start)
- understand product surfaces and data flow: [architecture.md](architecture.md)
- see the current product contract: [requirements.md](requirements.md)
- verify behavior before release: [test-plan.md](test-plan.md)
- resume as a maintainer: [reference/codex-quota-peek/development-plan.md](reference/codex-quota-peek/development-plan.md)

## By Goal

| Goal | Read This |
| --- | --- |
| Try the app locally | [README Quick Start](../README.md#quick-start) |
| Understand how app, CLI, and integrations fit together | [architecture.md](architecture.md) |
| See what behavior is considered stable | [requirements.md](requirements.md) |
| Verify release readiness | [test-plan.md](test-plan.md) |
| Resume below the public-doc layer as a maintainer | [reference/codex-quota-peek/development-plan.md](reference/codex-quota-peek/development-plan.md) |
| Understand signing gaps and future hardening | [signing-and-notarization-plan.md](signing-and-notarization-plan.md) |
| Prepare a release | [RELEASE.md](../RELEASE.md) |

## Public Doc Scope

- `README*`: user-facing overview, install path, capabilities, and entry links
- `docs/architecture*`: stable system shape and major design choices
- `docs/requirements*`: current product contract and release-blocking regressions
- `docs/test-plan*`: verification strategy and release gate
- `docs/signing-and-notarization-plan*`: release hardening plan for trusted macOS distribution
- `docs/reference/codex-quota-peek/development-plan*`: maintainer-facing execution queue below the public docs and above `.codex/plan.md`
- `.codex/*`: maintainer control surface, not public product docs
