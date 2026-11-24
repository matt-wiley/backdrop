# Getting started with dotfiles

This repo gives every shell on every machine the same config, with each setting written once. It works with bash, zsh and POSIX `sh`, on Linux and macOS.

It doesn't replace your `~/.zshrc`, `~/.bashrc` or other startup files. Instead, `dotfiles init` adds a small marked block at the top of each one, and that block loads the config from this repo. Everything below the block stays yours: hand edits, lines that installers append, and anything specific to one machine.

![Which startup files each kind of shell reads, and which layers each file's block loads](load-flow-files.svg)

Every shell reaches the environment layer; only interactive shells reach the interactive layers. [Editing the layers](02-editing-layers.md#how-the-layers-fit-together) shows the order inside a single shell start.

## What you need

- Linux or macOS.
- bash or zsh as your shell, and either curl or wget (for a release) or `git` (for a clone). Everything else the CLI needs ships with the OS.
- For `dotfiles install`: Homebrew on macOS, or apt, dnf, pacman or Homebrew on Linux.

## Set up a machine

There are two ways to get the files:

- **A release,** with one command and no git. Upgrades replace the files, so edits you make to shared files need copying back by hand after each upgrade. Profiles you create carry over.
- **A git clone,** if you'll change the config and want those changes versioned. The rest of this guide assumes a clone, but every step after the install works the same either way.

### 1. Get the files

To install a release, run the installer with curl or wget. It also does steps 2 and 4 below for you:

```sh
curl -fsSL https://github.com/matt-wiley/backdrop/releases/latest/download/install.sh | sh
wget -qO- https://github.com/matt-wiley/backdrop/releases/latest/download/install.sh | sh
```

The [README](../../README.md#install) lists its options, how to install a specific version and how to upgrade.

To clone instead:

```sh
git clone https://github.com/matt-wiley/backdrop.git ~/.dotfiles
```

`~/.dotfiles` is the default location, but any path works: `init` writes the repo's location into the blocks. If you move the repo later, run `dotfiles init` again from the new location.

### 2. Put the `dotfiles` command on your PATH

```sh
mkdir -p ~/.local/bin
ln -s ~/.dotfiles/bin/dotfiles ~/.local/bin/dotfiles
```

Once `init` has run, the env layer puts `~/.local/bin` on your `PATH` in every shell. Until then, call the command by its full path, `~/.dotfiles/bin/dotfiles`.

### 3. Choose a profile for this machine

A profile holds settings for one machine, or a group of machines, that should still be versioned: work-only `PATH` entries, a different editor, extra tools. Start one by copying the example:

```sh
cp -R ~/.dotfiles/hosts/example ~/.dotfiles/hosts/laptop
```

Every file in a profile is optional. Each one loads right after the shared file it overrides:

| Profile file | Overrides | Loads in |
| --- | --- | --- |
| `env.sh` | `sh/env.sh` | every shell |
| `interactive.sh` | `sh/interactive.sh` | interactive bash and zsh |
| `rc.bash` | `bash/rc.bash` | interactive bash |
| `rc.zsh` | `zsh/rc.zsh` | interactive zsh |
| `packages.toml` | `packages.toml` | `dotfiles install` |

You can skip the profile: run `init` without `--profile`, and the machine gets the shared config only. `doctor` will warn that no profile is selected until you pick one.

### 4. Run `init`

```sh
~/.dotfiles/bin/dotfiles init --profile laptop
```

`init` does the following:

- Writes the profile name to `~/.config/dotfiles/host`. That file is per machine and isn't part of the repo.
- Adds the block to the top of `~/.profile`, `~/.bash_profile`, `~/.bashrc`, `~/.zshenv`, `~/.zprofile` and `~/.zshrc`, creating any that don't exist. Your existing content moves below the block, unchanged.
- On Linux, backs up any of those files that is still an untouched copy of the distro default (from `/etc/skel`) to `<file>.dist`, and replaces it with a bare block. The repo's config takes over what the default provided.
- On Linux, writes `~/.config/environment.d/dotfiles.conf` so desktop apps get the same environment (see [Desktop apps on Linux](#desktop-apps-on-linux)).
- Lists tools from `packages.toml` that aren't installed.

`init` never installs anything, and running it again is safe: if nothing changed, it changes nothing.

### 5. Open a new shell and check

```sh
dotfiles doctor
```

`doctor` checks every entry file and the setup in general, then prints the content below each block. A healthy setup shows `ok` lines and ends with `doctor: 0 errors, 0 warnings`. Lines marked `info`, such as a tool that isn't installed, don't count as problems.

To see which repo files a shell loads:

```sh
DOTFILES_TRACE=1 zsh -ic exit
```

### 6. Install tools

```sh
dotfiles install          # dry run: shows what it would install, and the commands
dotfiles install --yes    # does it
```

`install` uses Homebrew on macOS. On Linux it uses apt, dnf or pacman, falling back to Homebrew; `--manager brew` (or `apt`, `dnf`, `pacman`) picks one yourself. It uses `sudo` for system package managers when you aren't root, and only installs tools that are missing.

## Where to put a setting

This is a quick reference. [Editing the layers](02-editing-layers.md) has examples for each kind of change.

| You want | Put it in | Notes |
| --- | --- | --- |
| An environment variable or `PATH` entry, everywhere | `sh/env.sh` | Reaches every shell, including scripts and `ssh host cmd` |
| The same, on one machine or profile | `hosts/<profile>/env.sh` | |
| An alias or simple function, both shells | `sh/interactive.sh` | Interactive shells only |
| bash or zsh options, completion, keybinds, prompt | `bash/rc.bash` or `zsh/rc.zsh` | |
| A plugin that must load last (syntax highlighting) | `zsh/load-last.zsh` | Runs once, at the first prompt |
| A tool to install | `packages.toml` | See [Adding a tool](#adding-a-tool) |
| Something for this machine only, not versioned | Below the block in the entry file | `doctor` shows it |
| A secret | Below the block, or a gitignored file in your profile | See [Secrets](#secrets) |

### Rules for `env.sh`

The env layer runs in every shell, including the many non-interactive shells that scripts and tools start. Keep it safe and fast:

- **POSIX `sh` only.** No bash or zsh syntax, because `sh` loads it too.
- **Silent.** No output, ever.
- **Fast.** No subprocesses (no `$(...)` and no `eval "$(tool init)"`); those belong in the interactive layers.
- **Exports only.** Variables and `PATH`; no aliases or shell options.
- **Add to `PATH` with the helper**, which skips directories that don't exist and never adds duplicates:

  ```sh
  _df_path_prepend "$HOME/go/bin"
  export EDITOR=vim
  ```

### Rules for the interactive layers

- **Don't redefine common commands.** No aliases or functions named `ls`, `cat`, `grep`, `cd` and the like; use new names such as `ll`. Scripts and coding agents expect the real commands, and `doctor` warns about these.
- **Detect tools, not operating systems:** `_df_has fdfind && alias fd=fdfind`.
- **Skip missing tools quietly.** A missing tool should never print an error at startup.

Changes take effect in new shells. To reload the current one, run `exec zsh` or `exec bash`.

### Editing a layer safely

A mistake in a layer breaks every new shell, and in `env.sh` it also breaks scripts: an `exit` makes every shell quit at startup, and a syntax error stops `sh` login shells where `sh` is dash, as on Debian and Ubuntu. So:

1. Keep one terminal open while you edit, in case new ones won't start.
2. Run `dotfiles doctor`. It checks that every layer file parses, in each shell that loads it, including your profile's files.
3. Run `dotfiles test`. It starts every kind of shell with your profile and fails on an `exit`, an error message, or output from a non-interactive shell.
4. Then open a new terminal; that's also the only way to try `load-last.zsh`.

If a new shell won't start, use the open terminal, or start one without startup files (`bash --noprofile --norc` or `zsh -f`), and undo the change with `git -C ~/.dotfiles restore <file>`. Moving the repo aside (`mv ~/.dotfiles ~/.dotfiles.off`) switches the config off everywhere at once; shells start without it.

### Adding a tool

Add a table to `packages.toml`, or to `hosts/<profile>/packages.toml` for one profile:

```toml
[fd]
bin = "fd fdfind"   # commands that count as installed; default: the table name
required = true     # doctor reports it when missing
brew = "fd"         # package name for each manager
apt = "fd-find"
dnf = "fd-find"
pacman = "fd"

[node]
mise = "node@lts"   # installed with `mise use -g`, not the package manager
```

Leave out a manager to skip the tool there. A table in a profile's `packages.toml` replaces the shared table of the same name.

### Secrets

Never put secrets in `hosts/`, or anywhere else in the repo. Either:

- put them below the block in the entry file, which never leaves the machine, or
- put them in a file the repo ignores (`hosts/<profile>/secrets.sh` or `hosts/<profile>/*.local.sh`) and source it from your profile:

  ```sh
  # hosts/laptop/interactive.sh
  [ -r "$DOTFILES_DIR/hosts/laptop/secrets.sh" ] && . "$DOTFILES_DIR/hosts/laptop/secrets.sh"
  ```

On Linux, anything the env layer exports is copied into `~/.config/environment.d/dotfiles.conf`. So a secret sourced from `env.sh` ends up in that file too. Source secrets from the interactive layers, as above, unless non-interactive shells really need them.

## Day to day

| When | Run |
| --- | --- |
| After pulling changes | `dotfiles doctor`; if it says a block is out of date, `dotfiles init` |
| After changing `env.sh` or a profile's `env.sh` (Linux) | `dotfiles sync-env`, then log out and back in for desktop apps |
| After adding tools to `packages.toml` | `dotfiles install`, then `dotfiles install --yes` |
| When an installer edits your startup files | `dotfiles doctor` |
| To see what changed locally since last time | `dotfiles doctor --diff` |
| To switch this machine's profile | `dotfiles init --profile NAME` |

Installers that append to `~/.zshrc` or `~/.bashrc` are fine: their lines land below the block. If one adds lines above the block instead, `doctor` reports an error, and `dotfiles init` moves the block back to the top.

## Desktop apps on Linux

Terminals and SSH sessions get the env layer from the blocks. Some programs on a Linux desktop never start from a shell, though: systemd user services, apps that D-Bus starts on demand, and on some desktops apps opened from the launcher. They read their environment from `~/.config/environment.d/` instead.

`dotfiles sync-env` writes `~/.config/environment.d/dotfiles.conf` from what the env layer exports. `init` runs it for you; after that, run it again whenever you change an `env.sh`. `doctor` warns when the file is out of date. Changes reach desktop apps at your next login.

A few values can't be written to that file exactly, such as ones containing `$` or quotes. `sync-env` skips those with a warning. On macOS, desktop apps don't read shell config, so `sync-env` isn't used there.

## Troubleshooting

- **Something doesn't load:** run `DOTFILES_TRACE=1 zsh -ic exit` (or `bash -ic exit`) to see which repo files load, then `dotfiles doctor`, which also reports layer files that don't parse.
- **A setting works in a terminal but not in a script:** it's probably in an interactive layer. Move it to `env.sh` if scripts need it.
- **The repo is missing or moved:** shells still start normally, without the repo's config. Run `dotfiles init` from the repo's new location.
- **Startup is slow:** look for `$(...)` or `eval` in your profile's files and below the blocks.

## Removing it

```sh
dotfiles uninstall
```

This removes every block and `~/.config/environment.d/dotfiles.conf`. Your own content stays where it is. Files that held only the block are deleted, and distro defaults that `init` backed up are restored. The profile selector (`~/.config/dotfiles/host`) and the cache (`~/.cache/dotfiles`) are kept; delete them by hand if you're done for good.

## More

- `dotfiles --help` lists the commands. Each one also takes `--help`.
- `dotfiles test` runs the full test suite; it needs bash and zsh.
- The design, and the reasons behind it, are in the [spec](../developer/specs/dotfiles-system-spec.md).
