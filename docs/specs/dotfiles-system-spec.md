# Dotfiles system spec

Nov 6, 2026 · @Matt Wiley

## Overview and goals

One repo delivers the right shell config to every shell on every machine, with each setting written once. Shell startup files stay owned by the machine; the repo injects a small block at the top of each and never manages the rest.

- **Write once:** each setting lives in exactly one file, whatever the shell or OS.
- **Right place:** environment reaches every shell; interactive config reaches only interactive shells.
- **Install-proof:** installers that append to rc files never touch the repo and never conflict with it.
- **Verifiable:** an automated matrix proves which files load in which shell, on Linux and macOS.
- **Removable:** `dotfiles uninstall` removes the blocks and generated files; machine content stays.

## The four axes

The system must give correct results for every combination of these axes (24 in all). The design collapses them into layers instead of maintaining a file per combination.

| Axis | Values | What it changes | How the design handles it |
| --- | --- | --- | --- |
| OS | Linux, macOS | Tool names and paths, `path_helper`, how the desktop starts the session | Detected once in the env layer; capability checks preferred over OS checks |
| Login | login, non-login | Which startup files the shell reads; macOS Terminal opens login shells | Every entry file gets an injected block, so both paths reach the env layer |
| Interactivity | interactive, non-interactive | Whether rc files are read | Env is unguarded; interactive layers sit behind a `$-` guard |
| Shell | bash, zsh, POSIX `sh` | File names, syntax, completion and option systems | Shared layers are POSIX `sh`; only the shell layer is shell-specific |

## Architecture

Settings are organized by kind, not by shell: environment, shared interactive, and shell-specific interactive. Each shell entry file carries only a small injected block that routes into those layers.

&#91;embedded content: entry files to layers · 6 files, 3 layers\]

Every shell path reaches the env layer; only interactive shells reach the two layers below it. `~/.bash_profile` reaches the layers through `~/.profile` and `~/.bashrc`.

## Repository layout

The repo holds layers, per-shell code, machine profiles and the CLI; it holds no copies of `~/.zshrc` or `~/.bashrc`.

```
dotfiles/
  bin/dotfiles              # CLI: init, install, doctor, sync-env, test, uninstall
  packages.toml             # tool list for `install`
  sh/
    env.sh                  # layer 1: environment (POSIX)
    interactive.sh          # layer 2: shared aliases and functions (POSIX)
    lib.sh                  # internal helpers: _df_path_prepend, _df_has, _df_trace
    os/darwin.sh
    os/linux.sh
  bash/rc.bash              # layer 3: bash interactive
  zsh/rc.zsh                # layer 3: zsh interactive
  zsh/load-last.zsh         # deferred plugins (syntax highlighting)
  hosts/
    <profile>/env.sh        # versioned machine overrides, all optional
    <profile>/interactive.sh
    <profile>/rc.bash
    <profile>/rc.zsh
    <profile>/packages.toml
  blocks/                   # templates for the injected blocks
  test/matrix.sh
```

All paths inside the repo are resolved from `DOTFILES_DIR`, which each injected block sets. `init` resolves the repo's own location and writes it into every block; the default clone path is `~/.dotfiles`. Moving the repo means re-running `init`.

## Injection blocks

Each shell entry file gets one marked block at its very top; everything below the block belongs to the machine and is never read or edited by the tool.

| Entry file | Block sources, in order | Why |
| --- | --- | --- |
| `~/.profile` | `env.sh`, host `env.sh` | `sh`, GDM and other desktop logins, bash login fallback |
| `~/.bash_profile` | `~/.profile`, then `~/.bashrc` if interactive | Bash login shells read only the first of `.bash_profile`, `.bash_login` and `.profile`, and never read `.bashrc` |
| `~/.bashrc` | `env.sh`, host `env.sh`, then guard, `interactive.sh`, `rc.bash`, host files | Env before the guard covers `ssh host cmd` |
| `~/.zshenv` | `env.sh`, host `env.sh` | Every zsh, including `zsh -c`, scripts and Claude Code |
| `~/.zprofile` | `env.sh`, host `env.sh` (again) | Restores `PATH` order after macOS `path_helper` |
| `~/.zshrc` | `interactive.sh`, `rc.zsh`, host files, load-last hook | Interactive zsh only |

### Block format

```sh
# >>> dotfiles v1 >>> managed by `dotfiles init`; do not edit inside
DOTFILES_DIR="$HOME/.dotfiles"   # repo path, written by init
[ -r "$DOTFILES_DIR/sh/env.sh" ] && . "$DOTFILES_DIR/sh/env.sh"
# <<< dotfiles <<<
```

