# Signing and Notarization Plan

[English](signing-and-notarization-plan.md) | [中文](signing-and-notarization-plan.zh-CN.md)

This document describes the future release-hardening plan for `Codex Quota Peek`.

## Goal

Make GitHub-downloaded macOS builds open cleanly without users seeing:

- "app is damaged"
- quarantine warnings
- repeated Gatekeeper friction

## What is required

To ship a properly trusted macOS build, the project will need:

- an Apple Developer Program membership
- a `Developer ID Application` signing identity
- notarization credentials for automated release signing

In practice, this means:

- paying for the Apple Developer Program
- signing the `.app`
- signing the `.dmg`
- submitting the app for notarization
- stapling the notarization ticket back onto the release artifact

## Recommended release flow

1. Build the unsigned app locally
2. Sign the app bundle with `codesign`
3. Package a DMG
4. Sign the DMG
5. Submit for notarization
6. Staple the notarization ticket
7. Upload the notarized DMG and optional zip to GitHub Release

## Why this matters

Without signing and notarization, users may need to:

- right-click and choose `Open`
- remove quarantine manually with `xattr`
- grant extra trust in macOS Security settings

That is acceptable for internal use, but not ideal for a public product.

## Short-term recommendation

Until signing is added, the most reliable install flow is:

- clone or download the source repository
- run the local install script
- launch the app from `/Applications`

Because the app is built locally, this avoids the most common downloaded-app Gatekeeper problems.

## Future automation

Once Apple signing credentials are available, the release pipeline should grow to include:

- environment-based signing configuration
- notarization submission and polling
- stapling
- CI checks that verify signed artifacts

## Related files

- [RELEASE.md](/Users/redcreen/Project/codex%20limit/RELEASE.md)
- [scripts/package_release.sh](/Users/redcreen/Project/codex%20limit/scripts/package_release.sh)
- [scripts/prepare_release.sh](/Users/redcreen/Project/codex%20limit/scripts/prepare_release.sh)
