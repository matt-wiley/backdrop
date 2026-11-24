# sh/interactive.sh: layer 2, shared interactive config for bash and zsh.
# POSIX aliases and simple functions only. Never shadow builtins or common
# commands (cd, ls, cat, grep, find); use distinct names.
case $- in *i*) ;; *) return 0 ;; esac
_df_trace sh/interactive.sh

alias ll='ls -lh'
alias la='ls -lAh'
_df_has fdfind && alias fd=fdfind
_df_has batcat && alias bat=batcat

# Human-only conveniences: skipped in agent shells (Claude Code sets CLAUDECODE=1).
if [ "${CLAUDECODE-}" != 1 ]; then
  :
fi
