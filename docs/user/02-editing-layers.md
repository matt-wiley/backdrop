# Editing the layers

This guide shows how to change each part of the config, with an example for each kind of change. If you haven't set up a machine yet, start with [Getting started](01-getting-started.md).

Every example here was added to a copy of the repo and checked in real shells.

## How the layers fit together

There are two layers, and two questions decide which file a setting goes in:

1. **Would a script need it?** Then it's environment: a `PATH` entry or an exported variable, in `env.sh`. Everything else goes in the rc file for your shell.
2. **Is it for every machine?** Then put it in the shared file. If it's for one profile, use the same-named file in `hosts/<profile>/`. If it's for this machine only and shouldn't be versioned, put it below the block.

|                                                                 | Every machine                  | One profile                           |
| --------------------------------------------------------------- | ------------------------------ | ------------------------------------- |
| **Scripts need it** (`PATH`, exports)                           | `sh/env.sh`                    | `hosts/<profile>/env.sh`              |
| **Only you need it** (aliases, options, prompt, tools, plugins) | `zsh/rc.zsh` or `bash/rc.bash` | `hosts/<profile>/rc.zsh` or `rc.bash` |

The layers load top to bottom, and each row can add to or override the rows above it:

![The layers, in the order they load: env.sh and the profile's env.sh, then rc.zsh or rc.bash and the profile's rc file, then your own lines, then load-last plugins](layer-stack.svg)

For variables, aliases and options, the last definition wins. For `PATH`, each `_df_path_prepend` goes in front of the ones before it, so the last call is searched first.

### Which shells load which layers

A shell only loads the layers if it reads a startup file, and which files it reads depends on how it was started:

| Shell start                                                 | Startup files it reads                                                         | Layers it loads                              |
| ----------------------------------------------------------- | ------------------------------------------------------------------------------ | -------------------------------------------- |
| Any zsh, including `zsh -c`, zsh scripts and `ssh host cmd` | `~/.zshenv`                                                                    | environment                                  |
| zsh login shell (every macOS Terminal window)               | `~/.zshenv`, `~/.zprofile`                                                     | environment, twice                           |
| Interactive zsh                                             | `~/.zshenv`, `~/.zshrc`                                                        | environment, interactive                     |
| Interactive bash                                            | `~/.bashrc`                                                                    | environment, interactive                     |
| bash login shell                                            | `~/.bash_profile`, which sources `~/.profile`, then `~/.bashrc` if interactive | environment, then interactive if interactive |
| `ssh host cmd` on a bash host                               | `~/.bashrc`                                                                    | environment                                  |
| `sh` login shell, Linux desktop login                       | `~/.profile`                                                                   | environment                                  |
| `bash -c`, `sh -c`, `bash script.sh`, `sh script.sh`        | none                                                                           | none                                         |

The last row is fine in practice. Exported variables pass from a process to everything it starts, so a script run from your terminal already has your `PATH`. The environment layer matters for shells that don't start from a terminal that has it: `ssh host cmd`, and editors or coding agents opened from the Dock or a launcher that run `zsh -c`. On Linux, desktop apps get it through [`sync-env`](01-getting-started.md#desktop-apps-on-linux).

### Inside one shell start

Each startup file runs its block first, then your own lines below it. Login shells load the environment layer twice, which is harmless:

![The order of startup files in a zsh login terminal and a bash login terminal, and which rows of the layer stack each one loads](startup-order.svg)

## Before and after any edit

Edits take effect in the next shell that starts; there's no build step. A mistake in a layer breaks new shells, so:

1. Keep one terminal open while you edit.
2. After editing, run `dotfiles doctor`. It checks that every layer file parses, in each shell that loads it.
3. Run `dotfiles test`. It starts every kind of shell with your profile, and fails on an `exit`, an error message, or output from a non-interactive shell.
4. Open a new terminal to see the change, or reload the current shell with `exec zsh` or `exec bash`.
5. On Linux, if you changed an `env.sh`, run `dotfiles sync-env` so desktop apps get the change at your next login.

If a new shell won't start, see [Editing a layer safely](01-getting-started.md#editing-a-layer-safely).

## Environment: `env.sh`

**Files:** `sh/env.sh` for every machine; `hosts/<profile>/env.sh` for one profile.

