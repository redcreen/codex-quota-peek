# 集成

[English](README.md) | [中文](README.zh-CN.md)

这个目录存放和 Codex Quota Peek 一起维护的一方集成。

## 当前可用集成

### OpenClaw 状态额度注入

路径：

- [openclaw-status-codex-quota](/Users/redcreen/project/codex%20limit/integrations/openclaw-status-codex-quota)

作用：

- 把 `codexQuotaPeek` 结果注入 `openclaw status`
- 当 quota 数据不可用时跳过注入
- 只在存在有效数据时为 JSON 输出增加 `codexQuota` 对象
- 保持较短的超时预算，避免 quota 查询阻塞状态输出

文档：

- [openclaw-status-codex-quota/README.zh-CN.md](/Users/redcreen/project/codex%20limit/integrations/openclaw-status-codex-quota/README.zh-CN.md)
