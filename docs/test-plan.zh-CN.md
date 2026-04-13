# 测试计划

[English](test-plan.md) | [中文](test-plan.zh-CN.md)

## 范围与风险

- 范围：
  - realtime logs、archived sessions、API snapshot 的 quota 解析
  - 刷新优先级与 stale 结果拦截
  - 菜单契约、语言契约与 display-state rebuild 行为
  - CLI 可用性与基础命令路径
  - 发版门禁依赖的本地构建与打包脚本
- 主要风险：
  - 更新较旧或质量较低的数据覆盖了已接受的新快照
  - 菜单契约在不同语言或刷新模式下发生漂移
  - 打包或安装脚本与文档描述不再一致

## 验收用例
| 用例 | 前置条件 | 操作 | 预期结果 |
| --- | --- | --- | --- |
| realtime log 解析可用 | 提供 SQLite 导出的管道分隔 quota 行 | 通过 `CodexQuotaProvider` 解析 | 生成正确来源和剩余额度的快照 |
| 自动刷新在日志过旧时保留较新的 API 数据 | 已有较新的 API 快照，日志以更旧时间戳或更旧 reset window 到达 | 在 automatic 模式下计算优先结果 | API 快照继续被接受 |
| 自动刷新在日志追平后接受本地日志 | 本地日志比上一次 API 快照更新 | 在 automatic 模式下计算优先结果 | realtime log 快照替换较旧 API 快照 |
| display state rebuild 保持稳定 | 已存储 snapshot、账号与来源元数据 | 从缓存输入重建 presentation | badge 行、账号行和来源标签都保持正确 |
| 本地日志无效时可平稳回退 | 本地日志不可读，但 archived sessions 存在 | 加载 automatic refresh snapshot | 使用 archived session 数据，而不是硬失败 |
| CLI 构建后仍可用 | 构建 CLI | 运行 `codexQuotaPeek help` 和 `codexQuotaPeek accounts list` | 命令成功退出 |

## 自动化覆盖

- `./scripts/test.sh` 是主要回归入口
- 当前自动化覆盖包括：
  - realtime log 解析
  - API 与本地日志的 freshness 选择
  - stale snapshot 拦截
  - display-state rebuild 逻辑
  - archived session 回退行为
  - CLI 构建与基础 smoke 命令
- GitHub CI 工作流模板位于 [github-actions/ci.workflow.yml](github-actions/ci.workflow.yml)，与本地 build + test 行为保持一致

## 手工检查

1. 执行 `./scripts/install_app.sh`，再启动 `/Applications/CodexQuotaPeek.app`。
2. 确认菜单栏 badge 出现，且显示 `H / W` 信息，而不是空状态。
3. 打开菜单，确认账号行、额度行、节奏选择器、每日图、来源行和动作列表按预期顺序出现。
4. 执行 `Refresh Now (API)`，确认来源/更新时间会刷新，且不破坏菜单契约。
5. 切换应用语言，确认菜单契约在中英文下都与文档一致。
6. 执行 `./scripts/install_cli.sh`，再检查 `codexQuotaPeek status`、`codexQuotaPeek status --json` 和 `codexQuotaPeek accounts list`。
7. 如果验证发版打包，执行 `./scripts/prepare_release.sh`，确认 DMG、ZIP、release notes 和 GitHub draft 文件都能生成。

## 测试数据与夹具

- `Tests/TestRunner.swift` 使用确定性的内联 snapshot 和临时测试目录
- 回退与解析测试会在系统临时目录下创建临时 `.codex` fixtures
- 可选 live smoke 仍通过 `CODEX_QUOTA_PEEK_RUN_LIVE_SMOKE=1` 显式开启

## 发布门禁

- `./scripts/test.sh` 通过
- `./scripts/build_app.sh` 和 `./scripts/build_cli.sh` 成功
- 安装脚本与文档中的 quick-start 流程保持一致
- 菜单契约、语言契约和 freshness 行为仍与 [requirements.zh-CN.md](requirements.zh-CN.md) 一致
- 准备发版时，release packaging 产物可以成功生成
