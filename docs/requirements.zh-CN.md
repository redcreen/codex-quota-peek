# 需求基线

[English](requirements.md) | [中文](requirements.zh-CN.md)

这份文档把当前产品行为整理成稳定需求基线，避免后续变更只靠记忆判断是否回归。

## 1. 产品目标

Codex Quota Peek 是一个面向 macOS 的 Codex quota 伴随工具。

它应该让用户能够：

- 在菜单栏里快速看到当前 `5h` 和 `7d` quota
- 不重新打开 Codex，也能理解重置时间、剩余额度和使用节奏
- 在需要时手动触发一次最新 API 刷新
- 在 CLI 和集成中复用同一套 quota 数据与语义

## 2. 支持的产品表面

当前支持三种表面：

1. macOS 菜单栏 app
2. 本地 CLI：`codexQuotaPeek`
3. `integrations/` 下的一方集成

菜单栏 app 是主体验，CLI 和集成应尽量共享同一套 quota 语义。

## 3. 核心用户需求

### R1. 快速可见的 quota

- 菜单栏 badge 必须显示 `H` 和 `W` 剩余额度
- 下拉菜单必须显示 `5h` 和 `7d` 两行额度
- 每行必须包含：
  - 标签
  - 可视化条
  - 重置文本
  - 剩余百分比

### R2. 新鲜度与来源行为

- 如果本地有数据，启动时不能让 badge 为空
- 启动后应在初始本地显示之后触发后台 API 刷新
- 手动 `Refresh Now (API)` 必须优先官方 API
- 当当前显示来自本地日志，或 API 快照已经过旧时，打开菜单应触发 API 刷新
- 后台刷新失败时，不得把一个有效显示状态替换成 `--` 或 `Source: unavailable`

### R3. 数据源策略

支持的数据源策略：

- `Auto`
- `Prefer API`
- `Prefer local logs`

规则：

- 手动刷新始终 API 优先
- 启动刷新必须保持 API-first，以保证新鲜度
- 自动刷新可以按用户所选策略变化

### R4. Quota 语义

- `% left` 始终表示当前快照中的真实剩余额度
- `! / !! / !!!` 表示节奏风险，而不是单纯的低额度
- 节奏标记不能改变真实的剩余百分比

### R5. 每周工作量预设

必须保留以下每周节奏预设：

- `40h`
- `56h`
- `70h`

它们会影响：

- 每周节奏严重度
- 每周解释文本
- 每周标记计算
- 每日图解释方式

但不会改变真实的 `7d` 剩余百分比。

### R6. 菜单结构

下拉菜单必须保持稳定顺序：

1. 标题
2. 账号行
3. `5h` 行
4. `7d` 行
5. 每周工作量选择器
6. 每周解释
7. credits
8. 每日用量
9. 更新时间 / 来源行
10. 动作区

必须保留的核心动作：

- `Refresh Now (API)`
- `Switch Account...`
- `Usage Dashboard`
- `Status Page`
- `Copy Details`
- `Open Codex Folder`
- `Reveal Logs Database`
- `Preferences...`
- `About Codex Quota Peek`
- `Quit`

### R7. 语言行为

- app 必须支持英文和中文
- 首次启动默认跟随 macOS 系统语言
- 一旦显式切换，所选语言必须持久化
- 核心菜单结构必须在中英文下都保持稳定

### R8. 账号显示

- 下拉菜单必须用一行紧凑格式显示当前账号
- 预期格式：
  - 英文：`Account <value> (<plan>)`
  - 中文：`账号 <value> (<plan>)`

### R9. 每日用量图

- 图表必须始终渲染完整七天
- 需要包括：
  - 标题
  - y 轴
  - x 轴基线
  - 日期标签
  - 柱状图字符

### R10. 通知

通知类别必须可独立配置：

- 低额度
- 节奏预警
- 重置提醒

要求：

- 重复通知必须抑制
- 关闭某一类，只影响该类

### R11. CLI 行为

CLI 必须支持：

- `codexQuotaPeek`
- `codexQuotaPeek status`
- `codexQuotaPeek status --refresh`
- `codexQuotaPeek status --json`
- `codexQuotaPeek accounts list`
- `codexQuotaPeek accounts save`
- `codexQuotaPeek accounts switch ...`

## 4. 非功能需求

### N1. 稳定性优先于新奇

- 自动刷新不能因为瞬时失败就清空有效 quota 状态
- 较旧或 stale 的快照不能覆盖较新的已接受结果
- UI 回归需要通过测试保护，而不是只靠人工观察

### N2. 可重复测试

- 默认测试运行不能依赖不稳定的线上 Codex 数据
- 逻辑与契约测试必须能在干净本地环境里跑通
- 可选 live smoke 必须显式开启，而不是隐式依赖

### N3. 菜单契约保护

菜单结构、语言标签或关键动作的变化，必须在发布前被测试捕获。

## 5. 当前验收基线

以下都属于 release-blocking regressions：

- `5h` 或 `7d` 行消失
- 每周选择器消失
- 标题或账号行消失
- 来源 / 更新时间行异常消失
- 启动或菜单打开时的 API freshness 路径悄悄失效
- 自动刷新失败会清空一个有效显示状态
- 中英文菜单标签偏离预期契约

## 6. 当前测试覆盖图

### 逻辑 / 策略

- realtime log 解析
- API 与 logs 的 freshness 选择
- 启动 / 菜单打开的刷新策略
- stale snapshot 拦截
- 自动刷新失败后的保留行为
- 每周节奏严重度
- marker 计算
- 通知去重

### 呈现 / 契约

- badge 行格式
- `5h / 7d` 标签
- 账号行格式
- 每周选择器选项
- 中英文动作标题
- 更新时间 / 来源可见性规则
