#!/bin/sh
# test/init.sh
#
# Checks `dotfiles init`, which writes the dotfiles block at the top of each
# entry file: ~/.profile, ~/.bash_profile, ~/.bashrc, ~/.zshenv, ~/.zprofile,
# ~/.zshrc and ~/.gitconfig. The checks follow the injection rules in the
# spec. They cover what init creates, what it must keep of a file's existing
# content, and when it must refuse to change a file. Those files hold
# people's own shell and git setup, so most of the checks are about leaving
# that content alone.
#
# Each case runs init in a new scratch home directory with its own copy of
# the repo (see test/lib.sh). Run it alone with `sh test/init.sh`.
SUITE=init
. "$(dirname "$0")/lib.sh"

# On an empty home, init creates all seven entry files and the cache
# directory. The repo is in the default place, so the block refers to it as
# $HOME/.dotfiles. Running init a second time must change nothing, so it is
# always safe to run again, and it reports each unchanged file as ok.
fresh
check "succeeds on empty home" run_init
check "creates all seven entry files" test -f "$H/.profile" -a -f "$H/.bash_profile" \
  -a -f "$H/.bashrc" -a -f "$H/.zshenv" -a -f "$H/.zprofile" -a -f "$H/.zshrc" \
  -a -f "$H/.gitconfig"
check "writes repo path relative to HOME" grep -qx 'DOTFILES_DIR="$HOME/.dotfiles"   # repo path, written by init' "$H/.zshenv"
check "creates cache dir" test -d "$H/.cache/dotfiles"
snapshot >"$root/before"
run_init
snapshot >"$root/after"
check "is idempotent" cmp -s "$root/before" "$root/after"
check "reports unchanged files as ok" test "$(grep -cE '^ok +.*/\.(profile|bash_profile|bashrc|zshenv|zprofile|zshrc|gitconfig)$' "$root/out")" -eq 7

# ~/.gitconfig gets a block too. It includes the repo's git/config and points
# core.excludesFile at git/ignore. git doesn't expand $HOME, so the paths are
# written with ~ instead. The machine's own settings, such as its [user]
# section, stay below the block, and because git keeps the last value it
# reads, they override the repo's. `git config --global` writes to
# ~/.gitconfig, which is the machine's own file, so a name or email set that
# way can't end up committed to the repo.
fresh
printf '[user]\n\tname = Machine\n' >"$H/.gitconfig"
run_init
check "writes the git include with ~" grep -qx '	path = "~/.dotfiles/git/config"' "$H/.gitconfig"
check "keeps the machine's git settings" grep -qx '	name = Machine' "$H/.gitconfig"
if command -v git >/dev/null 2>&1; then
  check "git loads the repo's config" test "$(git_get init.defaultBranch)" = main
  check "git keeps the machine's settings" test "$(git_get user.name)" = Machine
  check "git uses the repo's ignore file" test "$(git_get --type=path core.excludesFile)" = "$H/.dotfiles/git/ignore"
  printf '[init]\n\tdefaultBranch = trunk\n' >>"$H/.gitconfig"
  check "machine settings override the repo's" test "$(git_get init.defaultBranch)" = trunk
  cp "$H/.dotfiles/git/config" "$root/orig"
  run_git config --global user.email me@example.com
  check "git config --global writes to the machine's file" grep -q 'me@example.com' "$H/.gitconfig"
  check "git config --global leaves the repo alone" cmp -s "$H/.dotfiles/git/config" "$root/orig"
fi

# A repo outside the home directory is written as an absolute path, in the
# git block as in the shell blocks, and doctor accepts it. DOTFILES_DIR is a
# physical path (see block_dir), so the expected path is resolved with
# `pwd -P` too; on macOS the temporary directory is behind a symlink.
fresh
mv "$H/.dotfiles" "$root/outside$n"
out_dir=$(cd "$root/outside$n" && pwd -P)
HOME=$H DOTFILES_SKEL_DIR=$root/skel$n "$out_dir/bin/dotfiles" init >"$root/out" 2>&1
check "writes an absolute git include outside HOME" grep -qx "	path = \"$out_dir/git/config\"" "$H/.gitconfig"
HOME=$H DOTFILES_SKEL_DIR=$root/skel$n "$out_dir/bin/dotfiles" doctor >"$root/out" 2>&1
check "doctor accepts the absolute git include" out_has '^doctor: 0 errors'

