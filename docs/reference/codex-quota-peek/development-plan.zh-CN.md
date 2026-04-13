# Codex Quota Peek 开发计划

[English](development-plan.md) | [中文](development-plan.zh-CN.md)

## 目的

这份文档是给维护者看的 durable 执行队列，位置在公开文档之下、[`.codex/plan.md`](../../../.codex/plan.md) 之上。

它回答的是：

`维护者该从哪里恢复、当前主线切片是什么、产品和发布后续该按什么顺序推进。`

## 相关文档

- [../../../README.zh-CN.md](../../../README.zh-CN.md)
- [../../README.zh-CN.md](../../README.zh-CN.md)
- [../../architecture.zh-CN.md](../../architecture.zh-CN.md)
- [../../requirements.zh-CN.md](../../requirements.zh-CN.md)
- [../../test-plan.zh-CN.md](../../test-plan.zh-CN.md)
- [../../../RELEASE.zh-CN.md](../../../RELEASE.zh-CN.md)

## 怎么使用这份计划

1. 如果先需要产品上下文，先看 [docs/README.zh-CN.md](../../README.zh-CN.md) 和 [requirements.zh-CN.md](../../requirements.zh-CN.md)。
2. 再看这里的“当前位置”和“顺序执行队列”，确认维护者下一条主线应该从哪里开始。
3. 只有在需要实时执行细节时，才下钻到 [`.codex/status.md`](../../../.codex/status.md) 和 [`.codex/plan.md`](../../../.codex/plan.md)。
4. 这个仓库当前还不需要独立的 `docs/roadmap.md`；在工作真正分裂成多条命名里程碑之前，把这份文档当成 durable 的里程碑队列。

## 当前位置

| 项目 | 当前值 | 说明 |
| --- | --- | --- |
| 当前阶段 | `refresh-scheduling hardening active; docs baseline already aligned` | 仓库已经离开模板态 retrofit，当前进入一条明确的 active 代码主线 |
| 当前切片 | `formalize-refresh-scheduling-and-menu-open-freshness-boundary` | 下一条主线要把手动刷新、启动 API 刷新、自动刷新和菜单打开 freshness 收到同一个命名策略边界里 |
| 当前执行线 | 把 `RefreshSchedulingPolicy`、`QuotaRefreshPolicy`、`AppDelegate`、测试和 requirements / test-plan 文档收成一条明确的 refresh-scheduling 边界 | 这条线应该作为一个 checkpoint 收口，而不是继续拆成很多零散 follow-up tweak |
| 当前验证 | `project assistant continue`、`validate_control_surface_quality.py`、`validate_docs_system.py` 和 `./scripts/test.sh` | 维护者现在已经可以从 durable 真相恢复，并把下一条主线绑到真实验证上 |

## 阶段总览

| 里程碑 | 状态 | 目标 | 依赖 | 退出条件 |
| --- | --- | --- | --- | --- |
| M1 | done | 建立菜单栏 app、本地 CLI 和一方集成共享的产品基线 | app / CLI / integration 核心代码 | app、CLI 和集成共享同一套 quota 语义 |
| M2 | done | 收口双语文档基线和维护者恢复面 | 公开文档、`.codex/*`、development-plan 文档 | 维护者不再从模板态控制面恢复项目 |
| M3 | active | 正式收口 refresh scheduling 和菜单打开 freshness 边界 | `RefreshSchedulingPolicy`、`QuotaRefreshPolicy`、`AppDelegate`、`Tests/TestRunner.swift` | 一条策略边界拥有这套行为，测试保持绿色 |
| M4 | next | 在 M3 关闭后确定下一条命名里程碑 | 已验证的 M3 行为、release 文档、签名方案、integration 文档 | 仓库拥有一条明确的 post-M3 主线，而不是继续漂在零散 follow-up 里 |
| M5 | later | 加深发布硬化和可信 macOS 分发能力 | 版本化 release 流程、签名 / notarization 决策 | 公开发布路径不再只依赖未签名的本地安装 |

## 顺序执行队列

| 顺序 | 切片 | 当前状态 | 目标 | 验证 |
| --- | --- | --- | --- | --- |
| 1 | `close-durable-doc-baseline-and-maintainer-resume-surface` | 已完成 | 让仓库摆脱模板态控制面，并给未来维护者建立 durable 的 development-plan 入口 | `project assistant continue`、`validate_control_surface_quality.py` 和 `validate_docs_system.py` 都更像维护者恢复面板 |
| 2 | `formalize-refresh-scheduling-and-menu-open-freshness-boundary` | 当前主线 | 把手动 API 刷新、启动 API 刷新、自动刷新和菜单打开 freshness 收到同一个明确策略边界里 | `./scripts/test.sh` 以及 requirements / test-plan 里的 refresh 约束保持一致 |
| 3 | `expand-refresh-path-tests-and-docs-from-validated-behavior` | M3 内排队 | 从已验证的 refresh 行为回写 requirements、test-plan 和 release-facing 文档，而不是让文档落后于代码 | requirements 和 test-plan 解释的是测试真正覆盖的行为 |
| 4 | `choose-post-refresh-named-milestone` | 下一步 | 决定 refresh slice 之后，是 release hardening 还是更宽的 integration follow-on 成为下一条命名主线 | `.codex/status.md`、这份计划和 Next 3 Actions 指向同一条下一里程碑 |
| 5 | `release-hardening-and-trusted-distribution` | 更后面 | 把当前签名 / notarization 说明变成可执行的发布硬化切片 | release 文档、脚本和 macOS 信任链预期收敛到一起 |
| 6 | `broaden-first-party-integrations-after-the-baseline-stays-stable` | 更后面 | 只在 refresh 和 release 基线稳定后，再扩一方集成深度 | 新集成复用稳定的 quota 语义，而不是追着变化跑 |
