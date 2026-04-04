# Codex Quota Peek

[中文](#中文说明) | [English](#english)

A lightweight macOS menu bar app for checking the latest Codex quota usage at a glance.

## 中文说明

### 项目简介

`Codex Quota Peek` 是一个 macOS 状态栏小工具，用来显示 Codex 当前剩余额度。

它会在菜单栏中显示两行简洁信息：

- `H xx%`：主额度窗口剩余百分比
- `W xx%`：周额度窗口剩余百分比
- 超平均使用时会追加 `!` 或 `!!`

点开菜单后，还可以看到更完整的信息：

- 额度窗口时长
- 当前剩余百分比
- 对应重置时间
- 最近更新时间
- 当前账号与套餐
- 节奏提醒、快捷入口和偏好设置

### 语言说明

目前应用界面默认使用英文。

- 这份 README 同时提供中文和英文说明
- GitHub 页面可直接通过顶部链接切换阅读语言
- 如果后续你需要，我也可以把应用菜单本身做成中英文切换版本

### 解决的问题

这个工具主要解决几个实际问题：

- 不需要反复进入 Codex 才能看额度
- 不需要手动翻日志或数据库
- 可以在菜单栏里持续看到最新剩余额度
- 可以快速判断当前还能不能继续高频使用
- 可以更早发现“虽然额度还够，但当前消耗速度已经偏快”

### 使用方法

#### 环境要求

- 目前只支持 macOS
- 菜单栏 app 最低要求：macOS 13.0+
- CLI 目前同样只在 macOS 上验证和支持
- 需要本机已安装并使用过 Codex，且存在 `~/.codex` 目录
- CLI 会安装到当前 PATH 中可写的目录，例如 `/opt/homebrew/bin` 或 `~/.local/bin`

#### 直接下载使用

1. 在仓库中下载 `release/CodexQuotaPeek-mac.zip`
2. 解压后得到 `CodexQuotaPeek.app`
3. 双击打开即可使用
4. 应用启动后会常驻在 macOS 状态栏

如果 macOS 提示安全限制，可以在“系统设置 -> 隐私与安全性”里允许打开。

#### 当前功能

- 状态栏显示 `H / W` 两个额度窗口
- 绿色 / 黄色 / 红色额度提示
- 超平均使用时显示 `! / !!`
- 低额度和新出现的节奏告警支持 macOS 通知
- 下拉菜单显示账号、套餐、重置时间、`Last updated`
- `Refresh Now` 刷新后自动保持菜单交互连续
- 已保存登录快照的账号可在菜单里直接切换
- 独立 `Preferences...` 窗口，可配置显示项、weekly `!` 规则和启动行为
- `Launch at Login`
- `Open Codex Folder`
- `Reveal Logs Database`
- `codexQuotaPeek` CLI：查看额度、输出 JSON、保存和切换账号快照

CLI 示例：

```bash
codexQuotaPeek status
codexQuotaPeek status --api
codexQuotaPeek status --refresh --json
codexQuotaPeek accounts list
```

集成：

- OpenClaw `status` 注入插件位于 [integrations/openclaw-status-codex-quota](/Users/redcreen/Project/codex%20limit/integrations/openclaw-status-codex-quota)
- 使用说明见 [integrations/openclaw-status-codex-quota/README.md](/Users/redcreen/Project/codex%20limit/integrations/openclaw-status-codex-quota/README.md)

#### 从源码构建

```bash
./scripts/build_app.sh
./scripts/build_cli.sh
./scripts/package_release.sh
./scripts/prepare_release.sh
```

运行回归测试：

```bash
./scripts/test.sh
```

GitHub Actions 会在 `push` 和 `pull request` 时自动执行：

```bash
./scripts/test.sh
./scripts/build_app.sh
./scripts/build_cli.sh
./scripts/package_release.sh
```

如果你当前机器的 GitHub token 还没有 `workflow` scope，可以先使用仓库里的模板：

- `docs/github-actions/ci.workflow.yml`

之后再把它复制到：

- `.github/workflows/ci.yml`

安装 CLI：

```bash
./scripts/install_cli.sh
codexQuotaPeek help
```

构建完成后可直接运行：

```bash
open "dist/CodexQuotaPeek.app"
```

### 工作原理

应用的工作方式很直接：

1. 启动时立即读取一次本机 Codex 额度数据
2. 监听本地 Codex 日志与认证文件变化，尽量即时刷新
3. 同时保留固定间隔自动刷新作为兜底
4. 优先读取 `~/.codex/logs_1.sqlite` 中最新的实时 `codex.rate_limits` 事件
5. 如果实时数据暂时不可用，再回退读取 `~/.codex/archived_sessions/*.jsonl`
6. 将结果渲染成菜单栏 badge 和下拉菜单

当前版本默认保留 `20` 秒自动刷新兜底，并且会监听：

- `~/.codex/logs_1.sqlite`
- `~/.codex/auth.json`

菜单中也支持手动 `Refresh Now`。

### 已知限制

当前版本优先读取本机可见的持久化额度数据：

- `~/.codex/logs_1.sqlite`
- `~/.codex/archived_sessions/*.jsonl`

这意味着它通常已经足够实用，但仍有一个现实边界：

- 官方 Codex 面板有时会比本工具更早显示新额度
- 当前版本并不是直接请求官方内部实时额度接口
- 它主要是在追本地日志里的最新额度事件

我们已经排查过这些候选本地来源：

- `~/.codex/state_5.sqlite`
- `~/Library/Application Support/com.openai.chat`
- `~/Library/Application Support/Codex`

到目前为止，还没有发现一个比 `logs_1.sqlite` 更明确、稳定、可直接复用的本地 quota 持久化来源。

### 进一步调研

为了确认为什么官方 UI 有时更快，我们继续检查了：

- `/Applications/Codex.app/Contents/Resources/app.asar`

在其中可以搜到和额度状态相关的前端代码线索，例如：

- `queryKey: ['rate-limit-status']`
- `safeGet(...)`
- `refetchOnWindowFocus`
- `refetchInterval: ONE_MINUTE`

从这些线索可以合理推断：

- 官方桌面端并不只是依赖本地 `logs_1.sqlite`
- 它很可能还有一条更直接的额度状态请求链路

所以当前 `Codex Quota Peek` 更准确的定位是：

- 一个基于本地 Codex 日志的轻量额度观察工具
- 不是官方内部实时 quota API 的完整替代

### Roadmap

为了把这个项目继续做成一个可以持续发展的产品，当前 roadmap 是：

1. 产品化设置体验
   已完成第一步：从菜单层级设置升级成独立 `Preferences...` 窗口。后续新的高级设置也会优先放到这里。

   当前已记录的体验问题：
   `Preferences...` 窗口的排版仍然不够成熟，信息密度、留白和区块对齐需要重做。

2. 数据源策略可配置
   计划增加 `Auto / Prefer API / Prefer local logs` 这样的策略，让用户更清楚当前值为什么来自这个来源。

3. 历史趋势与节奏分析
   已完成当前阶段：除了最近趋势和近期低点，现在也会显示低点出现的大致时间，用来判断危险值是刚发生还是较早前出现。

4. 主动通知
   已完成当前阶段：低额度、新出现的 `! / !!` 节奏告警，以及窗口即将重置时，都会触发去重后的 macOS 通知；而且这些通知类型现在可以分别开关配置。

5. 应用语言切换
   已完成第一步：应用内已经支持 `English / 中文` 切换，默认英文。菜单、偏好设置和主要提示文案会跟随切换。CLI 目前仍默认英文。

6. 发布与工程化
   已完成第一步：仓库现在带有 GitHub Actions，会自动跑测试、构建 app/CLI，并生成 zip 发布包 artifact。后续继续完善版本管理、Release 和 changelog。

### 制作过程

这个项目从零开始搭建，核心过程大致是：

1. 确认 Codex 本地确实会记录额度信息
2. 找到真实可用的数据源和字段格式
3. 用原生 `AppKit` 做菜单栏应用，而不是依赖更重的桌面框架
4. 先实现双行 badge，再补充更丰富的下拉菜单
5. 修复旧快照误匹配、解析失败回退等问题
6. 逐步修正状态栏实例、菜单打不开、刷新不及时等交互问题
7. 补上颜色规则、节奏提醒、更新时间、登录启动和偏好设置
8. 增加回归测试，覆盖日志解析、刷新策略和展示规则
9. 为本机已登录账号保存认证快照，支持菜单内直接切换
10. 最后补上可直接分发的 `.app` 和 `.zip`

#### 关键输入模板

下面这组输入是本项目真正起作用的核心需求。别人如果想用 Codex 复现一个完整版本，可以直接参考这种表达方式：

1. 产品目标  
   帮我做一个 mac 的状态栏工具，显示 Codex 的限额；每分钟更新一次；像参考图那样展示。

2. 交互反馈  
   现在的问题是显示还是空值。  
   目前显示还是不对。  
   状态栏显示还是 88，但是实际是 86。

3. 命名要求  
   项目名字需要改一下，帮我想个名字，然后帮我改掉。  
   名字改成 `Codex Quota Peek`。

4. 发布要求  
   帮我发到我的 GitHub 上，需要自动创建 repo，public。  
   检查下代码里，不要有我的私人信息。  
   把它做成一个可以下载直接使用的 app，然后把 app 发布到 GitHub 上。

5. 文档要求  
   使用说明补一下；用中英文；可以切换语言的说明；解决问题；使用方法；工作原理；制作过程。

6. 菜单细化要求  
   需要图标后，把时间给出来。  
   菜单里显示窗口时长、剩余额度、重置时间。

#### 为什么这组输入有效

这组输入之所以能驱动 Codex 做出完整成品，是因为它覆盖了一个真实产品从头到尾最关键的五部分：

- 目标：做什么
- 样式：长什么样
- 反馈：哪里不对
- 发布：怎么交付
- 文档：怎么让别人看懂和使用

如果只给“帮我做一个状态栏工具”，通常只能得到一个初版 demo。  
但如果把上面这些输入逐步补齐，Codex 就能继续把项目推进到：

- 可运行
- 可调试
- 可修 bug
- 可重命名
- 可打包
- 可发布
- 可文档化

### 仓库内容

- `Sources/`：Swift 源码
- `scripts/build_app.sh`：构建 `.app`
- `scripts/test.sh`：运行回归测试
- `scripts/package_release.sh`：打包 zip 发布文件
- `scripts/generate_release_notes.sh`：从 `CHANGELOG.md` 生成当前版本的发布说明
- `scripts/prepare_release.sh`：一键执行测试、构建、打包并生成 GitHub Release 草稿
- `VERSION`：当前应用版本号
- `CHANGELOG.md`：版本变更记录
- `RELEASE.md`：正式发布步骤说明
- `docs/github-actions/ci.workflow.yml`：可复制到 GitHub 的 Actions workflow 模板
- `release/CodexQuotaPeek-mac.zip`：可直接下载使用的应用压缩包
- `release/GITHUB_RELEASE_DRAFT.md`：可直接粘贴到 GitHub Release 的发布草稿

---

## English

### Overview

`Codex Quota Peek` is a small macOS menu bar utility for monitoring your Codex quota in real time.

It shows two compact lines in the menu bar:

- `H xx%`: remaining percentage for the primary quota window
- `W xx%`: remaining percentage for the weekly quota window
- `! / !!`: usage pace is above the current window average

When you open the dropdown menu, it also shows:

- window duration
- remaining percentage
- reset time
- last updated time
- account and plan
- pace alerts, shortcuts, and preferences

### Language Notes

The app UI currently uses English by default.

- This README includes both Chinese and English
- You can switch reading language using the links at the top of the page
- If needed later, the app menu itself can also be turned into a bilingual UI

### Problems It Solves

This app is built to solve a few practical issues:

- You do not need to open Codex repeatedly just to check quota
- You do not need to inspect local logs or databases manually
- You can keep a live quota indicator in the macOS menu bar
- You can quickly judge whether you still have enough quota for heavy usage
- You can spot when your current consumption pace is ahead of the average window pace

### How To Use

#### Requirements

- Currently supports macOS only
- Minimum version for the menu bar app: macOS 13.0+
- The CLI is also currently tested and supported on macOS only
- Requires a local Codex setup with an existing `~/.codex` directory
- The CLI installs into a writable directory already in your PATH, such as `/opt/homebrew/bin` or `~/.local/bin`

#### Download and use directly

1. Download `release/CodexQuotaPeek-mac.zip` from this repository
2. Unzip it to get `CodexQuotaPeek.app`
3. Open the app
4. It will stay in the macOS menu bar

If macOS blocks the app the first time, allow it from `System Settings -> Privacy & Security`.

#### Current Features

- `H / W` quota windows in the menu bar
- green / yellow / red quota coloring
- `! / !!` pace markers when usage is ahead of average
- macOS notifications for new low-quota and pace-warning states
- dropdown details for account, plan, reset time, and `Last updated`
- `Refresh Now` keeps the interaction flow smooth
- standalone `Preferences...` window for display settings, weekly `!` behavior, and launch options
- `Launch at Login`
- `Open Codex Folder`
- `Reveal Logs Database`

#### Integrations

- OpenClaw `status` injection plugin lives in [integrations/openclaw-status-codex-quota](/Users/redcreen/Project/codex%20limit/integrations/openclaw-status-codex-quota)
- Plugin docs are in [integrations/openclaw-status-codex-quota/README.md](/Users/redcreen/Project/codex%20limit/integrations/openclaw-status-codex-quota/README.md)

#### Build from source

```bash
./scripts/build_app.sh
./scripts/build_cli.sh
./scripts/package_release.sh
./scripts/prepare_release.sh
```

Run regression tests with:

```bash
./scripts/test.sh
```

GitHub Actions automatically runs the same pipeline on every `push` and `pull request`:

```bash
./scripts/test.sh
./scripts/build_app.sh
./scripts/build_cli.sh
./scripts/package_release.sh
```

If your current GitHub token does not have the `workflow` scope yet, use the repo template first:

- `docs/github-actions/ci.workflow.yml`

Then copy it into:

- `.github/workflows/ci.yml`

Run the built app with:

```bash
open "dist/CodexQuotaPeek.app"
```

### How It Works

The app works like this:

1. It loads Codex quota data immediately at launch
2. It watches local Codex files for changes and refreshes as quickly as possible
3. It also keeps a fixed-interval refresh as a fallback
4. It first reads the latest realtime `codex.rate_limits` events from `~/.codex/logs_1.sqlite`
5. If realtime data is unavailable, it falls back to `~/.codex/archived_sessions/*.jsonl`
6. It renders the result into the menu bar badge and dropdown menu

The current version keeps a `20s` fallback timer and also watches:

- `~/.codex/logs_1.sqlite`
- `~/.codex/auth.json`

It also includes a manual `Refresh Now` action.

### Known Limitation

The current version primarily reads quota information from locally persisted sources:

- `~/.codex/logs_1.sqlite`
- `~/.codex/archived_sessions/*.jsonl`

That keeps the app lightweight and local-first, but it also means:

- the official Codex quota panel may show new values earlier
- this app is not directly calling the same internal realtime quota endpoint
- it mainly follows the latest local quota events written to disk

We investigated several likely local sources as well:

- `~/.codex/state_5.sqlite`
- `~/Library/Application Support/com.openai.chat`
- `~/Library/Application Support/Codex`

So far, we have not found a clearer, stable, directly reusable local persisted quota source beyond `logs_1.sqlite`.

### Further Investigation

To understand why the official UI can sometimes refresh faster, we also inspected:

- `/Applications/Codex.app/Contents/Resources/app.asar`

Inside the bundled frontend code, we found quota-related hints such as:

- `queryKey: ['rate-limit-status']`
- `safeGet(...)`
- `refetchOnWindowFocus`
- `refetchInterval: ONE_MINUTE`

This strongly suggests the official desktop app is not relying only on local quota logs and likely has a more direct quota-status request path.

So the current positioning of `Codex Quota Peek` is:

- a lightweight quota observer built on top of local Codex log events
- not a full replacement for the official internal realtime quota path

### Roadmap

To grow this project into a more sustainable product, the current roadmap is:

1. Product-grade settings
   The first step is already done: settings now live in a standalone `Preferences...` window instead of a stacked submenu. Future advanced controls will go there too.

   Recorded UX issue:
   the current `Preferences...` layout still needs a real design pass. Spacing, grouping, and section alignment are not polished enough yet.

2. Configurable source strategy
   Planned options include `Auto`, `Prefer API`, and `Prefer local logs` so users can choose the balance between freshness and local stability.

3. History and pacing analysis
   The current stage is done: besides recent trends and low-water marks, the app now also shows roughly when each low happened so you can tell whether the risky point was recent or historical.

4. Proactive notifications
   The current stage is done: low remaining quota, newly triggered `! / !!` pace warnings, and upcoming reset windows can now send deduplicated macOS notifications, and each notification category can be toggled independently.

5. App language switching
   The first step is now done: the app includes an in-app `English / 中文` toggle with English as the default. The menu, preferences window, and core status copy now follow the selected language. The CLI still stays in English for now.

6. Release and engineering polish
   The first step is now done: the repo includes GitHub Actions that run tests, build the app and CLI, and package the release zip as an artifact. Versioning, Releases, and changelogs can come next.

### Build Process

This project was built from scratch. The main steps were:

1. Verify that Codex actually stores quota information locally
2. Identify the correct local data source and payload format
3. Build a native menu bar app with `AppKit`
4. Start with the compact two-line badge
5. Add the richer dropdown menu with percentage and reset time
6. Fix stale snapshot matching, parsing edge cases, and duplicate menu bar instances
7. Refine menu interaction, refresh behavior, and real-time file watching
8. Add color rules, pace alerts, login launch, quick actions, and preferences
9. Package the final `.app` and distributable `.zip`

#### Key Prompt Inputs

The following inputs were the most important prompts used to drive this project to a complete result. If someone wants to recreate a similar full app with Codex, this structure is a strong starting point:

1. Product goal  
   Build a macOS menu bar utility that shows Codex quota limits, refreshes automatically, and follows a visual reference.

2. Iterative bug feedback  
   The app still shows empty values.  
   The display is still incorrect.  
   The menu bar shows 88, but the real value is 86.

3. Naming direction  
   Suggest a better project name and rename the app.  
   Final name: `Codex Quota Peek`.

4. Publishing requirements  
   Publish it to GitHub as a public repository.  
   Check that the code does not contain private information.  
   Package it as a directly downloadable app.

5. Documentation requirements  
   Add bilingual usage docs.  
   Include language switching notes, solved problems, usage, working principle, and build process.

6. Menu refinement  
   Add an icon and show time information in the dropdown.  
   Show window duration, remaining quota, and reset time.

#### Why These Inputs Work

These prompts work well because they cover the full lifecycle of a real product instead of only the first coding step:

- goal
- visual expectation
- bug feedback
- release requirements
- documentation requirements

If you only ask for “a menu bar app,” Codex will usually produce an initial prototype.  
If you keep adding the kinds of inputs above, it can continue all the way through:

- implementation
- debugging
- renaming
- packaging
- publishing
- documentation

### Repository Contents

- `Sources/`: Swift source code
- `scripts/build_app.sh`: builds the `.app`
- `scripts/generate_release_notes.sh`: generates release notes from `CHANGELOG.md`
- `scripts/package_release.sh`: packages the zip release
- `scripts/prepare_release.sh`: runs the full release prep pipeline and writes a GitHub Release draft
- `VERSION`: current app version
- `CHANGELOG.md`: release history
- `RELEASE.md`: release process and checklist
- `docs/github-actions/ci.workflow.yml`: ready-to-copy GitHub Actions workflow template
- `release/CodexQuotaPeek-mac.zip`: ready-to-download app archive
- `release/GITHUB_RELEASE_DRAFT.md`: ready-to-paste GitHub Release draft
