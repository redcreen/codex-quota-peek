# Program Board

## Current Program Direction
- Direction: `formalize-refresh-scheduling-and-menu-open-freshness-boundary`
- Status: `active`
- Why Now: land one explicit refresh-scheduling boundary so manual API refresh, startup freshness checks, and menu-open API refresh stay consistent across `AppDelegate`, policy helpers, tests, and docs

## Program Orchestration Contract

- 程序编排必须引用 `.codex/strategy.md`、`.codex/plan.md`、`.codex/status.md` 和当前 durable 文档，而不是只凭聊天上下文。
- 程序编排层拥有多个 workstreams、切片、执行器输入和串并行边界；它不拥有业务方向变更。
- 任何跨到业务方向、兼容性承诺、外部定位或显著成本 / 时间边界的变化，必须继续升级给人类审批。
- program-board 必须让维护者一眼看出当前有哪些 active workstreams、哪些可并行、下一次调度点是什么。
- 重要的编排收口应写入 devlog，避免只留下结果而没有调度原因。

## Active Workstreams

| Workstream | Scope | State | Priority | Current Focus | Next Checkpoint |
| --- | --- | --- | --- | --- | --- |
| primary delivery line | 当前 active slice 与当前执行线 | active | P0 | 保持当前主线持续推进 | 到达下一个 checkpoint 并刷新真相 |
| control truth and docs alignment | plan / status / roadmap / development plan / docs | active | P1 | 保持控制面、文档与当前执行同步 | 避免恢复真相漂移 |
| validation and release gates | tests / gate / release-facing evidence | active | P1 | 保持验证入口与当前主线对齐 | 下一轮变更前保持为绿 |
| supporting backlog routing | 暂不进入主线但需要保留可见性的议题 | active | P2 | 记录但不无计划回流主线 | 只有证据充分时才升级 |

## Sequencing Queue

| Order | Workstream | Slice / Input | Executor | Status |
| --- | --- | --- | --- | --- |
| 1 | primary delivery line | 继续当前 active slice 与当前执行线 | delivery worker | active |
| 2 | control truth and docs alignment | 保持 plan / status / docs / handoff 同步 | docs-and-release | active |
| 3 | validation and release gates | 运行 tests / gate 并把结果写回真相 | delivery worker | active |
| 4 | supporting backlog routing | 判断哪些尾项回队列、哪些需要下轮主线 | PTL | next |

## Executor Inputs

| Executor | Current Input | Why It Exists | Status |
| --- | --- | --- | --- |
| PTL | `.codex/strategy.md` + `.codex/program-board.md` + `.codex/delivery-supervision.md` + `.codex/status.md` | 决定当前主线是否继续、重排或升级 | active |
| delivery worker | active slice + execution tasks + validator outputs | 推进当前 checkpoint 并保持与 program-board 对齐 | active |
| docs-and-release | README + roadmap + development-plan + gate outputs | 保持 durable docs、交接说明和门禁一致 | active |

## Parallel-Safe Boundaries

| Boundary | Parallel-Safe? | Notes |
| --- | --- | --- |
| 读文件 / 快照 / 校验 / 测试 | yes | 安全的只读动作可以和主写入线并行 |
| docs alignment vs control truth | yes | 文档更新可以跟随 control truth，但 `.codex/plan.md` / `.codex/status.md` 仍保持唯一真相源 |
| 同一批文件的双写入 | no | 共享写入面必须串行，不要并行改同一套控制面或主代码边界 |
| 战略变化 vs 业务方向变化 | no | 一旦跨到业务方向、兼容性或外部定位，就必须停下来给人类审批 |

## Supporting Backlog Routing

| Topic | Current Position | Re-entry Rule | Notes |
| --- | --- | --- | --- |
| maintainer-facing polish | supporting backlog | 只有明确降低接手成本时，才允许回流主线 | 保持在 backlog |
| doc-only tidy-up | supporting backlog | 只有不会干扰当前主线且能降低恢复成本时，才并入下个 checkpoint | 按 sidecar 处理 |
| future governance / architecture side-track | supporting backlog | 只有 durable 证据显示当前主线不够时，才升级 | 先记录，不抢主线 |

## Next Orchestration Checks
1. 确认当前 active slice、执行线和 supporting backlog 仍保持同一套排序真相。
2. 判断哪些 sidecar 工作可以并入下个 checkpoint，哪些必须继续留在队列里。
3. 如果单 Codex PTL 模式在真实仓库里成为瓶颈，再整理成后续多执行器候选。
