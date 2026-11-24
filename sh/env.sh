# sh/env.sh: layer 1, environment. Sourced by every shell, interactive or not.
# Rules: POSIX sh, idempotent, silent, exports only, no subprocess beyond uname.

. "$DOTFILES_DIR/sh/lib.sh"
_df_trace sh/env.sh

# OS, detected once and cached for child shells.
if [ -z "${DOTFILES_OS-}" ]; then
  case $(uname -s) in
    Darwin) DOTFILES_OS=darwin ;;
    *) DOTFILES_OS=linux ;;
  esac
  export DOTFILES_OS
fi
if [ -r "$DOTFILES_DIR/sh/os/$DOTFILES_OS.sh" ]; then
  . "$DOTFILES_DIR/sh/os/$DOTFILES_OS.sh"
fi

# zsh: Ubuntu's /etc/zsh/zshrc runs its own uncached compinit unless this is
# set before it, in ~/.zshenv. rc.zsh runs compinit with a cache instead.
# A plain shell variable, harmless in sh and bash.
skip_global_compinit=1

# Machine profile, named in an unversioned selector file. Not exported:
# every shell re-reads it through its own block.
DOTFILES_PROFILE=
if [ -r "$HOME/.config/dotfiles/host" ]; then
  read -r DOTFILES_PROFILE <"$HOME/.config/dotfiles/host" || :
fi

# PATH: last prepend wins, so list from lowest to highest priority.
_df_path_prepend "$HOME/.local/share/mise/shims"
_df_path_prepend "$HOME/.local/bin"

# Environment variables.
# export EDITOR=vim
