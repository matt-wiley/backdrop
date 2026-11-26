# sh/env.sh: environment. Sourced by every shell, interactive or not:
# terminals, scripts, `ssh host cmd`, agents. Put PATH entries and exported
# variables here; everything else goes in zsh/rc.zsh or bash/rc.bash.
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

# PATH: each prepend goes in front of the ones before it, so this list runs
# from lowest to highest priority. A profile's env.sh loads after this file,
# so its entries come first of all.

# OS directories first, so your own directories end up ahead of them.
case $DOTFILES_OS in
  darwin)
    # /etc/zprofile runs path_helper after ~/.zshenv, which is why ~/.zprofile
    # sources env.sh again: these prepends then land back in front.
    _df_path_prepend /usr/local/bin
    _df_path_prepend /opt/homebrew/bin
    ;;
  linux) ;;
esac

_df_path_prepend "$HOME/.local/share/mise/shims"
_df_path_prepend "$HOME/.local/bin"

# Environment variables.
# export EDITOR=vim