# A file's existing content must survive. The block goes above it with one
# blank line between them, and running init again must not add another blank
# line each time.
#
# The expected end of the file is a heredoc on file descriptor 3, which the
# inner sh reads as /dev/fd/3. In `sh -c '...' _ FILE /dev/fd/3`, the two
# paths become $1 and $2. The _ is a placeholder, because sh -c assigns the
# first argument after the script to $0.
fresh
printf 'export FOO=1\nalias x=y\n' >"$H/.zshrc"
run_init
check "block is first in existing file" test "$(first_line "$H/.zshrc")" = '# >>> dotfiles v2 >>> managed by `dotfiles init`; do not edit inside'
check "keeps machine content" sh -c 'tail -n 3 "$1" | cmp -s - "$2"' _ "$H/.zshrc" /dev/fd/3 3<<'X'

export FOO=1
alias x=y
X
run_init
check "does not add a second blank line" test "$(grep -c '^$' "$H/.zshrc")" -eq 1

# A shebang only works on the first line, so it must stay there, and the
# block goes right after it.
fresh
printf '#!/bin/zsh\necho hi\n' >"$H/.zshrc"
run_init
check "keeps shebang first" test "$(first_line "$H/.zshrc")" = '#!/bin/zsh'
check "block follows shebang" sh -c 'sed -n 2p "$1" | grep -q "^# >>> dotfiles "' _ "$H/.zshrc"

# A file can hold blocks from an older version, more than one block, or a
# block below other content. init removes all of them and writes one current
# block at the top, with the new repo path. The content between the old
# blocks stays, in its original order.
fresh
cat >"$H/.bashrc" <<'X'
# >>> dotfiles v0 >>> old
DOTFILES_DIR="/old/path"
# <<< dotfiles <<<
echo one
# >>> dotfiles v0 >>> old
DOTFILES_DIR="/old/path"
# <<< dotfiles <<<
echo two
X
run_init
check "collapses duplicate blocks" test "$(count_blocks "$H/.bashrc")" -eq 1
check "upgrades block version" grep -q '^# >>> dotfiles v2 ' "$H/.bashrc"
check "replaces old repo path" sh -c '! grep -q /old/path "$1"' _ "$H/.bashrc"
check "keeps content order" sh -c 'grep "^echo" "$1" | tr "\n" " " | grep -qx "echo one echo two "' _ "$H/.bashrc"

# A block with an opening marker but no closing one. init can't tell where
# the block ends, so removing it could delete the user's own lines. It must
# leave the file untouched and exit non-zero, but still set up the other
# entry files.
fresh
printf '# >>> dotfiles v1 >>>\necho keep me\n' >"$H/.zshrc"
cp "$H/.zshrc" "$root/orig"
check "fails on unterminated block" fails run_init
check "leaves unterminated file untouched" cmp -s "$H/.zshrc" "$root/orig"
check "still injects other files" test -f "$H/.zshenv"

# On Linux, a new home directory starts with copies of the distro's files in
# /etc/skel. An entry file identical to its skeleton holds nothing the user
# wrote, so init backs it up as FILE.dist and replaces it with a bare block.
# That matters because Ubuntu's skeleton ~/.profile sources ~/.bashrc, which
# would load it twice in interactive bash login shells. A file that differs
# from its skeleton must be kept as it is. The case's skeleton directory
# stands in for /etc/skel (see fresh in test/lib.sh). The skeleton handling
# is Linux only, so these checks are skipped on macOS.
if [ "$(uname -s)" = Linux ]; then
  fresh
  printf '# skeleton\n[ -f ~/.bashrc ] && . ~/.bashrc\n' >"$root/skel$n/.profile"
  cp "$root/skel$n/.profile" "$H/.profile"
  printf '# edited skeleton\n' >"$root/skel$n/.bashrc"
  printf '# not the skeleton\n' >"$H/.bashrc"
  run_init
  check "backs up skeleton" cmp -s "$H/.profile.dist" "$root/skel$n/.profile"
  check "drops skeleton content" sh -c '! grep -q "# skeleton" "$1"' _ "$H/.profile"
  check "keeps non-skeleton file" grep -q 'not the skeleton' "$H/.bashrc"
  check "no backup for non-skeleton file" test ! -e "$H/.bashrc.dist"
