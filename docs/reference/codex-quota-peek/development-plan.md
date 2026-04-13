# Codex Quota Peek Development Plan

[English](development-plan.md) | [中文](development-plan.zh-CN.md)

## Purpose

This document is the durable maintainer-facing execution queue that sits below the public docs and above [`.codex/plan.md`](../../../.codex/plan.md).

It answers:

`where should maintainers resume, what slice is active now, and what order should product and release follow-up happen in?`

## Related Documents

- [../../../README.md](../../../README.md)
- [../../README.md](../../README.md)
- [../../architecture.md](../../architecture.md)
- [../../requirements.md](../../requirements.md)
- [../../test-plan.md](../../test-plan.md)
- [../../../RELEASE.md](../../../RELEASE.md)

## How To Use This Plan

1. Read [docs/README.md](../../README.md) and [requirements.md](../../requirements.md) first if you need product context.
2. Use `Current Position` and `Ordered Execution Queue` here to see where the next maintainer-facing slice starts.
3. Drop into [`.codex/status.md`](../../../.codex/status.md) and [`.codex/plan.md`](../../../.codex/plan.md) only when you need the live execution detail.
4. This repo does not yet need a standalone `docs/roadmap.md`; treat this document as the durable milestone queue until the work splits into multiple named roadmap tracks.

## Current Position

| Item | Current Value | Meaning |
| --- | --- | --- |
| Current Phase | `refresh-scheduling hardening active; docs baseline already aligned` | the repo has moved past template-state retrofit and now has one explicit active code slice |
| Active Slice | `formalize-refresh-scheduling-and-menu-open-freshness-boundary` | the next mainline work is to keep manual refresh, startup API refresh, automatic refresh, and menu-open freshness on one named policy boundary |
| Current Execution Line | land one explicit refresh-scheduling boundary across `RefreshSchedulingPolicy`, `QuotaRefreshPolicy`, `AppDelegate`, tests, and the requirements / test-plan docs | the repo should close this as one checkpoint instead of many small follow-up tweaks |
| Current Validation | `project assistant continue`, `validate_control_surface_quality.py`, `validate_docs_system.py`, and `./scripts/test.sh` | maintainers can now resume from durable truth and keep the next slice tied to real validation |

## Milestone Overview

| Milestone | Status | Goal | Depends On | Exit Criteria |
| --- | --- | --- | --- | --- |
| M1 | done | establish the product baseline across the menu bar app, local CLI, and first-party integration surfaces | core app / CLI / integration code | app, CLI, and integrations share one quota model |
| M2 | done | close the bilingual doc baseline and maintainer recovery surfaces | public docs, `.codex/*`, development-plan docs | maintainers no longer resume from template-state control docs |
| M3 | active | formalize the refresh-scheduling and menu-open freshness boundary | `RefreshSchedulingPolicy`, `QuotaRefreshPolicy`, `AppDelegate`, `Tests/TestRunner.swift` | one policy boundary owns the behavior and the tests stay green |
| M4 | next | choose the next named milestone after M3 closes | validated M3 behavior, release docs, signing plan, integration docs | the repo has one explicit post-M3 line instead of unsorted follow-up work |
| M5 | later | deepen release hardening and trusted macOS distribution | versioned release flow, signing/notarization decisions | the public release path is no longer limited to unsigned local installs |

## Ordered Execution Queue

| Order | Slice | Status | Objective | Validation |
| --- | --- | --- | --- | --- |
| 1 | `close-durable-doc-baseline-and-maintainer-resume-surface` | completed | move the repo out of template-state control docs and create a durable development-plan entrypoint for future maintainers | `project assistant continue`, `validate_control_surface_quality.py`, and `validate_docs_system.py` read as maintainer-facing |
| 2 | `formalize-refresh-scheduling-and-menu-open-freshness-boundary` | current | keep manual API refresh, startup API refresh, automatic refresh, and menu-open freshness on one explicit policy boundary | `./scripts/test.sh` plus refresh-path expectations in requirements and test-plan stay aligned |
| 3 | `expand-refresh-path-tests-and-docs-from-validated-behavior` | queued inside M3 | refresh the requirements, test plan, and release-facing docs from the validated refresh result instead of letting the docs lag the code | requirements and test-plan explain the same behavior that tests exercise |
| 4 | `choose-post-refresh-named-milestone` | next | decide whether release hardening or broader integration follow-on becomes the next named slice | `.codex/status.md`, this plan, and Next 3 Actions all point to the same next milestone |
| 5 | `release-hardening-and-trusted-distribution` | later | turn the current signing/notarization notes into an executable release-hardening slice | release docs, scripts, and macOS trust expectations converge |
| 6 | `broaden-first-party-integrations-after-the-baseline-stays-stable` | later | add more integration depth only after the refresh and release baselines stop moving underneath it | new integrations reuse the stable quota semantics instead of chasing churn |
