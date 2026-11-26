# zsh/rc.zsh
#
# Settings for interactive zsh: the shells you type into. Put aliases,
# functions, shell options, completion, key bindings, the prompt, tool setup
# and plugins here.
#
# Scripts never load this file. Anything a script needs, such as a PATH entry
# or an exported variable, belongs in sh/env.sh instead, which every shell
# loads.
#
# The block at the top of ~/.zshrc loads this file. Your profile's rc.zsh
# (hosts/<profile>/rc.zsh) loads right after it, so the profile can change or
# remove anything defined here.

# Stop here unless this shell is interactive. zsh only reads ~/.zshrc in
# interactive shells, but the check keeps the file safe if anything else
# sources it, such as a script: a script given these aliases and options could
# behave differently from how it was written.
[[ -o interactive ]] || return 0

# With DOTFILES_TRACE=1, print this file's name as it loads, so you can see
# which files a shell reads: DOTFILES_TRACE=1 zsh -ic exit
_df_trace zsh/rc.zsh

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
if [[ ${CLAUDECODE-} != 1 ]]; then
  :
fi

# --- History -----------------------------------------------------------------
#
# append_history: add to the history file instead of overwriting it, so
#   several open terminals don't erase each other's history.
# share_history: commands typed in one terminal show up in the others' history
#   straight away, not only in terminals opened later.
# hist_ignore_dups: don't record a command that repeats the one before it.
setopt append_history share_history hist_ignore_dups

# zsh keeps no history file unless HISTFILE names one. HISTSIZE is how many
# commands a running shell remembers; SAVEHIST is how many the file keeps.
HISTFILE=${HISTFILE:-$HOME/.zsh_history}
HISTSIZE=10000
SAVEHIST=10000

# --- Completion --------------------------------------------------------------
#
# compinit sets up tab completion. To do that it scans every directory in fpath
# for completion functions and checks those directories' permissions, which is
# the slowest part of starting zsh. So it saves what it found to a cache file
# (the "dump") and reuses it: the full scan runs at most once a day.
#
# Add directories of completion functions to fpath ABOVE this section; compinit
# only sees what's on fpath when it runs. A profile's rc.zsh loads after this
# point, so it can't add completion functions.
autoload -Uz compinit
_df_zcompdump=${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles/zcompdump
[[ -d ${_df_zcompdump:h} ]] || mkdir -p ${_df_zcompdump:h}

# Look for a dump modified in the last 24 hours. The glob qualifiers in (...)
# mean: N, give an empty list instead of an error when there's no match; .,
# regular files only; mh-24, modified less than 24 hours ago.
_df_fresh=( $_df_zcompdump(N.mh-24) )
if (( $#_df_fresh )); then
  # A recent dump exists: load it and skip the scan and the permission check
  # (-C). This is the fast path that almost every shell takes.
  compinit -C -d $_df_zcompdump
else
  # No dump, or a stale one: scan fpath and write a new dump. -i skips any
  # directory with unsafe permissions instead of stopping to ask about it, so
  # opening a terminal never waits for an answer.
  compinit -i -d $_df_zcompdump
fi
unset _df_zcompdump _df_fresh

# TODO: key bindings, prompt, and tool setup (starship, zoxide, fzf) with its
# output cached, so each new shell doesn't have to run the tools.

# --- Plugins that must load last ---------------------------------------------
#
# Some plugins only work when they load after everything else.
# zsh-syntax-highlighting is the usual example: it has to wrap every widget
# and key binding, including any defined after it. Loading those plugins at the
# end of this file isn't late enough, because your own lines below the block
# in ~/.zshrc, and lines that installers append there, run after this file.
#
# So they're listed here and loaded once, just before the first prompt, after
# all startup files have run. Each entry lists the places one plugin might be
# installed, separated by ':', because Homebrew and Linux packages put plugins
# in different directories; the first that exists is loaded. A profile's
# rc.zsh can add its own with _df_load_last+=(/path/to/plugin.zsh).
_df_load_last=(
  # /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh:/usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
  # /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh:/usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
)

# Runs just before the first prompt: loads the listed plugins, then removes
# itself, because zsh would otherwise run it before every prompt.
_dotfiles_load_last() {
  local entry f
  for entry in $_df_load_last; do
    # ${(s.:.)entry} splits the entry at each ':' into its possible locations.
    for f in ${(s.:.)entry}; do
      if [[ -r $f ]]; then source $f; break; fi
    done
  done
  unset _df_load_last
  add-zsh-hook -d precmd _dotfiles_load_last
  unfunction _dotfiles_load_last
}

# precmd hooks run just before zsh prints each prompt, so this is the first
# moment after every startup file has finished.
autoload -Uz add-zsh-hook
add-zsh-hook precmd _dotfiles_load_last
