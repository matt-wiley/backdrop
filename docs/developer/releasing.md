# Releasing

A release is a GitHub Release with three files: a versioned ZIP of the whole repo, an `install.sh` that installs it without git, and a `SHA256SUMS` file. You cut a release with one script; pushing its tag makes CI test, build and publish it.

## Versions

The current version is in `VERSION`, and each release is tagged `vX.Y.Z`. Versions follow [semantic versioning](https://semver.org), read for this project as:

| Bump | When | Examples |
| --- | --- | --- |
| Major (`X`) | Users have to act after upgrading | A new block version (users must run `dotfiles init`), a moved or renamed layer file, a removed command or option |
| Minor (`Y`) | New features that need no action | A new command or option, a new `doctor` check, new settings in a layer |
| Patch (`Z`) | Fixes | A bug fix, a docs fix |

Before the first release, `VERSION` is `0.0.0`.

`dotfiles version` prints the installed version. In a git clone, it also prints the commit, from `git describe`.

## Recording changes

Add a line to `CHANGELOG.md`, under `## Unreleased`, with each change that users would notice. Group lines under `### Added`, `### Changed`, `### Fixed` or `### Removed`. The release script turns this section into the release notes, and it refuses to release when the section is empty.

## Cutting a release

From an up-to-date `main`:

```sh
scripts/release.sh 0.1.0
git push --atomic origin main v0.1.0
```

Or do both in one step with `scripts/release.sh 0.1.0 --push`.

`scripts/release.sh` stops without changing anything unless:

- the version is `X.Y.Z` and newer than `VERSION`,
- you're on `main`, the working tree is clean, and `main` matches `origin/main`,
- the tag doesn't exist yet,
- `CHANGELOG.md` has entries under `## Unreleased`,
- `bin/dotfiles test` passes.

Then it writes the version to `VERSION`, renames the Unreleased section to `## 0.1.0 - <today>` under a new empty Unreleased section, commits `release: v0.1.0` and adds an annotated tag `v0.1.0`.

## What CI does with the tag

Pushing a `vX.Y.Z` tag runs `.github/workflows/release.yml`:

1. Runs the full test suite on Ubuntu and macOS, the same tests as every push.
2. Checks that the tag matches `VERSION`.
3. Builds the release files with `scripts/build-release.sh`.
4. Publishes a GitHub Release named after the tag, with the changelog section as its notes (from `scripts/release-notes.sh`).

The release's files:

| File | What it is |
| --- | --- |
| `mobua-bohr-vX.Y.Z.zip` | The repo as committed at the tag, in a `mobua-bohr-vX.Y.Z/` folder. Built with `git archive`, so uncommitted and ignored files are never included. |
| `install.sh` | The repo's `install.sh`, with `RELEASE_VERSION` set to `X.Y.Z`, so it installs its own release by default |
| `SHA256SUMS` | SHA-256 checksums of the two files above; the installer refuses a ZIP that doesn't match |

The README's `releases/latest/download/install.sh` URL always serves the newest release's installer. Anonymous downloads only work while the repository is public.

## Building and trying a release locally

```sh
scripts/build-release.sh            # writes dist/ (ignored by git)
sh dist/install.sh --zip dist/mobua-bohr-v$(cat VERSION).zip --dir /tmp/dotfiles-try --no-init
```

The build uses `HEAD`, so commit first. `test/release.sh`, part of `dotfiles test`, builds releases from a scratch copy of the working tree and installs them through a local HTTP server with both curl and wget.

## When a release goes wrong

- **The workflow fails before publishing** (a failing test, or a tag that doesn't match `VERSION`): nothing was published. Fix the problem on `main` and release the next patch version. Don't move or reuse a tag that was pushed.
- **A published release is broken:** release a fix as the next patch version. Marking the broken release as a pre-release on GitHub takes it out of `latest`, so new installs skip it.
