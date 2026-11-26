#!/bin/sh
# test/init.sh: behavior of `dotfiles init` on scratch home directories.
SUITE=init
. "$(dirname "$0")/lib.sh"

# Empty home: every entry file is created; a second run changes nothing.
fresh
check "succeeds on empty home" run_init
check "creates all six entry files" test -f "$H/.profile" -a -f "$H/.bash_profile" \
  -a -f "$H/.bashrc" -a -f "$H/.zshenv" -a -f "$H/.zprofile" -a -f "$H/.zshrc"
check "writes repo path relative to HOME" grep -qx 'DOTFILES_DIR="$HOME/.dotfiles"   # repo path, written by init' "$H/.zshenv"
check "creates cache dir" test -d "$H/.cache/dotfiles"
snapshot >"$root/before"
run_init
snapshot >"$root/after"
check "is idempotent" cmp -s "$root/before" "$root/after"
check "reports unchanged files as ok" test "$(grep -cE '^ok +.*/\.(profile|bash_profile|bashrc|zshenv|zprofile|zshrc)$' "$root/out")" -eq 6

# Existing content stays below the block, separated by one blank line.
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

# Shebang stays on line 1.
fresh
printf '#!/bin/zsh\necho hi\n' >"$H/.zshrc"
run_init
check "keeps shebang first" test "$(first_line "$H/.zshrc")" = '#!/bin/zsh'
check "block follows shebang" sh -c 'sed -n 2p "$1" | grep -q "^# >>> dotfiles "' _ "$H/.zshrc"

# Stale, duplicated and misplaced blocks collapse into one current block at the top.
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

# An unterminated block is an error and the file is left untouched.
fresh
printf '# >>> dotfiles v1 >>>\necho keep me\n' >"$H/.zshrc"
cp "$H/.zshrc" "$root/orig"
check "fails on unterminated block" fails run_init
check "leaves unterminated file untouched" cmp -s "$H/.zshrc" "$root/orig"
check "still injects other files" test -f "$H/.zshenv"

# A distro skeleton is backed up and replaced by a bare block (Linux only).
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

# Symlinked entry files are edited through the link.
fresh
printf 'echo linked\n' >"$H/real-zshrc"
ln -s real-zshrc "$H/.zshrc"
run_init
check "keeps the symlink" test -L "$H/.zshrc"
check "edits the link target" grep -q '^# >>> dotfiles ' "$H/real-zshrc"

# Profiles.
fresh
run_init --profile example
check "writes selector" test "$(cat "$H/.config/dotfiles/host")" = example
run_init
check "keeps selector when --profile is omitted" test "$(cat "$H/.config/dotfiles/host")" = example
run_init --profile=nosuch
check "warns on unknown profile" grep -q 'no directory hosts/nosuch' "$root/out"
check "rejects profile with a slash" fails run_init --profile a/b

finish
