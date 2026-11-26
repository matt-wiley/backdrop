# sh/env.sh
#
# The environment: PATH entries and exported variables. Everything else goes
# in zsh/rc.zsh or bash/rc.bash.
#
# This file loads in every shell that reads a startup file, including ones no
# person sees: `zsh -c` run by editors and coding agents, `ssh host cmd`, and
# on Linux the desktop session. That's how tools that start their own shells
# get the same PATH as your terminal. Because it runs so often, and in places
# where a mistake is hard to spot, it follows strict rules:
#
# - POSIX sh only. sh, bash and zsh all load this file, so syntax that only
#   bash or zsh understands, such as [[ ]] or arrays, would break sh.
# - No output. Anything printed here ends up in the output of scripts and
#   commands like `ssh host cmd`, and can break tools that parse it.
# - No subprocesses, such as $(...) or `eval "$(tool init)"`. Each one adds
#   delay to every shell that starts, and many shells start without you
#   seeing them. The one exception is uname, below, which runs once per login.
# - Exports only: no aliases, functions or shell options. Those would change
#   how scripts behave.
# - Safe to run twice. Login shells load this file twice (see ~/.zprofile), so
#   every line must give the same result the second time.
#
# Your profile's env.sh (hosts/<profile>/env.sh) loads right after this file,
# so it can override anything here.

# Load the helper functions this file uses: _df_trace, _df_has and
# _df_path_prepend.
. "$DOTFILES_DIR/sh/lib.sh"

# With DOTFILES_TRACE=1, print this file's name as it loads, so you can see
# which files a shell reads: DOTFILES_TRACE=1 zsh -c exit
_df_trace sh/env.sh

# --- Which operating system --------------------------------------------------
#
# Finding out takes a subprocess (uname), so do it once and export the answer:
# shells started from this one inherit DOTFILES_OS and skip the check.
if [ -z "${DOTFILES_OS-}" ]; then
  case $(uname -s) in
    Darwin) DOTFILES_OS=darwin ;;
    *) DOTFILES_OS=linux ;;
  esac
  export DOTFILES_OS
fi

# --- Completion on Ubuntu ----------------------------------------------------
#
# Ubuntu's system-wide /etc/zsh/zshrc runs compinit itself, without a cache,
# which roughly doubles zsh's startup time and can stop with an error about
# insecure directories. Setting skip_global_compinit before it runs (that is,
# here, which ~/.zshenv loads) tells it not to. zsh/rc.zsh runs compinit with a
# cache instead. sh and bash ignore the variable, and it isn't exported, so it
# doesn't reach other programs.
skip_global_compinit=1

# --- Which profile this machine uses -----------------------------------------
#
# `dotfiles init --profile NAME` writes the profile's name to this file. The
# blocks use DOTFILES_PROFILE to find hosts/<profile>/.
#
# It's deliberately not exported. Each shell reads the file itself (a quick
# builtin read, not a subprocess), so after you switch profiles, every new
# shell uses the new one, even one started from an old terminal that still
# holds the previous name.
#
# `|| :` ignores read's failure when the file has no final newline; the name
# is still read correctly in that case.
DOTFILES_PROFILE=
if [ -r "$HOME/.config/dotfiles/host" ]; then
  read -r DOTFILES_PROFILE <"$HOME/.config/dotfiles/host" || :
fi

# --- PATH --------------------------------------------------------------------
#
# _df_path_prepend puts a directory at the front of PATH. So each call goes in
# front of the ones before it, and this list runs from LOWEST to HIGHEST
# priority: the last directory added is searched first. Your profile's env.sh
# runs after this file, so its directories end up in front of all of these.

# The OS's package directories come first, so that your own directories, added
# after them, are searched before them.
case $DOTFILES_OS in
  darwin)
    # Homebrew: /opt/homebrew on Apple silicon, /usr/local on Intel Macs.
    #
    # On macOS, login shells run /etc/zprofile after ~/.zshenv, and it runs
    # path_helper, which moves the system directories back to the front of
    # PATH. That's why ~/.zprofile loads this file a second time: these
    # directories then go back in front of the system ones.
    _df_path_prepend /usr/local/bin
    _df_path_prepend /opt/homebrew/bin
    ;;
  linux) ;;
esac

# mise installs language runtimes (node, python and so on) and puts small
# launcher programs, called shims, in this directory. Each shim runs the
# runtime version a project asks for. Using shims, rather than running
# `mise activate`, keeps this file free of subprocesses.
_df_path_prepend "$HOME/.local/share/mise/shims"

# Your own commands, and the `dotfiles` command itself, which setup links here.
# Last, so they're found before anything with the same name above.
_df_path_prepend "$HOME/.local/bin"

# --- Environment variables ---------------------------------------------------
#
# For example:
# export EDITOR=vim
