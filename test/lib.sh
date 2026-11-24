# test/lib.sh: helpers for the CLI tests. Source after setting SUITE.
# Each case gets a scratch HOME with a copy of the repo at $HOME/.dotfiles,
# the default clone path, and its own empty skeleton dir.
set -u

# The CLI honors these; left set, tests would read and write the real
# ~/.config and ~/.cache instead of the scratch HOME's.
unset XDG_CONFIG_HOME XDG_CACHE_HOME

repo=$(cd "$(dirname "$0")/.." && pwd -P)
root=$(mktemp -d)
trap 'rm -rf "$root"' EXIT INT TERM
nfail=0
n=0
H=

pass() { printf 'ok    %s: %s\n' "$SUITE" "$1"; }
fail() {
  printf 'FAIL  %s: %s\n' "$SUITE" "$1"
  nfail=$((nfail + 1))
  # Show the last CLI output once per run of it, to explain the failure.
  if [ -s "$root/out" ] && ! cmp -s "$root/out" "$root/out.shown"; then
    sed 's/^/      > /' "$root/out"
    cp "$root/out" "$root/out.shown"
  fi
}
check() { # check DESCRIPTION COMMAND...
  desc=$1; shift
  if "$@"; then pass "$desc"; else fail "$desc"; fi
}
fails() { ! "$@"; }

fresh() {
  n=$((n + 1))
  H=$root/home$n
  mkdir -p "$H/.dotfiles" "$root/skel$n"
  (cd "$repo" && tar cf - --exclude .git .) | (cd "$H/.dotfiles" && tar xf -)
}
# run_cli COMMAND [ARGS...]: run bin/dotfiles in the scratch HOME; output in $root/out.
run_cli() {
  HOME=$H DOTFILES_SKEL_DIR=$root/skel$n "$H/.dotfiles/bin/dotfiles" "$@" >"$root/out" 2>&1
}
run_init() { run_cli init "$@"; }
run_uninstall() { run_cli uninstall "$@"; }
run_doctor() { run_cli doctor "$@"; }
# out_has PATTERN: true if the last command's output has a line matching PATTERN.
out_has() { grep -qE -- "$1" "$root/out"; }

first_line() { head -n 1 "$1"; }
count_blocks() { grep -c '^# >>> dotfiles ' "$1"; }
snapshot() { cat "$H"/.profile "$H"/.bash_profile "$H"/.bashrc "$H"/.zshenv "$H"/.zprofile "$H"/.zshrc; }

finish() {
  [ "$nfail" -eq 0 ] || { echo "$SUITE: $nfail failed"; exit 1; }
}
