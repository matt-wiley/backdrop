#!/bin/sh
# test/faults.sh: broken layer files must be caught. Each case breaks one
# file in a copy of the repo, then checks that the load matrix fails and,
# for syntax errors, that doctor reports an error.
SUITE=faults
. "$(dirname "$0")/lib.sh"

# setup: fresh copy with the example profile selected.
setup() { fresh; run_init --profile example; }
# append FILE TEXT: add a line to a repo file in the copy.
append() { printf '%s\n' "$2" >>"$H/.dotfiles/$1"; }
# run_matrix: run the copy's matrix (it makes its own scratch HOME).
run_matrix() { sh "$H/.dotfiles/test/matrix.sh" >"$root/out" 2>&1; }

setup
check "matrix passes on a clean copy" run_matrix
run_doctor
check "doctor passes on a clean copy" out_has '^  ok     every layer file parses$'

setup
append sh/env.sh 'exit 0'
check "matrix fails when env.sh exits" fails run_matrix
check "says the command never ran" out_has 'command never ran'

setup
append sh/env.sh 'if then'
check "matrix fails on a syntax error in env.sh" fails run_matrix
check "says sh -lc never ran" out_has '^FAIL  sh -lc .*command never ran'
check "shows the error" out_has '^      > .*env\.sh'
check "doctor fails on it" fails run_doctor
check "doctor names the file and shell" out_has 'error  sh/env.sh does not parse in sh: '
check "doctor trims the repo path" fails out_has "does not parse in sh: .*$H/.dotfiles/"

setup
append sh/env.sh 'nosuchcommand-df'
check "matrix fails on a failing command in env.sh" fails run_matrix
check "says stderr had output" out_has 'unexpected output on stderr'

setup
append sh/env.sh 'echo hello'
check "matrix fails when env.sh prints" fails run_matrix
check "says it wrote to stdout" out_has 'wrote to stdout'
check "shows the output" out_has '^      > hello$'

setup
append sh/interactive.sh 'if then'
check "matrix fails on a syntax error in interactive.sh" fails run_matrix
check "doctor fails on interactive.sh" fails run_doctor
check "doctor checks interactive.sh with bash" out_has 'error  sh/interactive.sh does not parse in bash'

setup
append zsh/rc.zsh 'if then'
check "matrix fails on a syntax error in rc.zsh" fails run_matrix
check "doctor fails on rc.zsh" fails run_doctor
check "doctor checks rc.zsh with zsh" out_has 'error  zsh/rc.zsh does not parse in zsh'

setup
append bash/rc.bash 'if then'
run_doctor
check "doctor checks rc.bash with bash" out_has 'error  bash/rc.bash does not parse in bash'

setup
append hosts/example/env.sh 'if then'
check "matrix fails on a syntax error in the profile's env.sh" fails run_matrix
check "doctor fails on the profile's env.sh" fails run_doctor
check "doctor checks the selected profile" out_has 'error  hosts/example/env.sh does not parse in sh'

finish
