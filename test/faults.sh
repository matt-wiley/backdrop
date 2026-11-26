#!/bin/sh
# test/faults.sh
#
# Checks that the tests themselves catch broken layer files. Each case breaks
# one file in a copy of the repo, in one of the ways a real edit can go
# wrong: an exit, a syntax error, a failing command or stray output. It then
# runs the copy's test/matrix.sh and checks that it fails with the right
# message. For syntax errors, it also checks that `dotfiles doctor` reports
# the file as an error.
#
# Without this suite, a bug in matrix.sh or doctor could let them pass
# everything, and a broken layer would only be noticed when shells started
# misbehaving on a real machine.
#
# Each case uses a scratch home directory with its own copy of the repo (see
# test/lib.sh). Run it alone with `sh test/faults.sh`.
SUITE=faults
. "$(dirname "$0")/lib.sh"

# setup
#
# Starts a case with a fresh scratch home and runs init with the example
# profile selected, so doctor checks the profile's files too.
setup() { fresh; run_init --profile example; }

# append FILE TEXT
#
# Adds TEXT as a new line at the end of FILE, a path in the case's copy of
# the repo.
append() { printf '%s\n' "$2" >>"$H/.dotfiles/$1"; }

# run_matrix
#
# Runs the matrix script from the case's copy, so it tests the broken copy
# rather than the real repo. The matrix makes its own scratch home. Its
# output goes to $root/out, where out_has and fail look for it.
run_matrix() { sh "$H/.dotfiles/test/matrix.sh" >"$root/out" 2>&1; }

# A clean copy must pass both the matrix and doctor's parse check. Otherwise
# the failures below would prove nothing.
setup
check "matrix passes on a clean copy" run_matrix
run_doctor
check "doctor passes on a clean copy" out_has '^  ok     every layer file parses$'

# An exit in env.sh ends every shell that loads it before the shell runs its
# command. The matrix notices because the probe command never prints.
setup
append sh/env.sh 'exit 0'
check "matrix fails when env.sh exits" fails run_matrix
check "says the command never ran" out_has 'command never ran'

# A syntax error in env.sh. Shells react to it differently. dash, which is
# /bin/sh on Debian and Ubuntu, stops and exits, so the probe never runs.
# bash running as sh, which is /bin/sh on macOS, reports the error and goes
# on. Either way sh -lc must fail, but the missing probe is checked only
# under dash. readlink -f follows the /bin/sh link to the shell it points to.
setup
append sh/env.sh 'if then'
check "matrix fails on a syntax error in env.sh" fails run_matrix
check "fails sh -lc" out_has '^FAIL  sh -lc '
if [ "$(readlink -f /bin/sh 2>/dev/null)" = /usr/bin/dash ]; then
  check "says dash never ran the command" out_has '^FAIL  sh -lc .*command never ran'
fi
check "shows the error" out_has '^      > .*env\.sh'
# doctor must name the file and the shell that rejected it. It should show
# the file's path inside the repo, without the scratch home's path in front,
# so the message stays short.
check "doctor fails on it" fails run_doctor
check "doctor names the file and shell" out_has 'error  sh/env.sh does not parse in sh: '
check "doctor trims the repo path" fails out_has "does not parse in sh: .*$H/.dotfiles/"

# A command that doesn't exist. The shell prints an error on stderr and
# carries on, so only the matrix's stderr check catches it.
setup
append sh/env.sh 'nosuchcommand-df'
check "matrix fails on a failing command in env.sh" fails run_matrix
check "says stderr had output" out_has 'unexpected output on stderr'

# Output from env.sh. In a non-interactive shell it would end up mixed into
# the output of every script, so the matrix must fail and show what was
# printed.
setup
append sh/env.sh 'echo hello'
check "matrix fails when env.sh prints" fails run_matrix
check "says it wrote to stdout" out_has 'wrote to stdout'
check "shows the output" out_has '^      > hello$'

# Syntax errors in the rc files. Each rc file uses its own shell's syntax, so
# doctor must check it with that shell rather than with sh.
setup
append zsh/rc.zsh 'if then'
check "matrix fails on a syntax error in rc.zsh" fails run_matrix
check "doctor fails on rc.zsh" fails run_doctor
check "doctor checks rc.zsh with zsh" out_has 'error  zsh/rc.zsh does not parse in zsh'

setup
append bash/rc.bash 'if then'
check "matrix fails on a syntax error in rc.bash" fails run_matrix
check "doctor fails on rc.bash" fails run_doctor
check "doctor checks rc.bash with bash" out_has 'error  bash/rc.bash does not parse in bash'

# A syntax error in the selected profile's env.sh. The profile's files load
# in the same shells as the shared ones, so doctor must check them too.
setup
append hosts/example/env.sh 'if then'
check "matrix fails on a syntax error in the profile's env.sh" fails run_matrix
check "doctor fails on the profile's env.sh" fails run_doctor
check "doctor checks the selected profile" out_has 'error  hosts/example/env.sh does not parse in sh'

finish
