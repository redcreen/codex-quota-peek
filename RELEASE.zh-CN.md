# 发布指南

[English](RELEASE.md) | [中文](RELEASE.zh-CN.md)

这个项目会产出 macOS app bundle、本地 CLI、带版本号的 DMG、带版本号的 ZIP，以及生成的 release notes。

## 本地发版步骤

1. 更新 `VERSION`
2. 在 `CHANGELOG.md` 顶部新增一个版本段落
3. 执行：

```bash
./scripts/prepare_release.sh
```

4. 检查生成的文件：

- `release/CodexQuotaPeek-mac.zip`
- `release/CodexQuotaPeek-<version>.dmg`
- `release/CodexQuotaPeek-<version>.zip`
- `release/RELEASE_NOTES.md`
- `release/GITHUB_RELEASE_DRAFT.md`

5. 提交并推送版本号与 changelog 变更
6. 创建或更新 GitHub Release，粘贴 `release/GITHUB_RELEASE_DRAFT.md`，并上传 ZIP/DMG 产物

## 签名状态

当前公开构建还没有完成 Apple 签名和 notarization。

后续方案见：

- [docs/signing-and-notarization-plan.zh-CN.md](/Users/redcreen/project/codex%20limit/docs/signing-and-notarization-plan.zh-CN.md)

## GitHub Actions 说明

仓库里已经包含一份可直接复制的 workflow 模板：

- `docs/github-actions/ci.workflow.yml`

要在 GitHub 上启用，把它复制到：

- `.github/workflows/ci.yml`

之所以单独保留这一步，是因为推送 workflow 文件需要带 `workflow` scope 的 token。

## 发版检查清单

- 版本号已更新
- Changelog 已更新
- 测试已通过
- App 可构建
- CLI 可构建
- DMG 已生成
- ZIP 已生成
- Release notes 已生成
- GitHub release draft 已生成
- README 仍然和产品现状一致
