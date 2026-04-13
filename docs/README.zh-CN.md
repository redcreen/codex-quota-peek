# 文档首页

[English](README.md) | [中文](README.zh-CN.md)

Codex Quota Peek 已经有多份 durable docs。这个页面按目标分流，避免读者在产品文档、发布文档和维护控制面之间来回猜。

## 从这里开始

- 安装并试用 app 或 CLI：[README](../README.zh-CN.md#快速开始)
- 了解 app、CLI 和集成如何拼起来：[architecture.zh-CN.md](architecture.zh-CN.md)
- 查看当前产品契约：[requirements.zh-CN.md](requirements.zh-CN.md)
- 发版前确认验证覆盖：[test-plan.zh-CN.md](test-plan.zh-CN.md)
- 作为维护者恢复当前执行队列：[reference/codex-quota-peek/development-plan.zh-CN.md](reference/codex-quota-peek/development-plan.zh-CN.md)

## 按目标阅读

| 目标 | 阅读这里 |
| --- | --- |
| 本地试用 app | [README 快速开始](../README.zh-CN.md#快速开始) |
| 理解 app、CLI 和集成的关系 | [architecture.zh-CN.md](architecture.zh-CN.md) |
| 查看哪些行为被视为稳定契约 | [requirements.zh-CN.md](requirements.zh-CN.md) |
| 确认发版前验证 | [test-plan.zh-CN.md](test-plan.zh-CN.md) |
| 作为维护者从公开文档之下恢复当前执行队列 | [reference/codex-quota-peek/development-plan.zh-CN.md](reference/codex-quota-peek/development-plan.zh-CN.md) |
| 了解签名与公证缺口及后续硬化方向 | [signing-and-notarization-plan.zh-CN.md](signing-and-notarization-plan.zh-CN.md) |
| 准备发版 | [RELEASE.zh-CN.md](../RELEASE.zh-CN.md) |

## 公开文档范围

- `README*`：用户向概览、安装路径、核心能力和入口导航
- `docs/architecture*`：稳定系统结构和关键设计选择
- `docs/requirements*`：当前产品契约和 release-blocking regressions
- `docs/test-plan*`：验证策略和发版门禁
- `docs/signing-and-notarization-plan*`：可信 macOS 分发所需的发布硬化方案
- `docs/reference/codex-quota-peek/development-plan*`：位于公开文档之下、`.codex/plan.md` 之上的维护者执行队列
- `.codex/*`：维护者控制面，不属于公开产品文档
