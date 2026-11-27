#!/bin/sh
# test/doctor.sh
#
# Checks `dotfiles doctor`, which reports problems with the setup. Each case
# starts from a healthy home, breaks one thing, and checks that doctor
# reports it at the right level. Errors make doctor exit non-zero, while
# warnings and info leave the exit code at zero. The checks covered here are
# listed under "Doctor checks" in the spec.
#
# Each case runs in a new scratch home directory with its own copy of the
# repo (see test/lib.sh). Run it alone with `sh test/doctor.sh`.
#
# Several cases change a file with `cmd FILE >"$root/tmp" && mv "$root/tmp"
# FILE`. A command can't safely read a file and redirect its output into the
# same file, because the redirection empties the file first.
SUITE=doctor
. "$(dirname "$0")/lib.sh"

# healthy
#
# Starts a case with a fresh scratch home set up by `init --profile example`,
# in which doctor should find nothing wrong.
healthy() { fresh; run_init --profile example; }

# A fresh init has nothing to report, and each of the seven entry files gets
# an ok line for its block. Every case below depends on this starting point.
healthy
check "passes on a fresh init" run_doctor
check "reports no errors or warnings" out_has '^doctor: 0 errors, 0 warnings$'
check "marks each file ok" test "$(grep -c '^  ok     block v2 at the top$' "$root/out")" -eq 7

# Errors. Each of these means some shells won't load the dotfiles as they
# should, so doctor must exit non-zero.
healthy
rm "$H/.zshrc"
check "fails when an entry file is missing" fails run_doctor
check "names the missing file" out_has '^  error  missing'

healthy
printf 'echo no block\n' >"$H/.zshrc"
check "fails when the block is missing" fails run_doctor
check "says the block is missing" out_has 'error  no dotfiles block'

# A line above the block, as an installer that prepends to ~/.zshenv might
# add. It runs before the dotfiles load.
healthy
{ printf 'echo installer\n'; cat "$H/.zshenv"; } >"$root/tmp" && mv "$root/tmp" "$H/.zshenv"
check "fails when the block is not first" fails run_doctor
check "says the block is not at the top" out_has 'error  block is not at the top'

# Joining the file to itself gives it two blocks.
healthy
cat "$H/.zprofile" "$H/.zprofile" >"$root/tmp" && mv "$root/tmp" "$H/.zprofile"
check "fails on two blocks" fails run_doctor
check "counts the blocks" out_has 'error  2 blocks'

healthy
printf '# >>> dotfiles v1 >>>\n' >"$H/.zshrc"
check "fails on an unterminated block" fails run_doctor
check "says the block is unterminated" out_has 'error  unterminated'

# The sed points the block's DOTFILES_DIR line at a directory that doesn't
# exist, as if the repo had been moved or deleted.
healthy
sed 's|^DOTFILES_DIR=.*|DOTFILES_DIR="/nonexistent"|' "$H/.zshenv" >"$root/tmp" && mv "$root/tmp" "$H/.zshenv"
check "fails when DOTFILES_DIR does not exist" fails run_doctor
check "names the bad DOTFILES_DIR" out_has 'error  DOTFILES_DIR does not exist: /nonexistent'

# A file the blocks source is missing. Every source in a block is
# conditional, so shells still start, but they silently go without that
# layer. That is why doctor has to report it.
healthy
rm "$H/.dotfiles/zsh/rc.zsh"
check "fails when a sourced file is missing" fails run_doctor
check "names the missing sourced file" out_has 'error  sourced file is missing: \$DOTFILES_DIR/zsh/rc.zsh'

# No block sources lib.sh directly, but env.sh needs it, so doctor checks
# for it as well.
healthy
rm "$H/.dotfiles/sh/lib.sh"
check "fails when lib.sh is missing" fails run_doctor
check "names lib.sh" out_has 'sourced file is missing: \$DOTFILES_DIR/sh/lib.sh'

# The git block has no DOTFILES_DIR line, so doctor reads the repo path from
# its include line instead, and checks the files that block names. git skips
# an include whose file is missing without a word, which is why doctor has
# to report it.
healthy
sed 's|^	path = .*|	path = "/nonexistent/git/config"|' "$H/.gitconfig" >"$root/tmp" && mv "$root/tmp" "$H/.gitconfig"
check "fails when the git block's repo does not exist" fails run_doctor
check "names the git block's bad repo path" out_has 'error  DOTFILES_DIR does not exist: /nonexistent'

