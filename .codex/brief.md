# Project Brief

## Delivery Tier
- Tier: `medium`
- Why this tier: multi-session maintenance needs a lightweight but durable control surface
- Last reviewed: `2026-04-13`

## Outcome

Keep `Codex Quota Peek` as a reliable macOS quota companion that serves three aligned surfaces:

- menu bar app
- local CLI
- first-party integrations

The repo should make quota visibility fast, preserve freshness semantics, and keep release packaging predictable.

## Scope

- menu bar app behavior and menu contract
- local CLI behavior
- shared quota parsing, formatting, and refresh policy
- release packaging, install scripts, and public documentation
- first-party integrations under `integrations/`

## Non-Goals

- replacing the official Codex product UI
- supporting non-macOS desktop platforms right now
- treating every experimental integration as a first-class shipped surface

## Constraints

- macOS-first implementation with app minimum version `13+`
- local and lightweight data paths should remain useful even when the official UI is closed
- stale or lower-quality snapshots must not overwrite newer accepted results
- current public release path is still unsigned and not notarized

## Definition of Done

- public docs are readable, bilingual, and switchable
- maintainer state is recoverable from `.codex/*` and `docs/reference/codex-quota-peek/development-plan*`
- regression tests and local build paths still pass
- app, CLI, and integration surfaces remain aligned with the current requirements baseline
