# Releasing

A release is a GitHub Release with three files: a versioned ZIP of the whole repo, an `install.sh` that installs it without git, and a `SHA256SUMS` file. It's what the README's `curl … | sh` and `wget … | sh` commands install.

Releases are cut by hand, with one script. Pushing the tag it creates makes CI test, build and publish the release.

**In short:**

1. With each change, add a line to `CHANGELOG.md` under `## Unreleased`.
2. When you're ready to release, merge to `main` and pull it.
3. Pick the version: major, minor or patch (see [Versioning](#versioning)).
4. Run `scripts/release.sh X.Y.Z --push`.
5. Watch the release workflow, then check the published release.

## Versioning

### Where the version lives

| Place | What it holds |
| --- | --- |
| `VERSION` | The current version, `X.Y.Z`. Only `scripts/release.sh` changes it. |
| Git tag `vX.Y.Z` | The commit each release was built from. Tags are never moved or reused. |
| The release's `install.sh` | Its `RELEASE_VERSION`, set at build time, so each installer installs its own release by default |
| `dotfiles version` | Prints `VERSION` on an installed machine; in a git clone, also the commit from `git describe` |

Before the first release, `VERSION` is `0.0.0`.

### Choosing the next version

Versions follow [semantic versioning](https://semver.org). For this project, the question is what a user has to do after upgrading:

| Bump | When | Examples |
| --- | --- | --- |
| **Major** (`X`) | Users must act after upgrading, or something they relied on is gone | A changed block template with a new block version (users must run `dotfiles init`); a layer file that moved or was renamed; a command, option or `packages.toml` key that was removed or now means something else |
| **Minor** (`Y`) | Something new, and upgrading needs no action | A new command, option or `doctor` check; new settings, aliases or tools in the layers; a new installer option |
| **Patch** (`Z`) | Fixes only | A bug fix in the CLI, installer or a layer; a docs or test fix |

When a release holds several kinds of change, the biggest one decides. Bump one number and reset the ones to its right: from `1.4.2`, a minor release is `1.5.0` and a major one is `2.0.0`.

## The changelog

`CHANGELOG.md` is written by hand, for people upgrading their machines. Its `## Unreleased` section collects changes until the next release, and at release time that section becomes the release notes.

### While developing

Add the changelog entry in the same pull request as the change. Put each entry under one of these headings in `## Unreleased`, creating the heading if it isn't there:

- `### Added` for new features.
- `### Changed` for changes to existing behavior.
- `### Fixed` for bug fixes.
- `### Removed` for things that are gone.

Write one line per change, describing what users notice rather than how the code changed. For a change that needs users to act, say what to run. Leave out changes nobody upgrading would notice, such as refactors, test-only changes and CI changes.

```markdown
## Unreleased

### Added

- `dotfiles doctor` reports layer files that don't parse.

### Changed

- The `~/.zshrc` block now loads host files earlier. Run `dotfiles init` after upgrading.

### Fixed

- `install.sh` no longer fails when `unzip` is missing; it uses Python instead.
```

### At release time

`scripts/release.sh` dates the section and opens a new empty one above it. It refuses to release when `## Unreleased` has no entries. Before:

```markdown
## Unreleased

### Fixed

- `install.sh` no longer fails when `unzip` is missing.
```

After `scripts/release.sh 0.2.1`:

```markdown
## Unreleased

## 0.2.1 - 2026-12-01

### Fixed

- `install.sh` no longer fails when `unzip` is missing.
```

The release workflow publishes everything under `## 0.2.1 - …` as the GitHub Release's notes. To preview them, run `scripts/release-notes.sh 0.2.1`.

### Fixing notes after a release

Fix the section in `CHANGELOG.md` on `main` like any other change, then update the published notes to match:

```sh
scripts/release-notes.sh 0.2.1 > /tmp/notes.md
gh release edit v0.2.1 --notes-file /tmp/notes.md
```

## Creating a release

### 1. Get `main` ready

- Merge everything that should be in the release.
- Check that `## Unreleased` in `CHANGELOG.md` describes all of it.
- Switch to `main` and pull: `git switch main && git pull`.

### 2. Run the release script

```sh
scripts/release.sh 0.2.0 --push
```

It stops without changing anything unless all of these are true:

- the version is `X.Y.Z` and newer than `VERSION`,
- you're on `main`, the working tree is clean, and `main` matches `origin/main`,
- the tag `v0.2.0` doesn't exist yet,
- `CHANGELOG.md` has entries under `## Unreleased`,
- `bin/dotfiles test` passes. This takes about a minute; if it fails, run `bin/dotfiles test` yourself to see why.

Then it:

- writes `0.2.0` to `VERSION` and dates the changelog section,
- commits `release: v0.2.0` and adds an annotated tag `v0.2.0`,
- pushes `main` and the tag together, so either both land or neither does.

Without `--push`, it stops after tagging and prints the push command. That leaves you a chance to look at the release commit first:

```sh
scripts/release.sh 0.2.0
git show                                  # check the release commit
git push --atomic origin main v0.2.0
```

### 3. Watch the release workflow

```sh
gh run watch "$(gh run list --workflow release.yml --limit 1 --json databaseId -q '.[0].databaseId')"
```

### 4. Check the published release

```sh
gh release view v0.2.0                    # notes, and three files attached
curl -fsSL https://github.com/matt-wiley/mobua-bohr/releases/latest/download/install.sh | grep '^RELEASE_VERSION='
```

To try the installer end to end without touching your own setup, give it a throwaway home directory:

```sh
curl -fsSL https://github.com/matt-wiley/mobua-bohr/releases/latest/download/install.sh | HOME=$(mktemp -d) sh -s -- --no-init
```

Anonymous downloads only work while the repository is public.

## What CI does with the tag

Pushing a `vX.Y.Z` tag runs `.github/workflows/release.yml`:

1. Runs the test workflow on Ubuntu and macOS: the same tests every push gets.
2. Checks that the tag matches `VERSION`.
3. Builds the release files with `scripts/build-release.sh`.
4. Publishes a GitHub Release named after the tag, with the changelog section as its notes.

The release's files:

| File | What it is |
| --- | --- |
| `mobua-bohr-vX.Y.Z.zip` | The repo as committed at the tag, in a `mobua-bohr-vX.Y.Z/` folder. Built with `git archive`, so uncommitted and ignored files are never included. |
| `install.sh` | The repo's `install.sh`, with `RELEASE_VERSION` set to `X.Y.Z` |
| `SHA256SUMS` | SHA-256 checksums of the two files above; the installer refuses a ZIP that doesn't match |

The README's `releases/latest/download/install.sh` URL always serves the newest release's installer.

## Building and trying a release locally

```sh
scripts/build-release.sh    # writes dist/, which git ignores
HOME=$(mktemp -d) sh dist/install.sh --zip "dist/mobua-bohr-v$(cat VERSION).zip"
```

The build uses `HEAD`, so commit first. The throwaway `HOME` matters: the installer links `~/.local/bin/dotfiles` and runs `dotfiles init`, which would otherwise change your own setup.

`test/release.sh`, part of `dotfiles test`, covers all of this automatically. It builds releases from a scratch copy of the working tree, serves them from a local HTTP server, and installs them with both curl and wget.

## When something goes wrong

| What happened | What to do |
| --- | --- |
| `scripts/release.sh` refused | It changed nothing. Fix what it names and run it again. |
| The push failed after the release commit and tag were made | Run `git push --atomic origin main vX.Y.Z` once the problem is fixed. To abandon the release before pushing: `git tag -d vX.Y.Z && git reset --hard HEAD~1`. |
| The release workflow failed | Nothing was published, but the tag and release commit are on GitHub. Fix the problem on `main`, add a changelog entry for the fix, and release the next patch version. Don't delete, move or reuse the tag. |
| A published release is broken | Release a fix as the next patch version. Meanwhile, mark the broken release as a pre-release on GitHub (`gh release edit vX.Y.Z --prerelease`), which takes it out of `latest`, so new installs skip it. |
| The release notes are wrong | See [Fixing notes after a release](#fixing-notes-after-a-release). |

## Files

| File | Role |
| --- | --- |
| `VERSION` | The current version |
| `CHANGELOG.md` | Changes per release; `## Unreleased` becomes the next release's notes |
| `scripts/release.sh` | Checks, bumps `VERSION`, dates the changelog, commits, tags, optionally pushes |
| `scripts/build-release.sh` | Builds the ZIP, the stamped `install.sh` and `SHA256SUMS` from `HEAD` |
| `scripts/release-notes.sh` | Prints one version's changelog section |
| `install.sh` | The installer; releases attach a copy stamped with their version |
| `.github/workflows/release.yml` | Tests, builds and publishes on a `vX.Y.Z` tag |
| `test/release.sh` | Tests for all of the above |
