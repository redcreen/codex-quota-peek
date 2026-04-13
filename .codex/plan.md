# Project Plan

## Current Phase

`Refresh-scheduling hardening active; docs baseline already aligned.`

## Current Execution Line

- Objective: land one explicit refresh-scheduling boundary so manual API refresh, startup freshness checks, and menu-open API refresh stay consistent across `AppDelegate`, policy helpers, tests, and docs
- Plan Link: formalize-refresh-scheduling-and-menu-open-freshness-boundary
- Runway: one checkpoint covering helper wiring, refresh-path tests, and maintainer-facing doc updates
- Progress: 1 / 4 tasks complete
- Stop Conditions:
  - blocker requires human direction
  - validation fails and changes the direction
  - product behavior, compatibility, or release-hardening priority needs user judgment
- Validation:
  - `./scripts/test.sh`
  - `python3 /Users/redcreen/.codex/skills/project-assistant/scripts/validate_docs_system.py .`
  - `python3 /Users/redcreen/.codex/skills/project-assistant/scripts/validate_control_surface_quality.py .`
  - requirements / test-plan docs stay aligned with the refresh behavior that tests validated

## Slices
- Slice: close-durable-doc-baseline-and-maintainer-resume-surface
  - Objective: move the repo out of template-state control docs, create the maintainer development plan, and make continue / progress / handoff resume from durable truth
  - Dependencies: `README*`, `docs/README*`, `docs/test-plan*`, `.codex/status.md`, `.codex/plan.md`
  - Risks: maintainers keep reading template-state `.codex` docs and cannot tell what the next slice really is
  - Validation: `validate_control_surface_quality.py`, `validate_docs_system.py`, and `project assistant continue` all read as maintainer-facing instead of template retrofit output
  - Exit Condition: control truth and durable docs point to one explicit next slice

- Slice: formalize-refresh-scheduling-and-menu-open-freshness-boundary
  - Objective: keep manual API refresh, startup API refresh, automatic refresh, and menu-open freshness on one explicit policy boundary
  - Dependencies: `Sources/RefreshSchedulingPolicy.swift`, `Sources/QuotaRefreshPolicy.swift`, `Sources/AppDelegate.swift`, `Tests/TestRunner.swift`, `docs/requirements*`, `docs/test-plan*`
  - Risks: refresh behavior drifts through small app-shell edits, causing stale or redundant refreshes that tests and docs do not explain
  - Validation: `./scripts/test.sh` passes and the refresh-path tests around manual / API / menu-open behavior stay green
  - Exit Condition: one policy boundary owns the behavior and the docs describe the validated result

- Slice: choose-post-refresh-named-milestone
  - Objective: decide whether release hardening or broader integration follow-on becomes the next named slice after refresh scheduling closes
  - Dependencies: validated refresh behavior, release docs, signing plan, integration docs
  - Risks: the repo drifts back into unsorted follow-up work instead of one named maintainer-facing line
  - Validation: `status.md`, development-plan docs, and Next 3 Actions all point to the same next milestone
  - Exit Condition: the next named slice is explicit before more cross-cutting work starts

## Execution Tasks

- [x] EL-1 isolate the refresh overlap boundary across manual refresh, startup API refresh, automatic refresh, and menu-open refresh
- [ ] EL-2 wire `RefreshSchedulingPolicy` through the remaining refresh entry points and keep manual refresh protection consistent
- [ ] EL-3 run `./scripts/test.sh` and confirm refresh-path coverage stays green
- [ ] EL-4 refresh requirements, test-plan, and release-facing maintainer docs from the validated result

## Development Log Capture

- Trigger Level: high
- Auto-Capture When:
  - the refresh boundary changes in a way future maintainers would need to reconstruct
  - the repo chooses release hardening over refresh scheduling as the next named milestone
  - a reusable policy/helper replaces repeated refresh tweaks in the app shell
  - tests or docs expose a non-obvious tradeoff in freshness semantics
- Skip When:
  - the change is mechanical or wording-only
  - no durable reasoning changed
  - docs simply mirrored an already-validated behavior
  - the change stayed local and introduced no durable tradeoff

## Architecture Supervision
- Signal: `yellow`
- Signal Basis: the repo has already improved freshness behavior, but the refresh boundary is still easy to split across `AppDelegate`, `QuotaRefreshPolicy`, and small follow-up patches if the next slice is not finished as one unit
- Problem Class: refresh behavior is cross-cutting: one small tweak can silently affect menu-open freshness, manual refresh protection, automatic refresh cadence, and maintainer docs at the same time
- Root Cause Hypothesis: the codebase has the right ingredients, but they still need one named slice to finish wiring `RefreshSchedulingPolicy` into the authoritative boundary and lock it down with tests
- Correct Layer: `RefreshSchedulingPolicy.swift`, `QuotaRefreshPolicy.swift`, `AppDelegate.swift`, `Tests/TestRunner.swift`, `docs/requirements*`, and `docs/test-plan*`
- Rejected Shortcut: landing more `AppDelegate` refresh tweaks without first closing the shared policy/helper and test boundary
- Automatic Review Trigger: another refresh-path change lands without a matching policy/helper or test update
- Escalation Gate: raise but continue

## Escalation Model

- Continue Automatically: wiring and validating the refresh-policy boundary without changing product direction or release promises
- Raise But Continue: refresh-path drift is visible but still fits within the current direction and can be closed inside one checkpoint
- Require User Decision: refresh behavior changes the intended product contract, compatibility expectations, or bumps release hardening ahead of the current slice
