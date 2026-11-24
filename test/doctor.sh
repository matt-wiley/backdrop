#!/bin/sh
# test/doctor.sh: findings and exit codes of `dotfiles doctor`.
SUITE=doctor
. "$(dirname "$0")/lib.sh"

# healthy: fresh scratch home after `init --profile example`.
healthy() { fresh; run_init --profile example; }

healthy
check "passes on a fresh init" run_doctor
check "reports no errors or warnings" out_has '^doctor: 0 errors, 0 warnings$'
check "marks each file ok" test "$(grep -c '^  ok     block v1 at the top$' "$root/out")" -eq 6

# Errors: exit code is non-zero.
healthy
rm "$H/.zshrc"
check "fails when an entry file is missing" fails run_doctor
check "names the missing file" out_has '^  error  missing'

healthy
printf 'echo no block\n' >"$H/.zshrc"
check "fails when the block is missing" fails run_doctor
check "says the block is missing" out_has 'error  no dotfiles block'

healthy
{ printf 'echo installer\n'; cat "$H/.zshenv"; } >"$root/tmp" && mv "$root/tmp" "$H/.zshenv"
check "fails when the block is not first" fails run_doctor
check "says the block is not at the top" out_has 'error  block is not at the top'

healthy
cat "$H/.zprofile" "$H/.zprofile" >"$root/tmp" && mv "$root/tmp" "$H/.zprofile"
check "fails on two blocks" fails run_doctor
check "counts the blocks" out_has 'error  2 blocks'

healthy
printf '# >>> dotfiles v1 >>>\n' >"$H/.zshrc"
check "fails on an unterminated block" fails run_doctor
check "says the block is unterminated" out_has 'error  unterminated'

healthy
sed 's|^DOTFILES_DIR=.*|DOTFILES_DIR="/nonexistent"|' "$H/.zshenv" >"$root/tmp" && mv "$root/tmp" "$H/.zshenv"
check "fails when DOTFILES_DIR does not exist" fails run_doctor
check "names the bad DOTFILES_DIR" out_has 'error  DOTFILES_DIR does not exist: /nonexistent'

healthy
rm "$H/.dotfiles/zsh/rc.zsh"
check "fails when a sourced file is missing" fails run_doctor
check "names the missing sourced file" out_has 'error  sourced file is missing: \$DOTFILES_DIR/zsh/rc.zsh'

healthy
rm "$H/.dotfiles/sh/lib.sh"
check "fails when lib.sh is missing" fails run_doctor
check "names lib.sh" out_has 'sourced file is missing: \$DOTFILES_DIR/sh/lib.sh'

# Warnings: exit code stays zero.
healthy
sed '1s/ v1 / v0 /' "$H/.bashrc" >"$root/tmp" && mv "$root/tmp" "$H/.bashrc"
check "passes with a stale block" run_doctor
check "warns about the stale block" out_has 'warn   block is v0, repo has v1'

healthy
sed 's/^\(\[ -r "\$DOTFILES_DIR\/sh\/env.sh" \]\)/# \1/' "$H/.profile" >"$root/tmp" && mv "$root/tmp" "$H/.profile"
run_doctor
check "warns about edits inside the markers" out_has 'warn   block was edited inside the markers'

healthy
rm "$H/.config/dotfiles/host"
run_doctor
check "warns when no profile is selected" out_has 'warn   no profile selected'

healthy
printf 'nosuch\n' >"$H/.config/dotfiles/host"
run_doctor
check "warns when the profile has no directory" out_has "warn   profile 'nosuch' has no directory"

healthy
printf 'alias ls="ls -G"\n' >>"$H/.bashrc"
printf 'cat() { command cat "$@"; }\n' >>"$H/.zshrc"
printf 'alias cd=pushd\n' >>"$H/.zshrc"
run_doctor
check "warns about a bash alias over a common command" out_has "warn   bash: alias 'ls' shadows"
check "warns about a zsh function over a common command" out_has "warn   zsh: function 'cat' shadows"
check "warns about an alias over a builtin" out_has "warn   zsh: alias 'cd' shadows"
check "does not flag distinct names like ll" fails out_has "'ll' shadows"

if [ "$(uname -s)" = Linux ]; then
  healthy
  mkdir -p "$H/.config/environment.d"
  printf 'X=1\n' >"$H/.config/environment.d/dotfiles.conf"
  touch -t 202001010000 "$H/.config/environment.d/dotfiles.conf"
  run_doctor
  check "warns when environment.d is older than env.sh" out_has 'warn   .*dotfiles.conf is older than sh/env.sh'

  healthy
  run_doctor
  check "notes environment.d is not generated yet" out_has 'info   .*dotfiles.conf not generated yet'

  healthy
  printf '# skeleton\nalias x=y\n' >"$root/skel$n/.bashrc"
  cat "$root/skel$n/.bashrc" >>"$H/.bashrc"
  run_doctor
  check "warns when a skeleton appears below the block" out_has 'warn   distro skeleton .*\.bashrc was added below the block'
fi

# Info: required tools.
healthy
printf '\n[nosuchtool]\nrequired = true\n\n[optionaltool]\nbrew = "x"\n' >>"$H/.dotfiles/packages.toml"
run_doctor
check "notes a missing required tool" out_has "info   required tool 'nosuchtool'"
check "ignores a missing optional tool" fails out_has "'optionaltool'"

# Report of local content, and --diff against the last run.
healthy
printf 'export LOCAL=1\n' >>"$H/.zshrc"
run_doctor
check "prints content below the block" out_has '^    \| export LOCAL=1$'
check "marks files without local content" out_has '^  ~/\.zprofile: \(empty\)$'
run_doctor --diff
check "--diff reports no change" out_has '^  ~/\.zshrc: unchanged since last run$'
printf 'export MORE=1\n' >>"$H/.zshrc"
run_doctor --diff
check "--diff reports a change" out_has '^  ~/\.zshrc: changed since last run$'
check "--diff shows the added line" out_has '^    \+export MORE=1$'

finish
