# Dotfiles system spec

Nov 6, 2026 · updated Nov 25, 2026 to match the implementation · @Matt Wiley

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
| Shell | bash, zsh, POSIX `sh` | File names, syntax, completion and option systems | The env layer is POSIX `sh`; each shell has one interactive file |

## Architecture

Settings are split by one question, whether a script would need them, into two layers: environment and interactive. Environment is shared by every shell; interactive config is one file per shell. Each layer has a shared file and an optional profile file that loads right after it. Each shell entry file carries only a small injected block that routes into those layers.

```
entry file          block loads                                   layer
~/.profile      ─┐
~/.zshenv       ─┤
~/.zprofile     ─┼─> sh/env.sh, host env.sh                       env, every shell
~/.bashrc       ─┘
~/.bashrc  (if interactive) ─> bash/rc.bash, host rc.bash         interactive bash
~/.zshrc                    ─> zsh/rc.zsh, host rc.zsh            interactive zsh
~/.bash_profile ─> ~/.profile, then ~/.bashrc if interactive
```

Every shell path reaches the env layer; only interactive shells reach their rc file. `~/.bash_profile` reaches the layers through `~/.profile` and `~/.bashrc`.

An earlier design had a third, shared interactive layer (`sh/interactive.sh`), separate OS files (`sh/os/*.sh`) and a separate `zsh/load-last.zsh`. They were folded in because ten possible places for an edit made it hard to know where one belonged; the cost is that an alias wanted in both bash and zsh is written in both rc files.

## Repository layout

The repo holds layers, per-shell code, machine profiles and the CLI; it holds no copies of `~/.zshrc` or `~/.bashrc`.

```
dotfiles/
  bin/dotfiles              # CLI: init, install, doctor, sync-env, test, uninstall, version
  packages.toml             # tool list for `install`
  sh/
    env.sh                  # environment, every shell (POSIX); OS differences in a case
    lib.sh                  # internal helpers: _df_path_prepend, _df_has, _df_trace
  bash/rc.bash              # interactive bash
  zsh/rc.zsh                # interactive zsh, including the load-last plugin list
  hosts/
    example/                # sample profile
    <profile>/env.sh        # versioned machine overrides, all optional
    <profile>/rc.bash
    <profile>/rc.zsh
    <profile>/packages.toml
  blocks/                   # templates for the injected blocks, one per entry file
    README.md               # template-to-file map and versioning rule
  test/
    matrix.sh               # load matrix
    init.sh uninstall.sh doctor.sh sync-env.sh install.sh   # CLI suites
    faults.sh               # broken layers must be caught
    lib.sh                  # helpers shared by the CLI suites
  .github/workflows/test.yml      # tests on every push and pull request
  .gitignore                # keeps host secrets files out of the repo
```

All paths inside the repo are resolved from `DOTFILES_DIR`, which each injected block sets. `init` resolves the repo's own location, following symlinks to `bin/dotfiles`, and writes it into every block: as `$HOME/...` when the repo is inside the home directory, otherwise as an absolute path. The default clone path is `~/.dotfiles`. Moving the repo means re-running `init`; `doctor` warns when a block points somewhere else.

## Injection blocks

Each shell entry file gets one marked block at its very top; everything below the block belongs to the machine and is never read or edited by the tool, except as the rules below allow.

| Entry file | Block sources, in order | Why |
| --- | --- | --- |
| `~/.profile` | `env.sh`, host `env.sh` | `sh`, GDM and other desktop logins, bash login fallback |
| `~/.bash_profile` | `~/.profile`, then `~/.bashrc` if interactive | Bash login shells read only the first of `.bash_profile`, `.bash_login` and `.profile`, and never read `.bashrc` |
| `~/.bashrc` | `env.sh`, host `env.sh`, then guard, `rc.bash`, host `rc.bash` | Env before the guard covers `ssh host cmd` |
| `~/.zshenv` | `env.sh`, host `env.sh` | Every zsh, including `zsh -c`, scripts and Claude Code |
| `~/.zprofile` | `env.sh`, host `env.sh` (again) | Restores `PATH` order after macOS `path_helper` |
| `~/.zshrc` | `rc.zsh`, host `rc.zsh` | Interactive zsh only; `rc.zsh` registers the load-last hook |

