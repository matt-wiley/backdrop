#!/bin/sh
# test/uninstall.sh: behavior of `dotfiles uninstall` on scratch home directories.
SUITE=uninstall
. "$(dirname "$0")/lib.sh"

# Empty home: everything init created goes away; selector and cache stay.
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

# init then uninstall restores existing files byte for byte.
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

# A block that isn't at the top is removed without touching nearby lines.
fresh
printf 'one\n\n# >>> dotfiles v1 >>>\nX=1\n# <<< dotfiles <<<\n\ntwo\n' >"$H/.zshrc"
run_uninstall
check "removes a block in the middle" cmp -s "$H/.zshrc" /dev/fd/3 3<<'X'
one


two
X

# Skeletons come back when nothing was added below the block.
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

# A broken block is an error and the file is left untouched.
fresh
printf '# >>> dotfiles v1 >>>\necho keep me\n' >"$H/.zshrc"
cp "$H/.zshrc" "$root/orig"
check "fails on unterminated block" fails run_uninstall
check "leaves the broken file untouched" cmp -s "$H/.zshrc" "$root/orig"

# Symlinks are kept; the block is removed from the file they point to.
fresh
printf 'echo linked\n' >"$H/real-zshrc"
ln -s real-zshrc "$H/.zshrc"
run_init
run_uninstall
check "keeps the symlink" test -L "$H/.zshrc"
check "restores the link target" sh -c 'test "$(cat "$1")" = "echo linked"' _ "$H/real-zshrc"

# Files without a block are not touched at all.
fresh
printf 'echo mine\n' >"$H/.zshrc"
touch -t 202001010000 "$H/.zshrc"
run_uninstall
check "leaves files without a block alone" test -n "$(find "$H/.zshrc" ! -newermt 2020-01-02)"

finish