### Rules

1. The block is the first non-shebang content in the file; `init` creates the file if it is missing. On Linux, if the file matches a known distro skeleton, `init` backs it up to `~/.bashrc.dist` and leaves the local section empty; `doctor` warns if a skeleton appears later.
2. Every source is conditional, so a missing or moved repo never breaks a login.
3. The version in the opening marker lets `init` upgrade blocks in place and `doctor` flag stale ones.
4. `init` is idempotent: it replaces an existing block between markers and never adds a second.
5. `uninstall` removes only the text between and including the markers.

## Load-last handling

Anything that must load after the whole rc file runs from a one-shot hook at the first prompt, so lines appended below the block cannot get in front of it.

**zsh:** `rc.zsh` registers a `precmd` function that sources `load-last.zsh` (zsh-syntax-highlighting, autosuggestions) and then removes itself.

```zsh
_dotfiles_load_last() {
  source "$DOTFILES_DIR/zsh/load-last.zsh"
  add-zsh-hook -d precmd _dotfiles_load_last
  unfunction _dotfiles_load_last
}
autoload -Uz add-zsh-hook
add-zsh-hook precmd _dotfiles_load_last
```

**bash:** the same pattern with a self-removing entry in `PROMPT_COMMAND`, used only if a bash tool needs it.

Deferred items never run in non-interactive shells, which is the intended behavior.

## Machine profiles

Per-machine settings that should be versioned live in `hosts/<profile>/`, and each machine names its profile explicitly in one unversioned file.

- **Selector:** `~/.config/dotfiles/host` holds one line, the profile name. Hostnames are not used: macOS hostnames can change with the network.
- **Sharing:** several machines may name the same profile.
- **Files:** `env.sh`, `interactive.sh`, `rc.bash`, `rc.zsh`, each optional. Each is sourced right after the shared file of the same layer, so it can override it.
- **No profile:** if the selector is missing or names no directory, host files are skipped silently.
- **Unversioned changes:** anything below the injected block in a machine's entry file stays local and unreported, except through `doctor`.
- **Secrets:** never in `hosts/`. Keep them below the block, or in a gitignored file the host layer sources.

## Layer authoring rules

The env layer must be safe to run anywhere, any number of times; the interactive layers may be richer but never run outside a prompt.

**Env layer (`env.sh`, host `env.sh`, `os/*.sh`)**

- POSIX `sh` only, so `sh`, bash and zsh can all source it.
- Idempotent: `_df_path_prepend` dedupes and moves an entry to the front, so double sourcing is harmless.
- Silent: no output on stdout or stderr, except in trace mode.
- Fast: no `eval` of tool init, no subprocesses beyond `uname` (cached in `DOTFILES_OS`).
- Exports only: variables and `PATH`; no aliases or shell options. The only functions are the `lib.sh` helpers, prefixed `_df_`.
- Version managers through shims (mise or similar), never by sourcing nvm.

**Interactive layers**

- Shared `interactive.sh` is POSIX: aliases and simple functions both shells accept.
- Shell-specific code (options, completion, keybinds, prompt) goes only in `rc.bash` or `rc.zsh`.
- Guarded on `$-` containing `i`.
- Detect tools, not OS: `_df_has fdfind && alias fd=fdfind`.
- Tool init output (starship, zoxide, fzf) is cached under `~/.cache/dotfiles/` and regenerated when the tool binary changes.
- `compinit` uses its cache (`-C`) and rebuilds `.zcompdump` at most once a day.
- A missing tool is skipped quietly; it never prints an error at startup.
- No aliases or functions that shadow builtins or common commands (`cd`, `ls`, `cat`, `grep`, `find`); use distinct names such as `z`, `ll` and `bat`.
- Human-only conveniences sit in a section of `interactive.sh` that is skipped when an agent is detected (`CLAUDECODE=1` for Claude Code; verify the variable on install).

## CLI

A single POSIX `sh` script, `bin/dotfiles`, with six commands. None edits entry-file content outside the markers, and only `install` acts outside your home directory.

