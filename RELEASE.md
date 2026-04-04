# Release Guide

This project ships a signed-style macOS app bundle, a CLI, a zip package, and generated release notes.

## Local release steps

1. Update `VERSION`
2. Add a new top section to `CHANGELOG.md`
3. Run:

```bash
./scripts/prepare_release.sh
```

4. Verify the generated files:

- `release/CodexQuotaPeek-mac.zip`
- `release/RELEASE_NOTES.md`
- `release/GITHUB_RELEASE_DRAFT.md`

5. Commit and push the version/changelog changes
6. Create or update a GitHub Release, paste `release/GITHUB_RELEASE_DRAFT.md`, and upload the zip

## GitHub Actions note

The repository includes a ready-to-copy workflow template here:

- `docs/github-actions/ci.workflow.yml`

To activate it on GitHub, copy it to:

- `.github/workflows/ci.yml`

This extra step exists because pushing workflow files requires a token with the `workflow` scope.

## Release checklist

- Version updated
- Changelog updated
- Tests passed
- App builds
- CLI builds
- Zip package generated
- Release notes generated
- GitHub release draft generated
- README still matches the product
