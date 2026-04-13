# Status Codex Quota

[English](README.md) | [中文](README.zh-CN.md)

`status-codex-quota` 是一个 OpenClaw 插件，用来把 `codexQuotaPeek` 的结果追加到 OpenClaw 状态输出里。

设计上坚持三条规则：

- quota CLI 必须带短超时
- 只有拿到有效 quota 结果时才做注入
- quota 查询绝不能长期阻塞原始状态输出

## 作用

- 为 plain-text `openclaw status` 追加 `Codex Quota` 区块
- 通过插件命令路径接管 `/status`，并在可用时追加同样的 quota 区块
- 在存在有效 quota JSON 时，给 `--json` 输出增加顶层 `codexQuota` 对象
- 当 `codexQuotaPeek` 超时、报错或返回不可用数据时，完全跳过注入

## 安装

从仓库根目录安装：

```bash
cd integrations/openclaw-status-codex-quota
./scripts/install.sh
```

或直接在当前目录安装：

```bash
./scripts/install.sh
```

手动安装：

```bash
openclaw plugins install -l .
openclaw plugins enable status-codex-quota
```

验证：

```bash
openclaw plugins list
openclaw status
openclaw status --json
```

示例 plain-text 注入结果：

```text
Codex Quota · 67560691@qq.com · Pro
- 5 hours: H 73% · reset 20:23
- 7 days: W 86%! · reset Apr 11
- updated just updated · source API
```

## 默认行为

- 基础状态命令：`openclaw`
- quota 命令：`codexQuotaPeek`
- quota 超时：`600ms`
- slash override：启用
- CLI 文本注入：启用

## 配置

`~/.openclaw/openclaw.json` 示例：

```json5
{
  plugins: {
    allow: ["status-codex-quota"],
    load: {
      paths: ["/ABSOLUTE/PATH/TO/status-codex-quota"]
    },
    entries: {
      "status-codex-quota": {
        enabled: true,
        config: {
          quotaTimeoutMs: 600,
          cliInject: true,
          slashOverride: true
        }
      }
    }
  }
}
```

## 测试

```bash
npm test
```

## 脚本

```bash
./scripts/install.sh
./scripts/uninstall.sh
```
