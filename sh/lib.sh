# sh/lib.sh: internal helpers shared by every layer. POSIX sh.
# Only functions live here, all prefixed _df_. No output, no subprocesses.

# _df_trace NAME: print NAME to stderr when DOTFILES_TRACE=1.
_df_trace() {
  [ "${DOTFILES_TRACE-}" = 1 ] && printf 'dotfiles: %s\n' "$1" >&2
  return 0
}

# _df_has CMD: true if CMD is on PATH (or a function/builtin).
_df_has() {
  command -v "$1" >/dev/null 2>&1
}

# _df_path_prepend DIR: move DIR to the front of PATH, dropping duplicates.
# Skips directories that don't exist. Safe to call any number of times.
_df_path_prepend() {
  [ -d "$1" ] || return 0
  _df_new=$1
  _df_rest=$PATH:
  while [ -n "$_df_rest" ]; do
    _df_p=${_df_rest%%:*}
    _df_rest=${_df_rest#*:}
    [ -z "$_df_p" ] || [ "$_df_p" = "$1" ] || _df_new=$_df_new:$_df_p
  done
  PATH=$_df_new
  export PATH
  unset _df_new _df_rest _df_p
}
