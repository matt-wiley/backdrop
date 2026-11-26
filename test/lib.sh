# test/lib.sh
#
# Shared helpers for the CLI test suites: init, uninstall, doctor, sync-env,
# install and faults. Each suite sets SUITE to its own name, which labels its
# output lines, and then sources this file.
#
# The tests never touch your real home directory. Each case calls fresh,
# which makes a new scratch home directory inside a temporary directory and
# copies the repo into it at ~/.dotfiles, the default clone path. The CLI
# under test is that copy, so a case can break or delete repo files without
# harming the real repo, and init writes the same repo path it would write on
# a real machine.
#
# A suite prints one "ok" or "FAIL" line per check and exits non-zero if any
# check failed. The temporary directory is removed when the suite exits, even
# if it is interrupted.

# Treat unset variables as errors, so a misspelled variable name in a test
# fails loudly instead of quietly expanding to nothing.
set -u

# The CLI honors XDG_CONFIG_HOME and XDG_CACHE_HOME. If they were left set
# from your own environment, the tests would read and write your real config
# and cache directories instead of the ones in the scratch home.
unset XDG_CONFIG_HOME XDG_CACHE_HOME

# This file is sourced, so $0 is the suite script in test/, and the repo is
# the directory above it.
repo=$(cd "$(dirname "$0")/.." && pwd -P)
root=$(mktemp -d)
trap 'rm -rf "$root"' EXIT INT TERM
# nfail counts failed checks. n counts the scratch homes made so far, which
# gives each case its own directory names. H is the current scratch home.
nfail=0
n=0
H=

# pass DESCRIPTION
# fail DESCRIPTION
#
# Print the result of one check. fail also counts the failure and prints the
# output of the last CLI run, indented, because that output usually explains
# what went wrong. When several checks about the same run fail, the output is
# shown only once: fail keeps a copy of what it last showed and compares the
# current output with it.
pass() { printf 'ok    %s: %s\n' "$SUITE" "$1"; }
fail() {
  printf 'FAIL  %s: %s\n' "$SUITE" "$1"
  nfail=$((nfail + 1))
  if [ -s "$root/out" ] && ! cmp -s "$root/out" "$root/out.shown"; then
    sed 's/^/      > /' "$root/out"
    cp "$root/out" "$root/out.shown"
  fi
}

# check DESCRIPTION COMMAND [ARGS...]
#
# Runs COMMAND and reports DESCRIPTION as passed if it succeeds, or failed if
# it doesn't. COMMAND can be anything that sets an exit status, such as test,
# grep, cmp or one of the helpers below.
check() { # check DESCRIPTION COMMAND...
  desc=$1; shift
  if "$@"; then pass "$desc"; else fail "$desc"; fi
}

# fails COMMAND [ARGS...]
#
# Succeeds when COMMAND fails. Use it with check to assert that a command
# fails, or that some output is absent:
#
#   check "rejects an unknown option" fails run_cli install --force
fails() { ! "$@"; }

# fresh
#
# Starts a new test case. It makes a new scratch home directory, sets H to
# it, and copies the repo's working tree to $H/.dotfiles, so uncommitted
# changes are tested too. tar is used because it can leave out .git, which
# the tests don't need, and cp has no portable way to exclude a directory.
#
# It also makes an empty skeleton directory for the case. run_cli points the
# CLI at it instead of /etc/skel, so the machine's real skeleton files can't
# change the results, and a test can put its own skeleton files there.
fresh() {
  n=$((n + 1))
  H=$root/home$n
  mkdir -p "$H/.dotfiles" "$root/skel$n"
  (cd "$repo" && tar cf - --exclude .git .) | (cd "$H/.dotfiles" && tar xf -)
}

# run_cli COMMAND [ARGS...]
#
# Runs the copy's bin/dotfiles with HOME set to the scratch home and with the
# case's own skeleton directory. Its stdout and stderr both go to $root/out,
# so out_has can search the messages and fail can show them. The exit status
# is the CLI's, so check can test it directly.
run_cli() {
  HOME=$H DOTFILES_SKEL_DIR=$root/skel$n "$H/.dotfiles/bin/dotfiles" "$@" >"$root/out" 2>&1
}

# run_init [ARGS...]
# run_uninstall [ARGS...]
# run_doctor [ARGS...]
#
# Shorthands for the commands most suites run.
run_init() { run_cli init "$@"; }
run_uninstall() { run_cli uninstall "$@"; }
run_doctor() { run_cli doctor "$@"; }

# out_has PATTERN
#
# Succeeds if a line in the output of the last CLI run matches PATTERN, an
# extended regular expression. The -- stops grep from reading a pattern that
# starts with a dash as an option.
out_has() { grep -qE -- "$1" "$root/out"; }

# first_line FILE
#
# Prints the first line of FILE.
first_line() { head -n 1 "$1"; }

# count_blocks FILE
#
# Prints how many dotfiles blocks FILE has, by counting their opening
# markers.
count_blocks() { grep -c '^# >>> dotfiles ' "$1"; }

# snapshot
#
# Prints all six entry files of the scratch home as one stream. A test saves
# it before and after a command and compares the two, to show the command
# changed nothing.
snapshot() { cat "$H"/.profile "$H"/.bash_profile "$H"/.bashrc "$H"/.zshenv "$H"/.zprofile "$H"/.zshrc; }

# finish
#
# Ends a suite. If any check failed, it prints how many and exits non-zero,
# so `dotfiles test` stops and reports the failure.
finish() {
  [ "$nfail" -eq 0 ] || { echo "$SUITE: $nfail failed"; exit 1; }
}
