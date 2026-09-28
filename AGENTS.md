# Agent Instructions

## Git branch workflow

- Keep `main` as the stable release branch; do routine and unreleased work on `development`.
- Name release branches `release/v<version>`, using the version in the root `pubspec.yaml` (for example, `release/v0.2.3`). Cut release branches from `development` for release preparation.
- Before switching branches with pending local work, preserve tracked and untracked changes with `git stash push --include-untracked`, then restore that work on `development` unless the user directs otherwise.
- Apply these branch rules to all agent work throughout this repository.
