# Integrations

[English](README.md) | [中文](README.zh-CN.md)

This folder contains first-party integrations built and maintained alongside
Codex Quota Peek.

## Available integrations

### OpenClaw status quota injection

Path:

- [openclaw-status-codex-quota](/Users/redcreen/Project/codex%20limit/integrations/openclaw-status-codex-quota)

What it does:

- injects `codexQuotaPeek` results into `openclaw status`
- skips injection when quota data is unavailable
- preserves JSON output by adding a `codexQuota` object only when valid data exists
- keeps a short timeout budget so quota lookup does not block status

Docs:

- [openclaw-status-codex-quota/README.md](/Users/redcreen/Project/codex%20limit/integrations/openclaw-status-codex-quota/README.md)