Each host file loads right after the shared file of the same layer, so it can override it.

### Block format

Templates in `blocks/` hold `@DOTFILES_DIR@`, which `init` replaces with the repo path. The `~/.profile` block:

```sh
# >>> dotfiles v2 >>> managed by `dotfiles init`; do not edit inside
DOTFILES_DIR="$HOME/.dotfiles"   # repo path, written by init
[ -r "$DOTFILES_DIR/sh/env.sh" ] && . "$DOTFILES_DIR/sh/env.sh"
[ -r "$DOTFILES_DIR/hosts/${DOTFILES_PROFILE-}/env.sh" ] && . "$DOTFILES_DIR/hosts/${DOTFILES_PROFILE-}/env.sh"
# <<< dotfiles <<<
```

### Rules

1. The block is the first non-shebang content in the file, followed by one blank line before the machine content. `init` creates the file if it is missing.
2. On Linux, if an entry file is byte-for-byte identical to its copy in `/etc/skel`, `init` backs it up to `<file>.dist` and leaves the local section empty. This applies to every entry file, not only `.bashrc`: Ubuntu's skeleton `.profile` sources `.bashrc`, which would load it twice in interactive bash login shells. `doctor` warns if a skeleton appears later.
3. Every source is conditional, so a missing or moved repo never breaks a login.
4. The version in the opening marker lets `init` upgrade blocks in place and `doctor` flag stale ones.
5. `init` is idempotent: it removes every existing block, wherever it is in the file, and writes one current block at the top. A second run changes nothing. A file with an unterminated or nested block is left untouched, and `init` exits non-zero.
6. `uninstall` removes the text between and including the markers, plus the blank line `init` adds after the block, so `init` followed by `uninstall` restores a file byte for byte. A file left with nothing but the block is deleted, or restored from its `.dist` backup if one exists; an empty `~/.bash_profile` would otherwise hide `~/.profile` from bash login shells. If content was added below the block, the `.dist` backup is kept for a manual merge.
7. Entry files that are symlinks are edited through the link; the link stays.
8. `init` warns if `~/.bash_login` exists, since the `~/.bash_profile` it creates stops bash from reading it.

## Load-last handling

Anything that must load after the whole rc file runs from a one-shot hook at the first prompt, so lines appended below the block cannot get in front of it.

**zsh:** `rc.zsh` defines the `_df_load_last` array of plugin paths (zsh-syntax-highlighting, autosuggestions) and registers a `precmd` function that sources them and then removes itself. Each entry lists the places a plugin may live, separated by `:`; the first readable one is sourced. A profile's `rc.zsh` loads before the first prompt, so it can append entries.

