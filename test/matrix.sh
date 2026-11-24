#!/bin/sh
# test/matrix.sh: prove which layers load in which shell.
# Each invocation runs in a scratch HOME with the blocks injected and
# DOTFILES_TRACE=1; the trace is reduced to layer names and compared.
set -u

repo=$(cd "$(dirname "$0")/.." && pwd -P)
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT INT TERM
fails=0

# Inject blocks directly until `dotfiles init` exists.
inject() {
  for pair in profile:.profile bash_profile:.bash_profile bashrc:.bashrc \
              zshenv:.zshenv zprofile:.zprofile zshrc:.zshrc; do
    sed "s|@DOTFILES_DIR@|$repo|" "$repo/blocks/${pair%%:*}.sh" >"$scratch/${pair#*:}"
  done
}

# run SHELL FLAGS: print the layers loaded, space-separated, in order.
run() {
  env -i HOME="$scratch" PATH=/usr/local/bin:/usr/bin:/bin TERM=dumb \
    DOTFILES_TRACE=1 "$1" "$2" 'true' 2>&1 >"$scratch/stdout" </dev/null |
    sed -n 's/^dotfiles: //p' |
    sed -n -e 's|^sh/env\.sh$|env|p' -e 's|^sh/interactive\.sh$|interactive|p' \
           -e 's|^bash/rc\.bash$|bash|p' -e 's|^zsh/rc\.zsh$|zsh|p' |
    tr '\n' ' ' | sed 's/ $//'
}

check() { # check SHELL FLAGS EXPECTED
  got=$(run "$1" "$2")
  if [ "$got" = "$3" ]; then
    printf 'ok    %-10s %s\n' "$1 $2" "${got:-none}"
  else
    printf 'FAIL  %-10s want [%s] got [%s]\n' "$1 $2" "$3" "$got"
    fails=$((fails + 1))
  fi
  case $2 in
    *i*) ;;
    *) if [ -s "$scratch/stdout" ]; then
         printf 'FAIL  %-10s wrote to stdout\n' "$1 $2"
         fails=$((fails + 1))
       fi ;;
  esac
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
