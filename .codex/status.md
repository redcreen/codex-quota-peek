# Project Status

## Delivery Tier
- Tier: `medium`
- Why this tier: multi-session maintenance needs a lightweight but durable control surface
- Last reviewed: `2026-04-13`

## Current Phase

Refresh-scheduling hardening active; docs baseline already aligned.

## Active Slice

`formalize-refresh-scheduling-and-menu-open-freshness-boundary`

## Done

- `.codex` control truth is on the current project-assistant generation, including strategy / program-board / delivery / PTL / worker-handoff / entry-routing layers
- bilingual durable docs now cover README, docs home, architecture, requirements, test plan, release guide, signing plan, and the OpenClaw integration docs
- maintainer-facing development-plan docs now exist under `docs/reference/codex-quota-peek/`
- `project assistant continue` now resumes from durable repo truth instead of template-state retrofit notes

## In Progress

- queue the next concrete code slice around refresh scheduling, menu-open freshness, and manual API refresh overlap
- keep control truth and maintainer docs aligned with the validated baseline while that slice is being prepared

## Blockers / Open Decisions

- refresh scheduling still spans the app shell and helper policies; another small refresh tweak could reopen drift until the next slice lands
- after the refresh-scheduling slice closes, decide whether release hardening or broader integration follow-on becomes the next named milestone

## Next 3 Actions
1. Wire `RefreshSchedulingPolicy` through the remaining refresh entry points so manual API refresh, startup API refresh, and automatic refresh do not fight each other.
2. Re-run `./scripts/test.sh` and confirm refresh-path coverage stays green after the policy boundary is fully wired.
3. Refresh requirements, test plan, and release-facing docs from the validated result, then decide whether release hardening or integration work is next.

## Current Execution Line

- Objective: land one explicit refresh-scheduling boundary so manual API refresh, startup freshness checks, and menu-open API refresh stay consistent across `AppDelegate`, policy helpers, tests, and docs
- Plan Link: formalize-refresh-scheduling-and-menu-open-freshness-boundary
- Runway: one checkpoint covering helper wiring, refresh-path validation, and maintainer-facing doc refresh
- Progress: 1 / 4 tasks complete
- Stop Conditions:
  - blocker requires human direction
  - validation fails and changes the direction
  - product behavior, compatibility, or release-hardening priority needs user judgment

## Execution Tasks

- [x] EL-1 isolate the refresh overlap boundary across manual refresh, startup API refresh, automatic refresh, and menu-open refresh
- [ ] EL-2 wire `RefreshSchedulingPolicy` through the remaining refresh entry points and keep manual refresh protection consistent
- [ ] EL-3 run `./scripts/test.sh` and confirm refresh-path coverage stays green
- [ ] EL-4 refresh requirements, test-plan, and release-facing maintainer docs from the validated result

## Development Log Capture

- Trigger Level: high
- Pending Capture: no
- Last Entry: not recorded yet; the first refresh-scheduling or release-hardening decision should create the initial durable devlog entry

## Architecture Supervision
- Signal: `yellow`
- Signal Basis: refresh behavior has already improved through several focused commits, but the policy boundary still needs one durable owner before more refresh-path tweaks accumulate in `AppDelegate`
- Root Cause Hypothesis: manual refresh, startup API refresh, and menu-open freshness checks can drift when the repo changes the app shell faster than it updates the shared policy/helper layer and tests
- Correct Layer: `RefreshSchedulingPolicy.swift`, `QuotaRefreshPolicy.swift`, `AppDelegate.swift`, `Tests/TestRunner.swift`, and the requirements / test-plan docs
- Automatic Review Trigger: another refresh-path change lands in `AppDelegate` without a matching policy/helper or test update
- Escalation Gate: raise but continue

## Current Escalation State
- Current Gate: raise but continue
- Reason: the next slice is clear and can continue, but refresh-path drift should stay visible until policy, tests, and docs agree on one boundary
- Next Review Trigger: review again when refresh behavior changes, tests fail, or the repo decides to prioritize release hardening instead
