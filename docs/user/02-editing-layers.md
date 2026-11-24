# Editing the layers

This guide shows how to change each part of the config, with an example for each kind of change. If you haven't set up a machine yet, start with [Getting started](01-getting-started.md).

Every example here was added to a copy of the repo and checked in real shells.

## How the layers fit together

Settings are grouped by what they are, not by shell. Each kind of shell start reads its own startup files, and the block in each one loads the layers that apply:

![Which startup files each kind of shell reads, and which layers each file's block loads](load-flow-files.svg)

The layers load in this order, and each profile file loads right after the shared file it overrides:

| Order | Layer | Files | Loaded by |
| --- | --- | --- | --- |
| 1 | Environment | `sh/env.sh`, then `sh/os/linux.sh` or `sh/os/darwin.sh`, then `hosts/<profile>/env.sh` | Every shell: terminals, scripts, `ssh host cmd`, agents, desktop login |
| 2 | Shared interactive | `sh/interactive.sh`, then `hosts/<profile>/interactive.sh` | Interactive bash and zsh |
| 3 | Shell-specific | `bash/rc.bash` or `zsh/rc.zsh`, then `hosts/<profile>/rc.bash` or `rc.zsh` | Interactive bash, or interactive zsh |
| — | Load-last | `zsh/load-last.zsh` | Interactive zsh, once, at the first prompt |
| — | Machine-local | Anything below the block in `~/.zshrc`, `~/.bashrc` and the other entry files | That machine only, after the layers above |

Inside one shell start, each entry file runs its block first, then your own lines below it. Login shells load the environment layer twice, which is harmless:

![The order of files and layers inside a zsh login shell and a bash login shell](load-flow-order.svg)

Two questions decide where a setting goes:

1. **Do scripts and non-interactive shells need it?** Then it's environment (layer 1): a variable or a `PATH` entry. Otherwise it belongs in layer 2 or 3.
2. **Is it for every machine?** Then put it in the shared file. If it's for one profile, use that profile's file. If it's for this machine only and shouldn't be versioned, put it below the block.

## Before and after any edit

Edits take effect in the next shell that starts; there's no build step. A mistake in a layer breaks new shells, so:

1. Keep one terminal open while you edit.
2. After editing, run `dotfiles doctor`. It checks that every layer file parses, in each shell that loads it.
3. Run `dotfiles test`. It starts every kind of shell with your profile, and fails on an `exit`, an error message, or output from a non-interactive shell.
4. Open a new terminal to see the change, or reload the current shell with `exec zsh` or `exec bash`.
5. On Linux, if you changed an env layer file, run `dotfiles sync-env` so desktop apps get the change at your next login.

If a new shell won't start, see [Editing a layer safely](01-getting-started.md#editing-a-layer-safely).

## Layer 1: environment

**Files:** `sh/env.sh` for every machine; `sh/os/linux.sh` or `sh/os/darwin.sh` for one OS; `hosts/<profile>/env.sh` for one profile.

This layer runs in every shell, including the many short-lived shells that scripts and tools start, so it has strict rules:

- **POSIX `sh` only.** `sh` loads this layer too, so no bash or zsh syntax such as `[[ ]]`, arrays or `local`.
- **Silent.** Never print anything.
- **No subprocesses.** No `$(...)`, backticks or `eval "$(tool init)"`; those go in layer 3.
- **No `exit`, and no shell options** (`set -e`, `set -u` and the like). Both leak into or kill every shell.
- **Variables and `PATH` only.** No aliases or functions.

### Add a directory to `PATH`

Use `_df_path_prepend`. It moves the directory to the front, never adds a duplicate, and skips directories that don't exist, so the same line works on machines that don't have it:

```sh
# sh/env.sh
_df_path_prepend "$HOME/go/bin"
```

Each call goes in front of the previous ones, so the **last** call ends up first in `PATH`. A profile's `env.sh` loads after the shared one, so its directories come before the shared ones:

```sh
# hosts/work/env.sh
_df_path_prepend "$HOME/work/bin"   # searched before ~/go/bin
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

Prefer checking for the thing you need over checking the OS: `_df_path_prepend` already skips directories that don't exist. When a setting really only makes sense on one OS, put it in that OS's file:

```sh
# sh/os/linux.sh
export SSH_AUTH_SOCK="${XDG_RUNTIME_DIR:-/run/user/0}/ssh-agent.socket"
```

`sh/os/darwin.sh` already adds Homebrew's directories to `PATH`.

### Secrets

Not in this layer, unless non-interactive shells really need them: on Linux, `sync-env` copies everything this layer exports into a file in `~/.config`. See [Secrets](01-getting-started.md#secrets).

## Layer 2: shared interactive

**Files:** `sh/interactive.sh` for every machine; `hosts/<profile>/interactive.sh` for one profile.

Both bash and zsh load this file, so everything in it must work in both. Use it for aliases and simple functions.

### Add an alias

```sh
# sh/interactive.sh
alias gs='git status --short'
```

Don't reuse the names of builtins or common commands (`ls`, `cat`, `grep`, `cd`, `find` and so on). Scripts and coding agents expect the real commands, and `doctor` warns about these. Use new names instead, such as `ll` or `gs`.

### Add a function

```sh
# sh/interactive.sh
mkcd() { mkdir -p "$1" && cd "$1"; }
```

Write the `name() { ...; }` form, which both shells accept.

### Only when a tool is installed

A missing tool should never print an error at startup. Check first with `_df_has`:

```sh
# sh/interactive.sh
_df_has fdfind && alias fd=fdfind
```

### Override or remove a shared alias on one profile

The profile's file loads right after the shared one, so define the alias again, or remove it:

```sh
# hosts/work/interactive.sh
alias gs='git status'        # replaces the shared definition
unalias la 2>/dev/null       # removes it on this profile
```

### Things only a person needs

`sh/interactive.sh` has a section that's skipped when a coding agent such as Claude Code starts the shell. Put conveniences that would confuse an agent there: fancy output, greetings, anything that changes how a command behaves.

```sh
# sh/interactive.sh
if [ "${CLAUDECODE-}" != 1 ]; then
  alias cls='clear'
fi
```

## Layer 3: bash or zsh only

**Files:** `bash/rc.bash` and `zsh/rc.zsh` for every machine; `hosts/<profile>/rc.bash` and `rc.zsh` for one profile.

Shell-specific code goes here: options, keybindings, prompts, completion, and tool setup that runs a command. You can use each shell's full syntax.

### Shell options

```sh
# bash/rc.bash
shopt -s globstar
```

```zsh
# zsh/rc.zsh
setopt auto_cd
```

### Keybindings

```sh
# bash/rc.bash
bind '"\e[A": history-search-backward' 2>/dev/null
```

```zsh
# zsh/rc.zsh
bindkey -e
```

### Prompt

```sh
# bash/rc.bash
PS1='\w \$ '
```

```zsh
# zsh/rc.zsh
PROMPT='%~ %# '
```

### Tools that print their own setup (zoxide, starship, fzf)

Run them only when they're installed:

```sh
# bash/rc.bash
_df_has zoxide && eval "$(zoxide init bash)"
```

```zsh
# zsh/rc.zsh
_df_has zoxide && eval "$(zoxide init zsh)"
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

## Plugins that must load last (zsh)

**File:** `zsh/load-last.zsh`

Some plugins only work if they load after everything else, including lines that installers append below the block. zsh-syntax-highlighting is the usual example. `load-last.zsh` runs once, at the first prompt.

Plugins live in different places on different systems, so try each and use the first that exists:

```zsh
# zsh/load-last.zsh
for _df_f in \
  /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh \
  /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh; do
  if [[ -r $_df_f ]]; then source $_df_f; break; fi
done
unset _df_f
```

`zsh -ic` never shows a prompt, so neither `dotfiles test` nor a quick `zsh -ic` runs this file. Open a new terminal to try it.

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
- **`blocks/`:** the templates `init` writes into your entry files. If you do change one, bump the `v1` in its first line, then run `dotfiles init` on every machine; `doctor` flags machines that haven't.
- **`bin/dotfiles`:** the CLI. Run `dotfiles test` after any change to it.
