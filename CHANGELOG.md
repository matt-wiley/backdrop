# Changelog

Changes in each release. Versions follow [semantic versioning](https://semver.org): a major version for changes that need you to act (a new block version, a moved or renamed file), a minor version for new features, a patch version for fixes.

`scripts/release.sh` turns the Unreleased section into the next release's notes.

## Unreleased

### Fixed

- Releases publish again. The release workflow's tests failed whenever the changelog's Unreleased section was empty, as it always is right after a release, so v1.0.0 was tagged but never published. Use v1.0.1.

## 1.0.0 - 2026-11-23

### Added

- Environment, shared interactive and shell-specific layers for bash, zsh and POSIX `sh`, with per-machine profiles in `hosts/`.
- Injected blocks for `~/.profile`, `~/.bash_profile`, `~/.bashrc`, `~/.zshenv`, `~/.zprofile` and `~/.zshrc`.
- The `dotfiles` CLI: `init`, `install`, `doctor`, `sync-env`, `test`, `uninstall` and `version`.
- Load matrix and CLI test suites, run in CI on Linux and macOS.
- Releases: a versioned ZIP of the repo and an `install.sh` that installs it with curl or wget, no git needed.
- User guides and load-flow diagrams in `docs/user/`.
