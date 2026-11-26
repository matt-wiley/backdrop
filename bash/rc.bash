# bash/rc.bash: everything for interactive bash that scripts don't need:
# aliases, functions, options, completion, keybinds, prompt and tool init.
# Sourced from the ~/.bashrc block; a profile's rc.bash loads after it.
case $- in *i*) ;; *) return 0 ;; esac
_df_trace bash/rc.bash

# Aliases and functions. Never shadow builtins or common commands
# (cd, ls, cat, grep, find); use distinct names.
alias ll='ls -lh'
alias la='ls -lAh'
_df_has fdfind && alias fd=fdfind
_df_has batcat && alias bat=batcat

# Human-only conveniences: skipped in agent shells (Claude Code sets CLAUDECODE=1).
if [ "${CLAUDECODE-}" != 1 ]; then
  :
fi

# History and options.
shopt -s histappend checkwinsize
HISTCONTROL=ignoreboth
HISTSIZE=10000
HISTFILESIZE=20000

# TODO: completion (bash-completion), prompt, cached tool init (starship, zoxide, fzf).
