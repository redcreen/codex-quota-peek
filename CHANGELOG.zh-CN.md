# 变更记录

[English](CHANGELOG.md) | [中文](CHANGELOG.zh-CN.md)

所有值得记录的 `Codex Quota Peek` 变更都整理在这里。

## 0.1.0 - 2026-04-06

- 首个带 tag 的 GitHub 公开构建版本。
- README 重组为更清晰的中英文用户入口。
- 下拉菜单头部文案更新为 `Codex Quota Usage` / `Codex 用量`。
- 改进 quota 帮助交互，使解释面板在下一次点击前保持展开。

## 1.1.0 - 2026-04-04

- 新增 app 内 `English / 中文` 语言切换，默认跟随英文。
- 新增低额度、节奏预警和重置提醒的去重通知。
- 新增独立通知开关：低额度、节奏、重置提醒。
- 新增最近趋势 sparkline 和低点信息。
- 新增独立 `Preferences...` 窗口，覆盖显示、数据源策略、节奏、通知和 app 行为。
- 新增可配置数据源策略：`Auto`、`Prefer API`、`Prefer local logs`。
- 新增账号快照保存与本地账号切换支持。
- 新增 CLI，支持 `status`、`--refresh`、JSON 输出和账号快照命令。
- 新增解析、刷新策略、语言切换、趋势格式化和通知行为的回归测试。

## 1.0.0 - 2026-04-04

- 首个公开发布的 macOS 菜单栏 app 版本。
- 新增从 `~/.codex/logs_1.sqlite` 读取本地 Codex quota。
- 新增菜单栏 badge、下拉详情、手动刷新和 release 打包流程。
