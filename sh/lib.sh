# sh/lib.sh
#
# Helper functions used by every layer. sh/env.sh loads this file first, in
# every shell that reads a startup file.
#
# Every shell loads these functions, so they follow the same rules as env.sh:
# POSIX sh only, no output, and no subprocesses. Their names start with _df_
# so they don't collide with your own functions or other tools'.
#
# A mistake here breaks the environment in every shell. After changing this
# file, run `dotfiles doctor` and `dotfiles test`.

# _df_trace NAME
#
# Prints "dotfiles: NAME" to stderr when DOTFILES_TRACE=1. Each layer file
# calls it with its own name, so `DOTFILES_TRACE=1 zsh -ic exit` lists which
# files a shell loaded, in order.
#
# It always returns success. Without `return 0`, it would fail whenever tracing
# is off, because the test before && is false, and that failure would
# become the exit status of whatever file called it last.
_df_trace() {
  [ "${DOTFILES_TRACE-}" = 1 ] && printf 'dotfiles: %s\n' "$1" >&2
  return 0
}

# _df_has COMMAND
#
# Succeeds if COMMAND can be run: a program on PATH, a builtin or a function.
# Use it to set something up only when a tool is installed, so a machine
# without the tool starts silently instead of printing an error:
#
#   _df_has zoxide && eval "$(zoxide init zsh)"
_df_has() {
  command -v "$1" >/dev/null 2>&1
}

# _df_path_prepend DIRECTORY
#
# Puts DIRECTORY at the front of PATH, so it's searched first.
#
# - If DIRECTORY is already in PATH, it moves to the front instead of
#   appearing twice. That makes the function safe to run any number of times,
#   which matters because login shells load env.sh twice.
# - If DIRECTORY doesn't exist, PATH is left alone. So a line such as
#   `_df_path_prepend /opt/homebrew/bin` can be shared by every machine,
#   including ones without that directory.
# - Empty entries are dropped. An empty entry in PATH means "the current
#   directory", which would let a program in whatever directory you're in
#   take the place of a real command.
#
# It walks PATH with shell string operations rather than tools like sed or tr,
# because those would start a subprocess in every shell. POSIX sh has no local
# variables, so the working variables get unusual names and are removed at the
# end, so they don't linger in your shell.
_df_path_prepend() {
  [ -d "$1" ] || return 0
  _df_new=$1
  _df_rest=$PATH:
  while [ -n "$_df_rest" ]; do
    _df_p=${_df_rest%%:*}   # the next entry: everything before the first ':'
    _df_rest=${_df_rest#*:} # what's left after it
    # Keep the entry unless it's empty or it's the directory being moved.
    [ -z "$_df_p" ] || [ "$_df_p" = "$1" ] || _df_new=$_df_new:$_df_p
  done
  PATH=$_df_new
  export PATH
  unset _df_new _df_rest _df_p
}
