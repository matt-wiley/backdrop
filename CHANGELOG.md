# Changelog

Changes in each release. Versions follow [semantic versioning](https://semver.org): a major version for changes that need you to act (a new block version, a moved or renamed file), a minor version for new features, a patch version for fixes.

`scripts/release.sh` turns the Unreleased section into the next release's notes.

## Unreleased

### Changed

- **Run `dotfiles init` on every machine after upgrading:** the blocks are now v2. Until you do, `doctor` reports the old blocks and the missing files they name.
- Two layers instead of three, so each setting has one obvious place: `sh/env.sh` for what scripts need, and `zsh/rc.zsh` or `bash/rc.bash` for everything else. Each still has a profile file in `hosts/<profile>/` that loads right after it.
- `sh/interactive.sh` and `hosts/<profile>/interactive.sh` are gone; their aliases moved into both rc files. Move anything you added to them into your rc file, or your profile's.
- `sh/os/darwin.sh` and `sh/os/linux.sh` are gone; OS-specific settings are a `case` in `sh/env.sh`, placed so the OS directories stay behind your own in `PATH`.
- `zsh/load-last.zsh` is gone; list plugins that must load last in `_df_load_last` in `zsh/rc.zsh`. A profile's `rc.zsh` can now add to that list too.

## 1.0.1 - 2026-11-23

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