```zsh
_dotfiles_load_last() {
  local entry f
  for entry in $_df_load_last; do
    for f in ${(s.:.)entry}; do
      if [[ -r $f ]]; then source $f; break; fi
    done
  done
  unset _df_load_last
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

- **Selector:** `~/.config/dotfiles/host` holds one line, the profile name. Hostnames are not used: macOS hostnames can change with the network. `env.sh` reads it into `DOTFILES_PROFILE`, an unexported shell variable the blocks use to find host files.
- **Names:** a profile name may not contain `/` or start with `-`.
- **Sharing:** several machines may name the same profile.
- **Files:** `env.sh`, `rc.bash`, `rc.zsh`, each optional. Each is sourced right after the shared file of the same layer, so it can override it.
- **No profile:** if the selector is missing or names no directory, host files are skipped silently.
- **Unversioned changes:** anything below the injected block in a machine's entry file stays local and unreported, except through `doctor`.
- **Secrets:** never in `hosts/`. Keep them below the block, or in a gitignored file the host layer sources; `.gitignore` already excludes `hosts/*/*.local.sh` and `hosts/*/secrets*`.

## Layer authoring rules

The env layer must be safe to run anywhere, any number of times; the interactive layers may be richer but never run outside a prompt.

**Env layer (`env.sh`, host `env.sh`)**

- POSIX `sh` only, so `sh`, bash and zsh can all source it.
- Idempotent: `_df_path_prepend` dedupes and moves an entry to the front, so double sourcing is harmless.
- Silent: no output on stdout or stderr, except in trace mode.
- Fast: no `eval` of tool init, no subprocesses beyond `uname` (cached in the exported `DOTFILES_OS`).
- Exports only: variables and `PATH`; no aliases or shell options. The only functions are the `lib.sh` helpers, prefixed `_df_`.
- Version managers through shims (mise or similar), never by sourcing nvm.

- OS differences sit in one `case $DOTFILES_OS` near the top of the `PATH` section, so OS directories land behind the repo's own.

**Interactive layer (`rc.bash`, `rc.zsh`, host files)**

- Everything a script doesn't need: aliases, functions, options, completion, keybinds, prompt, tool init and plugins. Each file uses its shell's full syntax.
- Guarded on `$-` containing `i`.
- Detect tools, not OS: `_df_has fdfind && alias fd=fdfind`.
- Tool init output (starship, zoxide, fzf) is cached under `~/.cache/dotfiles/` and regenerated when the tool binary changes.
- `compinit` uses its cache (`-C`) and rebuilds the dump, `~/.cache/dotfiles/zcompdump`, at most once a day. `env.sh` sets `skip_global_compinit=1` (a plain shell variable, not exported) so Ubuntu's `/etc/zsh/zshrc` doesn't run a second, uncached `compinit`; without it, that `compinit` roughly doubled zsh startup and aborted with an error on systems whose completion directories it considers insecure.
- A missing tool is skipped quietly; it never prints an error at startup.
- No aliases or functions that shadow builtins or common commands (`cd`, `ls`, `cat`, `grep`, `find`); use distinct names such as `z`, `ll` and `bat`.
- Human-only conveniences sit in a section of each rc file that is skipped when an agent is detected (`CLAUDECODE=1` for Claude Code; verify the variable on install).

## CLI

A single POSIX `sh` script, `bin/dotfiles`, with seven commands, each accepting `-h` or `--help`. Only `init` and `uninstall` edit entry files, and outside the markers they change only what the injection rules allow: the blank line after the block, skeleton replacement, and deleting or restoring files left empty. Only `install` acts outside your home directory. Where the paths below name `~/.config` or `~/.cache`, the CLI honors `XDG_CONFIG_HOME` and `XDG_CACHE_HOME`.

| Command | Does |
| --- | --- |
| `init [--profile NAME]` | Writes the selector (with `--profile`; otherwise keeps it), writes the repo path into every block, injects or upgrades blocks, creates missing entry files, creates the cache directory, runs `sync-env` on Linux. Reports every missing tool; never installs anything. Exits non-zero if an entry file is skipped or `sync-env` fails. |
| `install [--yes] [--manager NAME]` | Installs missing tools from `packages.toml` (see below). Dry run without `--yes`. |
| `doctor [--diff]` | Reports health and drift for each entry file (see Doctor checks). Exit code is non-zero on any error. |
| `sync-env` | Linux only; an error on macOS. Writes `~/.config/environment.d/dotfiles.conf` from the variables the `~/.profile` block exports (see below). Takes effect at next login. |
| `test [--profile]` | Runs the CLI test suites, then the matrix (see Testing) with this machine's profile; `--profile` adds a zsh startup profile. |
| `uninstall` | Removes every block (see injection rule 6) and `environment.d/dotfiles.conf`. Leaves the selector, caches and machine content, and says so. |
| `version` | Prints the git commit the repo is on, marked `-dirty` when there are uncommitted changes. Also `--version`. |

### Install command

`dotfiles install` installs tools; it is the only command that touches package managers or uses `sudo`.

- **Package list:** a declarative `packages.toml`, one table per logical tool, mapping each manager to its package name (for example `fd` is `fd-find` on apt, `fd` on brew and pacman). Optional keys:
  - `bin`: the commands that count as installed, any one of them; defaults to the tool's name (for example `bin = "fd fdfind"`).
  - `required = true`: `doctor` reports the tool when it is missing.
  - `mise = "SPEC"`: install with `mise use -g SPEC` instead of the package manager; for runtimes, such as `mise = "node@lts"`.
- **Profiles:** a shared list plus `hosts/<profile>/packages.toml`. A table there adds a tool, or replaces the shared table of the same name.
- **Managers:** Homebrew on macOS (if it is missing, `install` points to brew.sh); apt, dnf or pacman on Linux, then Homebrew. `--manager NAME` overrides detection. System managers run through `sudo` when not root; brew never does.
- **Commands:** all missing packages go in one install command (apt runs `apt-get update` first), then `mise use -g` for each mise tool, after mise itself if it is being installed. Mise tools are skipped with a warning when mise is unavailable.
- **Safety:** dry run by default, printing the plan and the exact commands; `--yes` applies. After applying, `install` warns when a tool's commands still aren't on `PATH`, and exits non-zero if a manager command fails.
- **First run:** `dotfiles init && dotfiles install --yes`.

### Doctor checks

- **Error:** entry file missing, block missing, block not first (the first line that is neither blank nor a shebang isn't the opening marker), more than one block, or an unterminated or nested block.
- **Error:** `DOTFILES_DIR` does not exist, or a file the block always sources is missing, including `sh/lib.sh`, which `env.sh` needs.
- **Error:** a layer file doesn't parse (`-n`) in a shell that loads it: the env layer files in `sh`, bash and zsh; each rc file in its own shell. The selected profile's files are checked too. Shells that aren't installed are skipped.
- **Warning:** block version older or newer than the repo's.
- **Warning:** block edited inside the markers (it differs from what `init` would write), or `DOTFILES_DIR` points at a different copy of the repo.
- **Warning:** selector missing, or it names a profile with no directory.
- **Warning:** on Linux, `environment.d/dotfiles.conf` is older than `env.sh` or the host `env.sh`. **Info** if it has not been generated yet.
- **Warning:** an alias or function shadows a builtin or common command. `doctor` starts interactive bash and zsh and compares their aliases and functions against each shell's builtins and a fixed list of common commands, so definitions from below the block and from `/etc` count too. A warning also if this check cannot run.
- **Warning:** on Linux, a distro skeleton's full text appears below a block.
- **Info:** a required tool from `packages.toml` is missing.
- **Report:** the content below each block, printed per file, so local additions are visible when something conflicts. Every run saves a snapshot in `~/.cache/dotfiles/doctor/`; with `--diff`, only the changes since the last snapshot are printed.

### Sync-env command

- **Source:** runs the real `~/.profile` block in a clean `sh`, with only `HOME`, `USER`, `LOGNAME` and systemd's default `PATH`, and compares the exported variables before and after. New or changed variables are written; `DOTFILES_OS` is among them.
- **Lists:** `PATH`, and any colon-separated variable that keeps all its old entries, is written as `NEW:ENTRIES:${NAME}`, so it extends the session's value.
- **Literal values only:** systemd expands `$` in `environment.d` even when escaped. Values containing `$`, `\`, quotes, backticks or newlines, or with whitespace at either end, are skipped with a warning.
- **Freshness:** the file is rewritten every run, so removed variables disappear; an unchanged file gets a new timestamp so `doctor` sees it as current.
- **Failures:** if the env layer fails, the previous file is kept and the command exits non-zero; if the env layer prints anything, it warns but still writes the file.

## Testing

A trace mode plus a matrix script prove which files load in each shell, and CLI suites cover each command; CI runs them on both operating systems for every push.

**Trace mode:** with `DOTFILES_TRACE=1`, every repo file appends its name to stderr as it loads. Off by default; a single variable test per file when off.

**Matrix:** `test/matrix.sh` runs each invocation under `env -i` in a scratch `HOME` with blocks injected by `init`, with a probe command (`echo @df@ran`). It captures stdout, stderr and the trace, and asserts the expected layers and `PATH` entries. It loads a host profile too: `DOTFILES_TEST_PROFILE`, which `dotfiles test` sets to this machine's profile, or `example`. If `init` fails but writes the blocks (as when `sync-env` meets a broken env layer), the matrix records the failure and still tests every shell.

| Invocation | Expected layers |
| --- | --- |
| `sh -c` (with `ENV` unset) | none |
| `sh -lc` | env |
| `bash -c` | none |
| `bash -lc` | env |
| `bash -ic` | env, bash |
| `bash -lic` | env (twice, idempotent), bash |
| `zsh -c` | env |
| `zsh -lc` | env (twice, idempotent) |
| `zsh -ic` | env, zsh |
| `zsh -lic` | env (twice, idempotent), zsh |

**Extra assertions**

- `PATH` has no duplicates and the repo's entries come before system ones, on macOS too.
- The probe command runs in every invocation, so no layer exits or stops the shell.
- No output on stdout from any non-interactive invocation, other than the probe's.
- Nothing on stderr but trace lines and bash's notices about running without a terminal, so syntax errors, failing commands and noise all fail the matrix.
- `env -i HOME=… zsh -c` still gets the env layer; every matrix row runs under `env -i`, so the `zsh -c` row covers it.
- A block with a missing repo produces no error.
- Startup time for `zsh -ic exit` stays under 100 ms, the median of 10 runs with `hyperfine`. CI warns above 100 ms and fails above 200 ms, since shared runners are noisy. `dotfiles test --profile` loads `zsh/zprof` to show what is slow.

**CLI suites:** `test/init.sh`, `test/uninstall.sh`, `test/doctor.sh`, `test/sync-env.sh` and `test/install.sh` run each command against scratch home directories holding a copy of the repo at `~/.dotfiles`. `test/faults.sh` breaks one layer file at a time in a copy (an `exit`, a syntax error, a failing command, output), and checks that the matrix fails and that `doctor` reports syntax errors.

- `install` runs against fake package managers and a fake `sudo` that only log their arguments; nothing is installed.
- On Linux, `sync-env` output is also read back with systemd's own `environment.d` generator when it is present.
- The suites unset `XDG_CONFIG_HOME` and `XDG_CACHE_HOME`, so they never touch the real `~/.config` or `~/.cache`.
- A failed check prints the CLI output it was checking.

**CI:** GitHub Actions on `ubuntu-latest` and `macos-latest`, running `dotfiles test` on every push to a branch and every pull request. The Ubuntu job installs zsh first. Linux-only checks (skeletons, `environment.d`, `sync-env`) are skipped on macOS.

## Out of scope and decisions

**Out of scope for v1:** Windows and WSL; shells beyond bash, zsh and POSIX `sh` (fish, nushell); non-shell config such as git, tmux and vim, which can reuse the same `init` later.

**Decisions** (all former open questions are resolved)

| Question | Decision | Where |
| --- | --- | --- |
| Distro skeletons | Replace on first `init`, any entry file, backed up to `<file>.dist`; `uninstall` restores the backup when nothing was added | Injection blocks |
| Uninstall beyond the markers | Delete files left with only the block, or restore their `.dist`; never leave an empty `~/.bash_profile` | Injection blocks |
| Startup time budget | 100 ms median for `zsh -ic exit`; CI warns at 100, fails at 200 | Testing |
| GUI environment, Linux | Keep the `~/.profile` block and also generate `environment.d` | CLI |
| `environment.d` values that need `$` | Skip with a warning; they cannot be written literally | Sync-env command |
| GUI environment, macOS | Not supported in v1; `launchctl setenv` with a LaunchAgent is the escape hatch | — |
| Tool installation | Separate `install` command with `packages.toml`; runtimes through a `mise` key | CLI |
| Repo location | Any path; `init` writes it into the blocks; default `~/.dotfiles` | Repository layout |
| Installing without git | Not supported: the repo is meant to be edited and versioned, so every machine uses a git clone. An earlier design shipped versioned ZIP releases with a curl-piped `install.sh`; they were removed because upgrades overwrote local edits | Repository layout |
| Agent shells (Claude Code snapshot) | No aliases that shadow commands, plus an agent guard | Layer authoring rules |

## Implementation status

Everything above is implemented except:

- **Caches:** tool init output for starship, zoxide and fzf is not generated or cached; `init` only creates the cache directory.
- **Interactive layer:** `_df_load_last` lists no plugins yet; `rc.bash` and `rc.zsh` have no completion setup beyond `compinit`, prompt or keybinds; the agent-only sections of the rc files are empty, and `install` does not verify `CLAUDECODE`.
- **Testing:**
  - The matrix asserts layers but not `PATH` entries.
  - Not implemented: the `PATH` duplicate and order assertion, the missing-repo assertion, the `hyperfine` startup budget and its CI thresholds.
  - `dotfiles test --profile` is accepted but does nothing.
  - Nothing checks the "no shell options" rule: `set -u` in the env layer leaks into every shell without failing any test.
