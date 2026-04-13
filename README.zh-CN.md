[English](README.md) | [中文](README.zh-CN.md)

# Codex Quota Peek

> 一个 macOS 菜单栏应用加本地 CLI，用来快速查看 Codex quota，并把同一份额度语义复用到一方集成里。

![Codex Quota Peek 菜单示意图](/Users/redcreen/project/codex%20limit/docs/screenshots/menu-demo.png)

## 适用对象

- 高频使用 Codex，希望不打开官方界面也能看到 `5h / 7d` 额度的人
- 既需要菜单栏体验，也需要本地 CLI 的 macOS 使用者
- 需要把同一套 quota 语义接到 OpenClaw 等集成里的维护者

## 快速开始

当前公开构建还没有做 Apple 签名和 notarization，所以现在最稳的安装方式仍然是本地构建后安装。

方式一：克隆后安装 app

```bash
git clone https://github.com/redcreen/codex-quota-peek.git
cd codex-quota-peek
./scripts/install_app.sh
```

方式二：同时安装 app 和 CLI

```bash
./scripts/install_app.sh
./scripts/install_cli.sh
```

安装后可直接验证：

```bash
open /Applications/CodexQuotaPeek.app
codexQuotaPeek status
```

## 安装

环境要求：

- 仅支持 macOS
- 菜单栏 app 最低要求 macOS 13+
- 本地存在 Codex 使用数据目录 `~/.codex`
- 本机已具备 Xcode command-line tools，可进行本地 Swift 构建

安装 app：

```bash
./scripts/install_app.sh
```

安装 CLI：

```bash
./scripts/install_cli.sh
```

本地验证：

```bash
./scripts/test.sh
codexQuotaPeek status --json
```

## 最简配置

默认工作流不需要额外配置。

默认行为：

- 启动时先显示本地可读取的最近 quota
- 启动后再异步走一次 API 刷新，追平最新值
- 自动刷新主要监听本地 Codex 日志和 auth 状态
- 手动 `Refresh Now (API)` 优先使用官方 API
- 应用语言默认跟随 macOS，除非用户显式切换

当前主要配置入口都在 app 内部：

- 数据源策略：`Auto`、`Prefer API`、`Prefer local logs`
- 每周节奏模式：`40h`、`56h`、`70h`
- 通知开关：低额度、节奏预警、重置提醒
- 语言：`English / 中文`

## 核心能力

- 菜单栏 badge 显示当前 `5h` 和 `7d` 剩余额度
- 下拉菜单显示重置时间、刷新来源、信用额度和节奏解释
- 点击 `?` 可查看 quota 语义说明
- 每日用量图和每周节奏选择器
- 手动 API 刷新
- 账号切换和本地快照支持
- 本地 CLI：`codexQuotaPeek`
- 一方 OpenClaw 集成，位于 [`integrations/`](integrations/)

## 常见工作流

通过 CLI 查看额度：

```bash
codexQuotaPeek status
codexQuotaPeek status --refresh
codexQuotaPeek status --json
codexQuotaPeek accounts list
```

从源码构建完整产物：

```bash
./scripts/test.sh
./scripts/build_app.sh
./scripts/build_cli.sh
./scripts/package_release.sh
```

使用 OpenClaw 集成：

- [集成总览](integrations/README.md)
- [OpenClaw 状态插件](integrations/openclaw-status-codex-quota/README.md)

## 文档导航

- [文档首页](docs/README.zh-CN.md)
- [架构](docs/architecture.zh-CN.md)
- [需求基线](docs/requirements.zh-CN.md)
- [测试计划](docs/test-plan.zh-CN.md)
- [签名与公证方案](docs/signing-and-notarization-plan.zh-CN.md)
- [发布指南](RELEASE.zh-CN.md)
- [变更记录](CHANGELOG.zh-CN.md)

## 开发

- app 入口位于 [Sources/main.swift](Sources/main.swift) 和 [Sources/AppDelegate.swift](Sources/AppDelegate.swift)
- quota 读取与刷新策略主要位于 [Sources/CodexQuotaProvider.swift](Sources/CodexQuotaProvider.swift) 和 [Sources/QuotaRefreshPolicy.swift](Sources/QuotaRefreshPolicy.swift)
- CLI 入口位于 [Sources/cli_main.swift](Sources/cli_main.swift)
- 回归测试位于 [Tests/TestRunner.swift](Tests/TestRunner.swift)
- 发版脚本位于 [scripts/](scripts/)
- 维护控制面位于 [.codex/](.codex/)

## 许可

MIT
