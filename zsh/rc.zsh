# zsh/rc.zsh: layer 3, zsh-only interactive config (options, completion,
# keybinds, prompt). Sourced from the ~/.zshrc block after interactive.sh.
[[ -o interactive ]] || return 0
_df_trace zsh/rc.zsh

setopt append_history share_history hist_ignore_dups
HISTFILE=${HISTFILE:-$HOME/.zsh_history}
HISTSIZE=10000
SAVEHIST=10000

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

# Load-last: runs once at the first prompt, after everything below the
# ~/.zshrc block, then removes itself.
_dotfiles_load_last() {
  [[ -r $DOTFILES_DIR/zsh/load-last.zsh ]] && source $DOTFILES_DIR/zsh/load-last.zsh
  add-zsh-hook -d precmd _dotfiles_load_last
  unfunction _dotfiles_load_last
}
autoload -Uz add-zsh-hook
add-zsh-hook precmd _dotfiles_load_last