This layer runs in every shell that reads a startup file, including the many short-lived ones that scripts and tools start, so it has strict rules:

- **POSIX `sh` only.** `sh` loads this layer too, so no bash or zsh syntax such as `[[ ]]`, arrays or `local`.
- **Silent.** Never print anything.
- **No subprocesses.** No `$(...)`, backticks or `eval "$(tool init)"`; those go in an rc file.
- **No `exit`, and no shell options** (`set -e`, `set -u` and the like). Both leak into or kill every shell.
- **Variables and `PATH` only.** No aliases or functions.

### Add a directory to `PATH`

Use `_df_path_prepend`. It moves the directory to the front, never adds a duplicate, and skips directories that don't exist, so the same line works on machines that don't have it:

```sh
# sh/env.sh
_df_path_prepend "$HOME/go/bin"
```

Each call goes in front of the previous ones, so the **last** call ends up first in `PATH`. `sh/env.sh` lists its entries from lowest to highest priority: the OS directories (Homebrew on macOS) first, then mise's shims, then `~/.local/bin`. A profile's `env.sh` loads after the shared one, so its directories come before all of them:

```sh
# hosts/work/env.sh
_df_path_prepend "$HOME/work/bin"   # searched before ~/.local/bin and Homebrew
```

### Set an environment variable

```sh
# sh/env.sh
export EDITOR=vim
export LESS='-R --mouse'
```

To override a shared variable on one profile, export it again in the profile's `env.sh`:

```sh
# hosts/work/env.sh
export AWS_PROFILE=work
```

On Linux, `sync-env` copies these variables to `~/.config/environment.d/` for desktop apps, but skips any value containing `$`, `\`, quotes or backticks, with a warning. Expand those yourself (`"$HOME/x"` is fine; it's expanded before `sync-env` sees it), or accept that desktop apps won't get that variable.

### Settings for one operating system

Prefer checking for the thing you need over checking the OS: `_df_path_prepend` already skips directories that don't exist. When a setting really only makes sense on one OS, add it to the `case` near the top of the `PATH` section in `sh/env.sh`:

```sh
# sh/env.sh
case $DOTFILES_OS in
  darwin)
    _df_path_prepend /usr/local/bin
    _df_path_prepend /opt/homebrew/bin
    ;;
  linux)
    export SSH_AUTH_SOCK="${XDG_RUNTIME_DIR:-/run/user/0}/ssh-agent.socket"
    ;;
esac
```

### Secrets

Not in this layer, unless non-interactive shells really need them: on Linux, `sync-env` copies everything this layer exports into a file in `~/.config`. See [Secrets](01-getting-started.md#secrets).

## Interactive: `rc.zsh` and `rc.bash`

**Files:** `zsh/rc.zsh` and `bash/rc.bash` for every machine; `hosts/<profile>/rc.zsh` and `rc.bash` for one profile.

Everything a script doesn't need goes here: aliases, functions, options, keybindings, prompt, completion, tool setup that runs a command, and plugins. You can use each shell's full syntax. If you use both shells, an alias you want in both goes in both files.

### Add an alias

```zsh
# zsh/rc.zsh
alias gs='git status --short'
```

Don't reuse the names of builtins or common commands (`ls`, `cat`, `grep`, `cd`, `find` and so on). Scripts and coding agents expect the real commands, and `doctor` warns about these. Use new names instead, such as `ll` or `gs`.

### Add a function

```zsh
# zsh/rc.zsh
mkcd() { mkdir -p "$1" && cd "$1"; }
```

### Only when a tool is installed

A missing tool should never print an error at startup. Check first with `_df_has`:

```zsh
# zsh/rc.zsh
_df_has fdfind && alias fd=fdfind
```

### Override or remove a shared alias on one profile

The profile's file loads right after the shared one, so define the alias again, or remove it:

```zsh
# hosts/work/rc.zsh
alias gs='git status'        # replaces the shared definition
unalias la 2>/dev/null       # removes it on this profile
```

### Things only a person needs

Each rc file has a section that's skipped when a coding agent such as Claude Code starts the shell. Put conveniences that would confuse an agent there: fancy output, greetings, anything that changes how a command behaves.

```zsh
# zsh/rc.zsh
if [[ ${CLAUDECODE-} != 1 ]]; then
  alias cls='clear'
