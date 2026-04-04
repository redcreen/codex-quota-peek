# Status Codex Quota

`status-codex-quota` is an OpenClaw plugin that appends `codexQuotaPeek` output
to OpenClaw status results.

It is designed around three rules:

- call the quota CLI with a short timeout
- inject only when a valid quota result exists
- never let quota lookup block status forever

## What it does

- appends a `Codex Quota` section to plain-text `openclaw status`
- overrides `/status` through the plugin command path and appends the same
  quota block when available
- preserves `--json` output shape by adding a top-level `codexQuota` object
  only when valid quota JSON exists
- skips injection completely when `codexQuotaPeek` times out, errors, or
  returns unusable data

## Install

From the repo root:

```bash
cd integrations/openclaw-status-codex-quota
./scripts/install.sh
```

Or from this directory:

```bash
./scripts/install.sh
```

Or manually:

```bash
openclaw plugins install -l .
openclaw plugins enable status-codex-quota
```

Then verify:

```bash
openclaw plugins list
openclaw status
openclaw status --json
```

Example plain-text injection:

```text
Codex Quota · 67560691@qq.com · Pro
- 5 hours: H 73% · reset 20:23
- 7 days: W 86%! · reset Apr 11
- updated just updated · source API
```

## Default behavior

- base status command: `openclaw`
- quota command: `codexQuotaPeek`
- quota timeout: `600ms`
- slash override: enabled
- CLI text injection: enabled

## Config

Example `~/.openclaw/openclaw.json` entry:

```json5
{
  plugins: {
    allow: ["status-codex-quota"],
    load: {
      paths: ["/ABSOLUTE/PATH/TO/status-codex-quota"]
    },
    entries: {
      "status-codex-quota": {
        enabled: true,
        config: {
          quotaTimeoutMs: 600,
          cliInject: true,
          slashOverride: true
        }
      }
    }
  }
}
```

## Test

```bash
npm test
```

## Scripts

```bash
./scripts/install.sh
./scripts/uninstall.sh
```