healthy
rm "$H/.dotfiles/git/ignore"
check "fails when a file the git block names is missing" fails run_doctor
check "names the missing git file" out_has 'error  sourced file is missing: \$DOTFILES_DIR/git/ignore'

# git stops every command with an error when an included file can't be
# parsed, so a mistake in git/config is an error too. The unclosed [ makes
# the file invalid.
if command -v git >/dev/null 2>&1; then
  healthy
  printf '[broken\n' >>"$H/.dotfiles/git/config"
  check "fails when git/config does not parse" fails run_doctor
  check "says git/config does not parse" out_has 'error  git/config does not parse'
fi

# Warnings. These point at something worth fixing, but shells still load the
# dotfiles, so the exit code stays zero.
#
# The sed changes the version in the first line, the opening marker, from v2
# to v0, as if the block came from an older version of the repo.
healthy
sed '1s/ v2 / v0 /' "$H/.bashrc" >"$root/tmp" && mv "$root/tmp" "$H/.bashrc"
check "passes with a stale block" run_doctor
check "warns about the stale block" out_has 'warn   block is v0, repo has v2'

# The sed comments out the line in the ~/.profile block that loads env.sh.
# It matches the line by its start, `[ -r "$DOTFILES_DIR/sh/env.sh" ]`, and
# \1 puts the matched text back after "# ". A change inside the markers is
# lost the next time init rewrites the block, so doctor warns about it.
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

# Aliases and functions that take the name of a builtin or common command
# change how that command behaves, which can break scripts and coding agents
# that expect the standard behavior. They are added below the blocks here.
# doctor still finds them, because it asks real interactive shells what is
# defined. ll, which zsh/rc.zsh defines, is a new name and must not be
# flagged.
healthy
printf 'alias ls="ls -G"\n' >>"$H/.bashrc"
printf 'cat() { command cat "$@"; }\n' >>"$H/.zshrc"
printf 'alias cd=pushd\n' >>"$H/.zshrc"
run_doctor
check "warns about a bash alias over a common command" out_has "warn   bash: alias 'ls' shadows"
check "warns about a zsh function over a common command" out_has "warn   zsh: function 'cat' shadows"
check "warns about an alias over a builtin" out_has "warn   zsh: alias 'cd' shadows"
check "does not flag distinct names like ll" fails out_has "'ll' shadows"

# Linux only. These checks are skipped on macOS.
if [ "$(uname -s)" = Linux ]; then
  # sync-env writes environment.d/dotfiles.conf for the desktop session and
  # systemd's services. If the file is older than env.sh, env.sh may have
  # changed since, so the file may be out of date. It is backdated to 2020
  # to make it older.
  healthy
  mkdir -p "$H/.config/environment.d"
  printf 'X=1\n' >"$H/.config/environment.d/dotfiles.conf"
  touch -t 202001010000 "$H/.config/environment.d/dotfiles.conf"
  run_doctor
  check "warns when environment.d is older than env.sh" out_has 'warn   .*dotfiles.conf is older than sh/env.sh'

  healthy
  rm "$H/.config/environment.d/dotfiles.conf"
  run_doctor
  check "notes environment.d is not generated yet" out_has 'info   .*dotfiles.conf not generated yet'

  # A distro skeleton's full text below a block. init replaces a file that
  # is identical to its skeleton, but it can't stop the skeleton being added
  # back later, so doctor looks for it. The skeleton is written to the case's
  # skeleton directory only after init has run, so init doesn't treat
  # ~/.bashrc as a skeleton itself.
  healthy
  printf '# skeleton\nalias x=y\n' >"$root/skel$n/.bashrc"
  cat "$root/skel$n/.bashrc" >>"$H/.bashrc"
  run_doctor
  check "warns when a skeleton appears below the block" out_has 'warn   distro skeleton .*\.bashrc was added below the block'
fi

# Info. doctor mentions required tools from packages.toml that aren't
# installed, and says nothing about missing optional ones. Two made-up tools
# are appended to the copy's packages.toml, one of each kind.
healthy
printf '\n[nosuchtool]\nrequired = true\n\n[optionaltool]\nbrew = "x"\n' >>"$H/.dotfiles/packages.toml"
run_doctor
check "notes a missing required tool" out_has "info   required tool 'nosuchtool'"
check "ignores a missing optional tool" fails out_has "'optionaltool'"

# The report. doctor prints what each entry file has below its block, so
# local additions are visible when something conflicts. Each run saves a
# snapshot, and --diff prints only what changed since the last one.
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