fi

# Some people keep their entry files elsewhere and symlink them into their
# home directory. init must edit the file the link points to and leave the
# link in place.
fresh
printf 'echo linked\n' >"$H/real-zshrc"
ln -s real-zshrc "$H/.zshrc"
run_init
check "keeps the symlink" test -L "$H/.zshrc"
check "edits the link target" grep -q '^# >>> dotfiles ' "$H/real-zshrc"

# The profile selector, ~/.config/dotfiles/host, names this machine's
# profile. --profile writes it, and a later init without --profile must keep
# it. A profile with no directory under hosts/ gets a warning. A name with a
# slash is rejected, because the name is used as a directory under hosts/.
fresh
run_init --profile example
check "writes selector" test "$(cat "$H/.config/dotfiles/host")" = example
run_init
check "keeps selector when --profile is omitted" test "$(cat "$H/.config/dotfiles/host")" = example
run_init --profile=nosuch
check "warns on unknown profile" grep -q 'no directory hosts/nosuch' "$root/out"
check "rejects profile with a slash" fails run_init --profile a/b

# zsh reads .zprofile and .zshrc from $ZDOTDIR when ~/.zshenv sets it, so
# init must put those blocks there, while the .zshenv block stays in $HOME.
# doctor and uninstall must look in the same places. These cases need a real
# zsh, because init asks zsh where it reads its files.
if command -v zsh >/dev/null 2>&1; then
  fresh
  Z=$H/.config/zsh
  printf 'export ZDOTDIR="$HOME/.config/zsh"\n' >"$H/.zshenv"
  run_init --profile example
  check "puts the zshrc block in ZDOTDIR" grep -q '^# >>> dotfiles ' "$Z/.zshrc"
  check "puts the zprofile block in ZDOTDIR" grep -q '^# >>> dotfiles ' "$Z/.zprofile"
  check "keeps the zshenv block in HOME" grep -q '^# >>> dotfiles ' "$H/.zshenv"
  check "keeps ZDOTDIR below the zshenv block" grep -q '^export ZDOTDIR=' "$H/.zshenv"
  check "creates no zshrc in HOME" test ! -e "$H/.zshrc"
  check "doctor accepts the ZDOTDIR files" run_doctor
  check "doctor reports no warnings with ZDOTDIR" out_has '^doctor: 0 errors, 0 warnings$'
  check "doctor names the ZDOTDIR zshrc" out_has '^~/\.config/zsh/\.zshrc$'
  run_uninstall
  check "uninstall removes the ZDOTDIR zshrc" test ! -e "$Z/.zshrc"
  check "uninstall keeps ZDOTDIR in zshenv" grep -qx 'export ZDOTDIR="$HOME/.config/zsh"' "$H/.zshenv"

  # ZDOTDIR set after an earlier init leaves blocks in ~/.zshrc and
  # ~/.zprofile that zsh no longer reads. init and doctor warn about them,
  # and uninstall removes them along with the new ones.
  fresh
  run_init --profile example
  printf 'export ZDOTDIR="$HOME/.config/zsh"\n' >>"$H/.zshenv"
  run_init
  check "warns about a zshrc block zsh no longer reads" out_has "$H/\.zshrc has a dotfiles block, but zsh reads"
  run_doctor
  check "doctor warns about the unread zshrc block" out_has 'warn   ~/\.zshrc has a dotfiles block'
  run_uninstall
  check "uninstall removes the unread zshrc block" test ! -e "$H/.zshrc"
  check "uninstall removes the ZDOTDIR zshrc block too" test ! -e "$H/.config/zsh/.zshrc"

  # A ZDOTDIR exported only in the shell that runs init, as editors' terminal
  # integrations do, isn't where a new zsh looks. init ignores it and says so.
  fresh
  ZDOTDIR=$root/elsewhere
  export ZDOTDIR
  run_init
  unset ZDOTDIR
  check "ignores a ZDOTDIR set only in this shell" test -f "$H/.zshrc" -a ! -e "$root/elsewhere/.zshrc"
  check "says it ignored that ZDOTDIR" out_has "ZDOTDIR is $root/elsewhere in this shell"
fi

finish
