# bash/rc.bash
#
# Settings for interactive bash: the shells you type into. Put aliases,
# functions, shell options, completion, key bindings, the prompt and tool
# setup here.
#
# Scripts never load this file. Anything a script needs, such as a PATH entry
# or an exported variable, belongs in sh/env.sh instead, which every shell
# loads.
#
# The block at the top of ~/.bashrc loads this file. Your profile's rc.bash
# (hosts/<profile>/rc.bash) loads right after it, so the profile can change or
# remove anything defined here.

# Stop here unless this shell is interactive. $- lists the shell's option
# letters, and "i" means interactive. The ~/.bashrc block already checks this,
# but the check here keeps the file safe if anything else sources it, such as a
# script running `. ~/.bashrc`: a script given these aliases and options could
# behave differently from how it was written.
case $- in *i*) ;; *) return 0 ;; esac

# With DOTFILES_TRACE=1, print this file's name as it loads, so you can see
# which files a shell reads: DOTFILES_TRACE=1 bash -ic exit
_df_trace bash/rc.bash

# --- Aliases and functions ---------------------------------------------------
#
# Use new names (ll, la) rather than redefining real commands (ls, cat, grep,
# cd). Scripts and coding agents run commands in shells too, and expect each
# command to behave the standard way. `dotfiles doctor` warns about any alias
# or function that redefines one.
alias ll='ls -lh'
alias la='ls -lAh'

# Debian and Ubuntu install fd and bat as fdfind and batcat, because other
# packages already use the shorter names. These aliases give you the usual
# names, and only when the renamed command is installed, so nothing changes on
# systems that use the normal names.
_df_has fdfind && alias fd=fdfind
_df_has batcat && alias bat=batcat

# Conveniences for people only. Claude Code sets CLAUDECODE=1 in the shells it
# starts, and anything here is skipped in those shells: an agent reads command
# output literally, so greetings, decorated output or changed command behavior
# would confuse it.
if [ "${CLAUDECODE-}" != 1 ]; then
  :
fi

# --- History and window size -------------------------------------------------
#
# histappend: add to the history file when a shell exits, instead of
#   overwriting it, so several open terminals don't erase each other's history.
# checkwinsize: re-read the window size after each command, so long lines wrap
#   correctly after you resize the terminal.
shopt -s histappend checkwinsize

# Leave a command out of history when it repeats the one before it, or when it
# starts with a space. Starting a command with a space is a quick way to keep
# something sensitive, such as a token, out of the history file.
HISTCONTROL=ignoreboth

# HISTSIZE is how many commands a running shell remembers; HISTFILESIZE is how
# many the history file keeps between sessions.
HISTSIZE=10000
HISTFILESIZE=20000

# TODO: completion (bash-completion), prompt, and tool setup (starship, zoxide,
# fzf) with its output cached, so each new shell doesn't have to run the tools.
