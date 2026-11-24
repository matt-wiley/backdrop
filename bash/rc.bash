# bash/rc.bash: layer 3, bash-only interactive config (options, completion,
# keybinds, prompt). Sourced from the ~/.bashrc block after interactive.sh.
case $- in *i*) ;; *) return 0 ;; esac
_df_trace bash/rc.bash

shopt -s histappend checkwinsize
HISTCONTROL=ignoreboth
HISTSIZE=10000
HISTFILESIZE=20000

# TODO: completion (bash-completion), prompt, cached tool init (starship, zoxide, fzf).
