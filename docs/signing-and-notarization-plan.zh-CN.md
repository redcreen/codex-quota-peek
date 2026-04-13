# 签名与公证方案

[English](signing-and-notarization-plan.md) | [中文](signing-and-notarization-plan.zh-CN.md)

这份文档说明 `Codex Quota Peek` 后续在发布硬化上的目标：让从 GitHub 下载的 macOS 构建可以更顺滑地通过系统信任链。

## 目标

让用户在打开从 GitHub 下载的 macOS 构建时，不再频繁遇到：

- “app is damaged”
- quarantine 警告
- 重复的 Gatekeeper 阻拦

## 需要什么

要发布一个被 macOS 更好信任的构建，需要：

- Apple Developer Program 会员资格
- `Developer ID Application` 签名身份
- 用于自动化 notarization 的凭证

落到执行上，意味着：

- 购买 Apple Developer Program
- 给 `.app` 签名
- 给 `.dmg` 签名
- 提交 notarization
- 在产物上 stapling notarization ticket

## 推荐发布流程

1. 本地构建未签名 app
2. 用 `codesign` 给 app bundle 签名
3. 打包 DMG
4. 给 DMG 签名
5. 提交 notarization
6. stapling 公证票据
7. 上传 notarized DMG 和可选 ZIP 到 GitHub Release

## 为什么重要

没有签名和公证时，用户可能需要：

- 右键后选择 `Open`
- 手动用 `xattr` 去掉 quarantine
- 在 macOS 安全设置里追加信任

这对内部自用还能接受，但对公开产品不理想。

## 短期建议

在签名能力补齐前，当前最可靠的安装方式仍然是：

- clone 或下载源码仓库
- 运行本地安装脚本
- 从 `/Applications` 启动 app

因为 app 是在本机构建的，这样可以避开很多下载包常见的 Gatekeeper 摩擦。

## 后续自动化方向

一旦具备 Apple 签名凭证，release pipeline 应继续扩展：

- 基于环境变量的签名配置
- notarization 提交与轮询
- stapling
- 校验签名产物的 CI 检查

## 相关文件

- [RELEASE.md](/Users/redcreen/project/codex%20limit/RELEASE.md)
- [scripts/package_release.sh](/Users/redcreen/project/codex%20limit/scripts/package_release.sh)
- [scripts/prepare_release.sh](/Users/redcreen/project/codex%20limit/scripts/prepare_release.sh)
