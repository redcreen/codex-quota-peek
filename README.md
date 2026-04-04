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
- 下拉菜单显示账号、套餐、重置时间、`Last updated`
- `Refresh Now` 刷新后自动保持菜单交互连续
- `Preferences` 子菜单，可开关颜色、节奏提醒、更新时间
- `Launch at Login`
- `Open Codex Folder`
- `Reveal Logs Database`

#### 从源码构建

```bash
./scripts/build_app.sh
./scripts/package_release.sh
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

当前版本默认保留 `5` 秒自动刷新兜底，并且会监听：

- `~/.codex/logs_1.sqlite`
- `~/.codex/auth.json`

菜单中也支持手动 `Refresh Now`。

### 制作过程

这个项目从零开始搭建，核心过程大致是：

1. 确认 Codex 本地确实会记录额度信息
2. 找到真实可用的数据源和字段格式
3. 用原生 `AppKit` 做菜单栏应用，而不是依赖更重的桌面框架
4. 先实现双行 badge，再补充更丰富的下拉菜单
5. 修复旧快照误匹配、解析失败回退等问题
6. 逐步修正状态栏实例、菜单打不开、刷新不及时等交互问题
7. 补上颜色规则、节奏提醒、更新时间、登录启动和偏好设置
8. 最后补上可直接分发的 `.app` 和 `.zip`

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
- `scripts/package_release.sh`：打包 zip 发布文件
- `release/CodexQuotaPeek-mac.zip`：可直接下载使用的应用压缩包

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
- dropdown details for account, plan, reset time, and `Last updated`
- `Refresh Now` keeps the interaction flow smooth
- `Preferences` submenu for colors, pace alerts, and updated-time visibility
- `Launch at Login`
- `Open Codex Folder`
- `Reveal Logs Database`

#### Build from source

```bash
./scripts/build_app.sh
./scripts/package_release.sh
```

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

The current version keeps a `5s` fallback timer and also watches:

- `~/.codex/logs_1.sqlite`
- `~/.codex/auth.json`

It also includes a manual `Refresh Now` action.

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
- `scripts/package_release.sh`: packages the zip release
- `release/CodexQuotaPeek-mac.zip`: ready-to-download app archive
