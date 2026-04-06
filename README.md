# Codex Quota Peek

[中文](#中文) | [English](#english)

macOS menu bar app + CLI for checking Codex quota quickly.

![Codex Quota Peek menu demo](/Users/redcreen/Project/codex%20limit/docs/screenshots/menu-demo.png)

## 中文

### 这是什么

`Codex Quota Peek` 是一个专门给 macOS 做的 Codex 用量查看工具。

它解决的是很直接的问题：

- 不想反复打开 Codex 才看额度
- 想在菜单栏里直接看到 `5h / 7d` 剩余
- 想知道自己是不是已经明显跑快了
- 想手动点一下就走 API 拉最新值

### 快速使用

一键下载安装：
[下载最新版 DMG](https://github.com/redcreen/codex-quota-peek/raw/main/release/CodexQuotaPeek-0.1.0.dmg)

安装步骤：

1. 下载 `CodexQuotaPeek-0.1.0.dmg`
2. 打开 DMG，把 `CodexQuotaPeek.app` 拖进 `Applications`
3. 双击打开，应用会常驻在菜单栏

如果 macOS 提示安全限制，到“系统设置 -> 隐私与安全性”里允许打开即可。

### 适合谁

- 日常高频用 Codex 的人
- 想同时看 `5h` 和 `7d` 两个窗口的人
- 想用 CLI 或 OpenClaw 插件接额度信息的人

### 你能看到什么

- 菜单栏 badge：`H xx% / W xx%`
- 下拉菜单：`5h / 7d`、重置时间、剩余、来源、更新时间
- `?` 说明：点击后查看当前条目的计算方式
- 每周工作时长切换：`40h / 56h / 70h`
- 每日用量图
- `Refresh Now (API)` 手动拉最新值
- 账号切换、状态页、使用面板、日志定位
- `codexQuotaPeek` CLI

### 语言

- README 本身支持中英文切换
- 应用界面支持 `English / 中文`
- 默认跟随 macOS 系统语言

### 环境要求

- 只支持 macOS
- 菜单栏 app 最低要求：macOS 13+
- 需要本机已安装并使用过 Codex，且存在 `~/.codex`
- CLI 同样只在 macOS 上验证和支持

### CLI

```bash
codexQuotaPeek status
codexQuotaPeek status --refresh
codexQuotaPeek status --json
codexQuotaPeek accounts list
```

### 集成

- 集成总览：[integrations/README.md](/Users/redcreen/Project/codex%20limit/integrations/README.md)
- OpenClaw 插件：[integrations/openclaw-status-codex-quota](/Users/redcreen/Project/codex%20limit/integrations/openclaw-status-codex-quota)

### 工作原理

默认策略：

1. 启动后先显示本地可读结果
2. 自动刷新主要跟随本地 Codex 日志
3. 手动 `Refresh Now (API)` 强制走 API
4. 文件监听和定时刷新一起兜底

核心数据源：

- `~/.codex/logs_1.sqlite`
- `~/.codex/archived_sessions/*.jsonl`
- 官方 usage API（手动刷新优先使用）

完整实现文档：
[docs/architecture.md](/Users/redcreen/Project/codex%20limit/docs/architecture.md)

### 已知边界

- 官方 Codex 面板有时会比本工具更早显示最新额度
- 本工具已经尽量优先走更实时的数据源，但不同来源之间仍然存在短暂追平时间

### 从源码构建

```bash
./scripts/test.sh
./scripts/build_app.sh
./scripts/build_cli.sh
./scripts/package_release.sh
./scripts/install_app.sh
./scripts/install_cli.sh
```

### 发布

- 当前发布版本：`0.1.0`
- 推荐下载文件：`CodexQuotaPeek-0.1.0.dmg`
- 版本记录：[CHANGELOG.md](/Users/redcreen/Project/codex%20limit/CHANGELOG.md)
- 发版流程：[RELEASE.md](/Users/redcreen/Project/codex%20limit/RELEASE.md)

### Roadmap

接下来重点继续做：

- 每日用量 ledger，避免重复扫日志
- 每日用量颜色逻辑按“当天是否压住节奏”判断
- `Preferences...` 继续产品化整理
- 更多官方集成

## English

### What It Is

`Codex Quota Peek` is a macOS menu bar app built for one job: checking Codex quota fast.

It is for people who want to:

- see `5h / 7d` quota without reopening Codex
- know when usage pace is getting risky
- manually force an API refresh when needed
- use the same quota data from a CLI or integration

### Quick Start

One-click download:
[Download the latest DMG](https://github.com/redcreen/codex-quota-peek/raw/main/release/CodexQuotaPeek-0.1.0.dmg)

Install:

1. Download `CodexQuotaPeek-0.1.0.dmg`
2. Open the DMG and drag `CodexQuotaPeek.app` into `Applications`
3. Open it once, then it will live in the menu bar

If macOS blocks the app, allow it from “System Settings -> Privacy & Security”.

### What You Get

- Menu bar badge: `H xx% / W xx%`
- Dropdown details for `5h / 7d`, resets, remaining quota, source, and freshness
- Clickable `?` explanations for quota rows
- Weekly pace selector: `40h / 56h / 70h`
- Daily usage chart
- `Refresh Now (API)` for an explicit latest fetch
- Account switching, usage dashboard, status page, log shortcuts
- `codexQuotaPeek` CLI

### Language

- This README supports both English and Chinese
- The app UI supports `English / 中文`
- By default, the app follows your macOS language

### Requirements

- macOS only
- Menu bar app requires macOS 13+
- Requires a local Codex setup with an existing `~/.codex`
- CLI is currently supported and tested on macOS only

### CLI

```bash
codexQuotaPeek status
codexQuotaPeek status --refresh
codexQuotaPeek status --json
codexQuotaPeek accounts list
```

### Integrations

- Integrations index: [integrations/README.md](/Users/redcreen/Project/codex%20limit/integrations/README.md)
- OpenClaw plugin: [integrations/openclaw-status-codex-quota](/Users/redcreen/Project/codex%20limit/integrations/openclaw-status-codex-quota)

### How It Works

Default behavior:

1. Show the latest locally available value at launch
2. Follow local Codex logs for background refresh
3. Use the official API for manual `Refresh Now (API)`
4. Keep file watching and timed refresh as fallback

Primary data sources:

- `~/.codex/logs_1.sqlite`
- `~/.codex/archived_sessions/*.jsonl`
- official usage API

Full implementation notes:
[docs/architecture.md](/Users/redcreen/Project/codex%20limit/docs/architecture.md)

### Known Limits

- The official Codex UI may sometimes surface newer quota values slightly earlier
- This app tries to prefer fresher sources when possible, but different sources can still temporarily converge at different times

### Build From Source

```bash
./scripts/test.sh
./scripts/build_app.sh
./scripts/build_cli.sh
./scripts/package_release.sh
./scripts/install_app.sh
./scripts/install_cli.sh
```

### Release

- Current release tag: `0.1.0`
- Recommended download: `CodexQuotaPeek-0.1.0.dmg`
- Changelog: [CHANGELOG.md](/Users/redcreen/Project/codex%20limit/CHANGELOG.md)
- Release guide: [RELEASE.md](/Users/redcreen/Project/codex%20limit/RELEASE.md)

### Roadmap

Next product work focuses on:

- a local daily-usage ledger to avoid rescanning logs
- better daily usage colors based on whether each day stayed within pace
- further product polish for `Preferences...`
- more official integrations