fi
```

### Shell options

```zsh
# zsh/rc.zsh
setopt auto_cd
```

```sh
# bash/rc.bash
shopt -s globstar 2>/dev/null   # bash 4+; macOS ships bash 3.2 as /bin/bash
```

### Keybindings

```zsh
# zsh/rc.zsh
bindkey -e
```

```sh
# bash/rc.bash
bind '"\e[A": history-search-backward' 2>/dev/null
```

### Prompt

```zsh
# zsh/rc.zsh
PROMPT='%~ %# '
```

```sh
# bash/rc.bash
PS1='\w \$ '
```

### Tools that print their own setup (zoxide, starship, fzf)

Run them only when they're installed:

```zsh
# zsh/rc.zsh
_df_has zoxide && eval "$(zoxide init zsh)"
```

```sh
# bash/rc.bash
_df_has zoxide && eval "$(zoxide init bash)"
```

Each one starts a process every time a shell opens. Check the cost after adding one; the target is under 100 ms:

```sh
time zsh -ic exit
```

### Completion in zsh

`rc.zsh` runs `compinit` once, from a cache in `~/.cache/dotfiles/zcompdump` that's rebuilt at most once a day.

- **Completion styles** can go anywhere in `rc.zsh`:

  ```zsh
  zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'   # case-insensitive
  ```

- **New completion functions** must be on `fpath` *before* `compinit` runs, so add them in `zsh/rc.zsh` above the completion section. A profile's `rc.zsh` loads after `compinit`, which is too late:

  ```zsh
  # zsh/rc.zsh, above "# Completion: use the cached dump"
  [[ -d /opt/homebrew/share/zsh/site-functions ]] && fpath=(/opt/homebrew/share/zsh/site-functions $fpath)
  ```

- **After adding completion functions,** delete the cache so they're picked up now rather than tomorrow:

  ```sh
  rm ~/.cache/dotfiles/zcompdump
  ```

### Plugins that must load last (zsh)

Some plugins only work if they load after everything else, including lines that installers append below the block. zsh-syntax-highlighting is the usual example. List them in `_df_load_last` in `zsh/rc.zsh`; each is sourced once, at the first prompt.

Plugins live in different places on different systems, so an entry can list several places, separated by `:`. The first one that exists is used:

```zsh
# zsh/rc.zsh
_df_load_last=(
  /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh:/usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
)
```

A profile adds its own with `+=`:

```zsh
# hosts/work/rc.zsh
_df_load_last+=(/opt/work/share/work-plugin.zsh)
```

`zsh -ic` never shows a prompt, so neither `dotfiles test` nor a quick `zsh -ic` loads these plugins. Open a new terminal to try them.

## Machine-local settings

Anything below the block in `~/.zshrc`, `~/.bashrc` or the other entry files stays on that machine and isn't versioned. It's the right place for one-off experiments, settings you don't want in the repo, and lines that installers add.

The same rules apply by file: below the block in `~/.zshenv` or `~/.profile` is environment, so keep it silent and fast; below the block in `~/.zshrc` or `~/.bashrc` is interactive.

Don't edit between the markers; `dotfiles init` overwrites those lines, and `doctor` warns about edits there. To see what's changed below the blocks since you last looked:

```sh
dotfiles doctor --diff
```

## Adding a new profile

```sh
cp -R ~/.dotfiles/hosts/example ~/.dotfiles/hosts/work
dotfiles init --profile work
```

Every file in a profile is optional; delete the ones you don't need. Several machines can share one profile. Commit the profile like any other change.

## Adding a tool to install

**Files:** `packages.toml` for every machine; `hosts/<profile>/packages.toml` for one profile.

```toml
[fd]
bin = "fd fdfind"   # commands that count as installed; default: the table name
brew = "fd"
apt = "fd-find"
```

Then preview and install:

```sh
dotfiles install
dotfiles install --yes
```

The full set of keys is in [Adding a tool](01-getting-started.md#adding-a-tool).

## Files to leave alone

- **`sh/lib.sh`:** the helpers every layer uses. A mistake here breaks the env layer in every shell.
- **`blocks/`:** the templates `init` writes into your entry files. If you do change one, bump the version in the first line of every template, then run `dotfiles init` on every machine; `doctor` flags machines that haven't.
- **`bin/dotfiles`:** the CLI. Run `dotfiles test` after any change to it.
