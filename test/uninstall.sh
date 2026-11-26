#!/bin/sh
# test/uninstall.sh
#
# Checks `dotfiles uninstall`, which removes the dotfiles block from every
# shell entry file. The goal is that init followed by uninstall leaves a home
# directory as it was, byte for byte, so someone can try the dotfiles and
# back out cleanly. Content the user wrote must never be lost.
#
# Each case runs in a new scratch home directory with its own copy of the
# repo (see test/lib.sh). Run it alone with `sh test/uninstall.sh`.
SUITE=uninstall
. "$(dirname "$0")/lib.sh"

# On a home that init set up from nothing, uninstall deletes the entry files,
# since they hold only the block. Leaving them empty would not be harmless:
# an empty ~/.bash_profile stops bash login shells from reading ~/.profile.
# It also deletes the environment.d file that sync-env writes, which is
# created by hand here because init writes it only on Linux. The profile
# selector and the cache stay. A second run must succeed with nothing left to
# remove.
fresh
run_init --profile example
mkdir -p "$H/.config/environment.d"
printf 'FOO=1\n' >"$H/.config/environment.d/dotfiles.conf"
check "succeeds" run_uninstall
check "deletes files that held only the block" sh -c '! ls -A "$1" | grep -qxE "\.(profile|bash_profile|bashrc|zshenv|zprofile|zshrc)"' _ "$H"
check "deletes environment.d file" test ! -e "$H/.config/environment.d/dotfiles.conf"
check "keeps selector" test -f "$H/.config/dotfiles/host"
check "keeps cache dir" test -d "$H/.cache/dotfiles"
check "second run succeeds" run_uninstall

# Files that had content before init get exactly that content back. The
# files include a leading blank line and a shebang, because those sit right
# where the block goes. init runs twice first, to show that a repeated init
# leaves nothing extra behind for uninstall to miss.
fresh
printf 'export FOO=1\nalias x=y\n' >"$H/.zshrc"
printf '\n# leading blank line\n' >"$H/.zshenv"
printf '#!/bin/bash\necho hi\n' >"$H/.bashrc"
for f in .zshrc .zshenv .bashrc; do cp "$H/$f" "$root/orig$f"; done
run_init
run_init
run_uninstall
for f in .zshrc .zshenv .bashrc; do
  check "round-trips $f" cmp -s "$H/$f" "$root/orig$f"
done

# A block that isn't at the top is removed on its own, and the blank lines
# around it, which belong to the user, stay. The expected result is a
# heredoc on file descriptor 3, which cmp reads as /dev/fd/3.
fresh
printf 'one\n\n# >>> dotfiles v1 >>>\nX=1\n# <<< dotfiles <<<\n\ntwo\n' >"$H/.zshrc"
run_uninstall
check "removes a block in the middle" cmp -s "$H/.zshrc" /dev/fd/3 3<<'X'
one


two
X

# On Linux, init replaces an entry file identical to its skeleton with a
# bare block and keeps the original as FILE.dist. uninstall puts the
# skeleton back and removes the backup, as long as nothing was added below
# the block. If something was added, as in .bashrc here, it keeps both the
# file and the backup, so the user can merge them by hand. Skeletons are
# Linux only, so these checks are skipped on macOS.
if [ "$(uname -s)" = Linux ]; then
  fresh
  printf '# skeleton profile\n' >"$root/skel$n/.profile"
  printf '# skeleton bashrc\n' >"$root/skel$n/.bashrc"
  cp "$root/skel$n/.profile" "$root/skel$n/.bashrc" "$H/"
  run_init
  printf 'export ADDED=1\n' >>"$H/.bashrc"
  run_uninstall
  check "restores untouched skeleton" cmp -s "$H/.profile" "$root/skel$n/.profile"
  check "removes its backup" test ! -e "$H/.profile.dist"
  check "keeps content added below the block" grep -qx 'export ADDED=1' "$H/.bashrc"
  check "keeps backup when content was added" test -f "$H/.bashrc.dist"
fi

# A block with an opening marker but no closing one. uninstall can't tell
# where the block ends, so removing it could delete the user's own lines. It
# must leave the file untouched and exit non-zero.
fresh
printf '# >>> dotfiles v1 >>>\necho keep me\n' >"$H/.zshrc"
cp "$H/.zshrc" "$root/orig"
check "fails on unterminated block" fails run_uninstall
check "leaves the broken file untouched" cmp -s "$H/.zshrc" "$root/orig"

# Symlinked entry files keep their links. The block is removed from the file
# each link points to, which gets its original content back.
fresh
printf 'echo linked\n' >"$H/real-zshrc"
ln -s real-zshrc "$H/.zshrc"
run_init
run_uninstall
check "keeps the symlink" test -L "$H/.zshrc"
check "restores the link target" sh -c 'test "$(cat "$1")" = "echo linked"' _ "$H/real-zshrc"

# A file without a block must not be written at all, not even with the same
# content. Its modification time is set to 2020 first. find with
# `! -newermt 2020-01-02` prints the file only if it hasn't been modified
# since then, so empty output means uninstall wrote to it.
fresh
printf 'echo mine\n' >"$H/.zshrc"
touch -t 202001010000 "$H/.zshrc"
run_uninstall
check "leaves files without a block alone" test -n "$(find "$H/.zshrc" ! -newermt 2020-01-02)"

finish
