#!/bin/sh
# test/matrix.sh: prove which layers load in which shell, and that they load
# cleanly. Each invocation runs `echo @df@ran` under env -i in a scratch HOME
# with the blocks injected and DOTFILES_TRACE=1. It fails if the expected
# layers don't load, if the command never runs (a layer exits or stops the
# shell), if a non-interactive shell writes to stdout, or if anything other
# than trace lines reaches stderr (syntax errors, failing commands, noise).
# DOTFILES_TEST_PROFILE picks the host profile to load (default: example).
set -u
unset XDG_CONFIG_HOME XDG_CACHE_HOME # keep init in the scratch HOME

repo=$(cd "$(dirname "$0")/.." && pwd -P)
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT INT TERM
fails=0

profile=${DOTFILES_TEST_PROFILE:-example}

# inject: write the blocks with init. If init fails but the blocks exist
# (sync-env can fail on a broken env layer), record it and test the shells anyway.
inject() {
  out=$(HOME=$scratch DOTFILES_SKEL_DIR=$scratch/no-skel \
    "$repo/bin/dotfiles" init --profile "$profile" 2>&1) && return 0
  echo "FAIL  dotfiles init"
  printf '%s\n' "$out" | sed 's/^/      > /'
  fails=$((fails + 1))
  [ -f "$scratch/.zshrc" ] || exit 1
}

# run SHELL FLAGS: run the probe command; stdout and stderr go to files.
run() {
  env -i HOME="$scratch" PATH=/usr/local/bin:/usr/bin:/bin TERM=dumb \
    DOTFILES_TRACE=1 "$1" "$2" 'echo @df@ran' \
    >"$scratch/stdout" 2>"$scratch/stderr" </dev/null
}

# layers: the layers the last run loaded, space-separated, in order.
layers() {
  sed -n 's/^dotfiles: //p' "$scratch/stderr" |
    sed -n -e 's|^sh/env\.sh$|env|p' -e 's|^sh/interactive\.sh$|interactive|p' \
           -e 's|^bash/rc\.bash$|bash|p' -e 's|^zsh/rc\.zsh$|zsh|p' |
    tr '\n' ' ' | sed 's/ $//'
}

# noise: stderr lines other than trace lines and bash's notices about having
# no terminal, which only appear because the tests run without one.
noise() {
  grep -v -e '^dotfiles: ' -e 'no job control in this shell' \
    -e 'cannot set terminal process group' "$scratch/stderr"
}

failed() { # failed SHELL FLAGS MESSAGE
  printf 'FAIL  %-10s %s\n' "$1 $2" "$3"
  fails=$((fails + 1))
}

check() { # check SHELL FLAGS EXPECTED
  run "$1" "$2"
  got=$(layers)
  ok=1
  if [ "$got" != "$3" ]; then
    failed "$1" "$2" "want [$3] got [$got]"; ok=0
  fi
  if ! grep -qx '@df@ran' "$scratch/stdout"; then
    failed "$1" "$2" "command never ran: a layer exits or stops the shell"; ok=0
  fi
  case $2 in
    *i*) ;;
    *) if [ "$(cat "$scratch/stdout")" != '@df@ran' ]; then
         failed "$1" "$2" "wrote to stdout:"; ok=0
         grep -vx '@df@ran' "$scratch/stdout" | sed 's/^/      > /'
       fi ;;
  esac
  if noise >/dev/null; then
    failed "$1" "$2" "unexpected output on stderr:"; ok=0
    noise | sed 's/^/      > /'
  fi
  [ "$ok" -eq 0 ] || printf 'ok    %-10s %s\n' "$1 $2" "${got:-none}"
}

inject
check sh   -c   ""
check sh   -lc  "env"
check bash -c   ""
check bash -lc  "env"
check bash -ic  "env interactive bash"
check bash -lic "env env interactive bash"
check zsh  -c   "env"
check zsh  -lc  "env env"
check zsh  -ic  "env interactive zsh"
check zsh  -lic "env env interactive zsh"

# TODO: PATH order and duplicates, missing-repo block, startup time (hyperfine),
# --profile with zsh/zprof.

[ "$fails" -eq 0 ] && echo "all passed" || { echo "$fails failed"; exit 1; }
