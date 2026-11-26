#!/bin/sh
# test/matrix.sh
#
# Checks which layers load in each kind of shell, and that they load cleanly.
# It covers sh, bash and zsh, started as plain, login, interactive and
# interactive login shells, and compares the result with the table in the
# Testing section of the spec.
#
# It injects the blocks with `dotfiles init` into a scratch home directory.
# Then it starts each shell with DOTFILES_TRACE=1, which makes every layer
# file print its name to stderr as it loads, and gives it a probe command,
# `echo @df@ran`, to run. An invocation fails in any of these cases:
#
# - The layers it loaded are not the expected ones, in the expected order.
# - The probe never ran. That means a layer exited or stopped the shell, so
#   any script or command run in that kind of shell would never run either.
# - A non-interactive shell printed something else on stdout. Scripts and
#   command substitutions read that output, so stray text would corrupt it.
# - Anything other than trace lines reached stderr, such as a syntax error,
#   a failing command or a stray message.
#
# It tests the repo it lives in, which it finds from its own path. That lets
# test/faults.sh break a file in a copy of the repo and run the copy's
# matrix.sh against it.
#
# `dotfiles test` runs it after the CLI suites. To run it alone, use
# `sh test/matrix.sh`. It also loads the host profile named by
# DOTFILES_TEST_PROFILE, so the profile's files are tested too. `dotfiles
# test` sets that variable to this machine's profile. Without it, the example
# profile is used.
set -u
# As in test/lib.sh, the XDG variables are unset so that init writes the
# selector and cache into the scratch home, not your real ~/.config and
# ~/.cache.
unset XDG_CONFIG_HOME XDG_CACHE_HOME # keep init in the scratch HOME

repo=$(cd "$(dirname "$0")/.." && pwd -P)
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT INT TERM
fails=0

profile=${DOTFILES_TEST_PROFILE:-example}

# inject
#
# Writes the blocks into the scratch home with `dotfiles init`. The skeleton
# directory is set to a path that doesn't exist, so the machine's /etc/skel
# files are never treated as skeletons.
#
# init can fail after it has written the blocks, for example when sync-env
# meets a broken env layer. In that case the failure is recorded and the
# shells are tested anyway, so the report still shows which shells the
# breakage affects. test/faults.sh checks those lines. If init didn't get as
# far as writing ~/.zshrc, there is nothing to test, and the script stops.
inject() {
  out=$(HOME=$scratch DOTFILES_SKEL_DIR=$scratch/no-skel \
    "$repo/bin/dotfiles" init --profile "$profile" 2>&1) && return 0
  echo "FAIL  dotfiles init"
  printf '%s\n' "$out" | sed 's/^/      > /'
  fails=$((fails + 1))
  [ -f "$scratch/.zshrc" ] || exit 1
}

# run SHELL FLAGS
#
# Starts SHELL with FLAGS and the probe command, and saves its stdout and
# stderr to files. env -i empties the environment first. Otherwise variables
# exported by the shell running the tests, such as PATH or the DOTFILES_
# variables, could cover up a layer that fails to set them. Only HOME, a
# basic PATH, TERM and the trace switch are passed in. Because ENV is not
# among them, sh -c reads no startup file. TERM is set to dumb because there
# is no real terminal. stdin is /dev/null, so an interactive shell can't sit
# waiting for input.
run() {
  env -i HOME="$scratch" PATH=/usr/local/bin:/usr/bin:/bin TERM=dumb \
    DOTFILES_TRACE=1 "$1" "$2" 'echo @df@ran' \
    >"$scratch/stdout" 2>"$scratch/stderr" </dev/null
}

# layers
#
# Prints the layers the last run loaded, in order and separated by spaces,
# for example "env env zsh". The first sed keeps only the trace lines and
# strips their "dotfiles: " prefix. The second sed turns each shared layer
# file into a short name and drops every other line, including the profile's
# files, so the expected results don't depend on which profile is loaded. tr
# and the last sed join the names onto one line without a trailing space.
layers() {
  sed -n 's/^dotfiles: //p' "$scratch/stderr" |
    sed -n -e 's|^sh/env\.sh$|env|p' \
           -e 's|^bash/rc\.bash$|bash|p' -e 's|^zsh/rc\.zsh$|zsh|p' |
    tr '\n' ' ' | sed 's/ $//'
}

# noise
#
# Prints the lines on stderr that shouldn't be there. Trace lines are
# expected. So are bash's notices about job control and the terminal process
# group, which interactive bash prints only because the tests run it without
# a terminal. grep succeeds when it prints a line, so noise also works as a
# test for whether there was any.
noise() {
  grep -v -e '^dotfiles: ' -e 'no job control in this shell' \
    -e 'cannot set terminal process group' "$scratch/stderr"
}

# failed SHELL FLAGS MESSAGE
#
# Prints a FAIL line for one invocation and counts it.
failed() { # failed SHELL FLAGS MESSAGE
  printf 'FAIL  %-10s %s\n' "$1 $2" "$3"
  fails=$((fails + 1))
}

# check SHELL FLAGS EXPECTED
#
# Runs one invocation and checks it. It prints a FAIL line for each problem
# it finds, or a single ok line with the layers that loaded. EXPECTED is the
# list of layers the invocation should load, in the form layers prints. This
# script doesn't use test/lib.sh, so this check is its own and takes
# different arguments.
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
  # Only non-interactive shells must keep stdout to the probe's output, since
  # that is what scripts read. Interactive shells are exempt, because the rc
  # layers may print things meant for the person at the prompt.
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

# The expected layers for each invocation. sh -c and bash -c read no startup
# files, so they load nothing. zsh reads ~/.zshenv in every shell, so even
# zsh -c gets the env layer. Some login shells load env twice. In bash, the
# ~/.bash_profile block sources ~/.profile, and in an interactive shell it
# then sources ~/.bashrc as well, and both of those load env. In zsh,
# ~/.zprofile loads env again after ~/.zshenv, to restore the PATH order that
# macOS's path_helper changes in between. env.sh is idempotent, so loading it
# twice is harmless.
inject
check sh   -c   ""
check sh   -lc  "env"
check bash -c   ""
check bash -lc  "env"
check bash -ic  "env bash"
check bash -lic "env env bash"
check zsh  -c   "env"
check zsh  -lc  "env env"
check zsh  -ic  "env zsh"
check zsh  -lic "env env zsh"

# TODO: Some checks in the spec are not built yet. They are that PATH has no
# duplicates and lists the repo's entries first, that a block whose repo is
# missing prints no error, a startup time limit measured with hyperfine, and
# the --profile option, which loads zsh/zprof.

[ "$fails" -eq 0 ] && echo "all passed" || { echo "$fails failed"; exit 1; }
