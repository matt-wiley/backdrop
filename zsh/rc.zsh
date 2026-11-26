# zsh/rc.zsh: everything for interactive zsh that scripts don't need:
# aliases, functions, options, completion, keybinds, prompt, tool init and
# plugins. Sourced from the ~/.zshrc block; a profile's rc.zsh loads after it.
[[ -o interactive ]] || return 0
_df_trace zsh/rc.zsh

# Aliases and functions. Never shadow builtins or common commands
# (cd, ls, cat, grep, find); use distinct names.
alias ll='ls -lh'
alias la='ls -lAh'
_df_has fdfind && alias fd=fdfind
_df_has batcat && alias bat=batcat

# Human-only conveniences: skipped in agent shells (Claude Code sets CLAUDECODE=1).
if [[ ${CLAUDECODE-} != 1 ]]; then
  :
fi

# History and options.
setopt append_history share_history hist_ignore_dups
HISTFILE=${HISTFILE:-$HOME/.zsh_history}
HISTSIZE=10000
SAVEHIST=10000

# Completion functions must be on fpath before this point.
# Completion: use the cached dump; rebuild it at most once a day.
autoload -Uz compinit
_df_zcompdump=${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles/zcompdump
[[ -d ${_df_zcompdump:h} ]] || mkdir -p ${_df_zcompdump:h}
_df_fresh=( $_df_zcompdump(N.mh-24) )
if (( $#_df_fresh )); then
  compinit -C -d $_df_zcompdump
else
  compinit -i -d $_df_zcompdump
fi
unset _df_zcompdump _df_fresh

# TODO: keybinds, prompt, cached tool init (starship, zoxide, fzf).

# Plugins that must load last (zsh-syntax-highlighting, autosuggestions).
# They're sourced once, at the first prompt, after everything below the
# ~/.zshrc block. List the places a plugin may live, separated by ':'; the
# first one that exists is used. A profile's rc.zsh can add entries with
# _df_load_last+=(...).
_df_load_last=(
  # /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh:/usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
  # /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh:/usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
)
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