| Command | Does |
| --- | --- |
| `init [--profile NAME]` | Writes the selector, writes the repo path into every block, injects or upgrades blocks, creates missing entry files, builds caches, runs `sync-env` on Linux. Reports missing tools; never installs anything. |
| `install [--yes]` | Installs tools from `packages.toml` (see below). Dry run without `--yes`. |
| `doctor [--diff]` | Reports health and drift for each entry file (see Doctor checks). Exit code is non-zero on any error. |
| `sync-env` | Linux only: writes `~/.config/environment.d/dotfiles.conf` from the variables `env.sh` and the host `env.sh` export. Takes effect at next login. |
| `test [--profile]` | Runs the matrix locally (see Testing); `--profile` adds a zsh startup profile. |
| `uninstall` | Removes every block and `environment.d/dotfiles.conf`. Leaves the selector, caches and machine content. |

### Install command

`dotfiles install` installs tools; it is the only command that touches package managers or uses `sudo`.

- **Package list:** a declarative `packages.toml`, one logical name per tool mapped to each manager's package name (for example `fd` is `fd-find` on apt, `fd` on brew and pacman).
- **Profiles:** a shared list plus optional additions in `hosts/<profile>/packages.toml`.
- **Managers:** detects brew, apt, dnf or pacman. Prefers cross-platform installers (mise for runtimes, brew on macOS) to keep the mapping small.
- **Safety:** dry run by default; `--yes` applies.
- **First run:** `dotfiles init && dotfiles install --yes`.

### Doctor checks

- **Error:** block missing, block not first in the file, or more than one block.
- **Error:** `DOTFILES_DIR` does not resolve, or a sourced file is missing.
- **Warning:** block version older than the repo's.
- **Warning:** selector missing, or it names a profile with no directory.
- **Warning:** `environment.d/dotfiles.conf` is older than `env.sh` or the host `env.sh`.
- **Warning:** an alias or function shadows a builtin or common command.
- **Warning:** a distro skeleton appears below a block.
- **Info:** a required tool from `packages.toml` is missing.
- **Report:** the content below each block, printed per file, so local additions are visible when something conflicts. With `--diff`, compared against the last run's snapshot in `~/.cache/dotfiles/`.

## Testing

A trace mode plus a matrix script prove which files load in each shell; CI runs it on both operating systems for every push.

**Trace mode:** with `DOTFILES_TRACE=1`, every repo file appends its name to stderr as it loads. Off by default; a single variable test per file when off.

**Matrix:** `test/matrix.sh` runs each invocation in a scratch `HOME` with blocks injected, captures the trace, and asserts the expected files and `PATH` entries.

| Invocation | Expected layers |
| --- | --- |
| `sh -c` (with `ENV` unset) | none |
| `sh -lc` | env |
| `bash -c` | none |
| `bash -lc` | env |
| `bash -ic` | env, interactive, bash |
| `bash -lic` | env, interactive, bash |
| `zsh -c` | env |
| `zsh -lc` | env (twice, idempotent) |
| `zsh -ic` | env, interactive, zsh |
| `zsh -lic` | env, interactive, zsh |

**Extra assertions**

- `PATH` has no duplicates and the repo's entries come before system ones, on macOS too.
- No output on stdout from any non-interactive invocation.
- `env -i HOME=… zsh -c` still gets the env layer.
- A block with a missing repo produces no error.
- Startup time for `zsh -ic exit` stays under 100 ms, the median of 10 runs with `hyperfine`. CI warns above 100 ms and fails above 200 ms, since shared runners are noisy. `dotfiles test --profile` loads `zsh/zprof` to show what is slow.

**CI:** GitHub Actions on `ubuntu-latest` and `macos-latest`, running `dotfiles test`.

## Out of scope and decisions

**Out of scope for v1:** Windows and WSL; shells beyond bash, zsh and POSIX `sh` (fish, nushell); non-shell config such as git, tmux and vim, which can reuse the same `init` later.

**Decisions** (all former open questions are resolved)

| Question | Decision | Where |
| --- | --- | --- |
| Distro skeleton `~/.bashrc` | Replace on first `init`, backed up to `~/.bashrc.dist` | Injection blocks |
| Startup time budget | 100 ms median for `zsh -ic exit`; CI warns at 100, fails at 200 | Testing |
| GUI environment, Linux | Keep the `~/.profile` block and also generate `environment.d` | CLI |
| GUI environment, macOS | Not supported in v1; `launchctl setenv` with a LaunchAgent is the escape hatch | — |
| Tool installation | Separate `install` command with `packages.toml` | CLI |
| Repo location | Any path; `init` writes it into the blocks; default `~/.dotfiles` | Repository layout |
| Agent shells (Claude Code snapshot) | No aliases that shadow commands, plus an agent guard | Layer authoring rules |
