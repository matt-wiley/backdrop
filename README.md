# backdrop

Shell dotfiles for bash, zsh and POSIX `sh` on Linux and macOS: each setting is written once, and a small injected block at the top of each startup file loads it.

## Install

You need Linux or macOS, and curl or wget. git isn't needed.

With curl:

```sh
curl -fsSL https://github.com/matt-wiley/backdrop/releases/latest/download/install.sh | sh
```

With wget:

```sh
wget -qO- https://github.com/matt-wiley/backdrop/releases/latest/download/install.sh | sh
```

The installer downloads the latest release, checks its SHA-256 checksum, installs it in `~/.dotfiles`, links the `dotfiles` command into `~/.local/bin`, and runs `dotfiles init`. Then open a new terminal and run `dotfiles doctor`.

### Options

Pass options after `sh -s --`:

```sh
curl -fsSL https://github.com/matt-wiley/backdrop/releases/latest/download/install.sh | sh -s -- --profile laptop
wget -qO- https://github.com/matt-wiley/backdrop/releases/latest/download/install.sh | sh -s -- --profile laptop
```

| Option | Does |
| --- | --- |
| `--profile NAME` | Selects this machine's profile from `hosts/` |
| `--version X.Y.Z` | Installs that release instead of the latest |
| `--dir PATH` | Installs somewhere other than `~/.dotfiles` |
| `--no-init` | Installs the files only, without running `dotfiles init` |
| `--zip FILE` | Installs from a release ZIP you've already downloaded, without the network |

### A specific release

Replace `latest/download` with `download/vX.Y.Z` in the URL:

```sh
curl -fsSL https://github.com/matt-wiley/backdrop/releases/download/v0.1.0/install.sh | sh
wget -qO- https://github.com/matt-wiley/backdrop/releases/download/v0.1.0/install.sh | sh
```

Every release on the [releases page](https://github.com/matt-wiley/backdrop/releases) has the versioned ZIP of the repo, its `install.sh` and a `SHA256SUMS` file.

### Read the script first

To look at the installer before running it, download it, then run it with the same options:

```sh
curl -fsSLO https://github.com/matt-wiley/backdrop/releases/latest/download/install.sh
less install.sh
sh install.sh --profile laptop
```

### Upgrade

Run the install command again. The previous install moves to `~/.dotfiles.previous-<version>`. Profiles you created in `hosts/` carry over to the new install; changes to other files stay in the backup, so copy back anything you need. Your startup files and selected profile are kept.

### Install with git instead

To keep your own changes under version control, clone the repo instead of using a release:

```sh
git clone https://github.com/matt-wiley/backdrop.git ~/.dotfiles
~/.dotfiles/bin/dotfiles init
```

Update a clone with `git pull`; the installer refuses to overwrite one.

## Documentation

- [Getting started](docs/user/01-getting-started.md): set up a machine and add your own settings.
- [Editing the layers](docs/user/02-editing-layers.md): examples for each kind of change, layer by layer.
- [Releasing](docs/developer/releasing.md): versioning and how to publish a release.
- [Spec](docs/developer/specs/dotfiles-system-spec.md): the design and the reasons behind it.
- [Changelog](CHANGELOG.md): what changed in each release.
