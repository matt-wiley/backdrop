#!/bin/sh
# test/release.sh: building releases, installing them with install.sh over
# HTTP (curl and wget, piped into sh), upgrading, and scripts/release.sh.
# Releases are built from a throwaway git copy of the working tree and served
# from a local python3 HTTP server; nothing touches the network or GitHub.
SUITE=release
. "$(dirname "$0")/lib.sh"

if [ ! -e "$repo/.git" ] || ! command -v git >/dev/null 2>&1 || ! command -v python3 >/dev/null 2>&1; then
  echo "skip  release: needs a git clone, git and python3"
  exit 0
fi

# git with no dependence on the user's config: identity, signing, hooks.
g() {
  git -c user.name=dotfiles-test -c user.email=test@example.invalid \
    -c commit.gpgsign=false -c tag.gpgsign=false -c core.hooksPath=/dev/null "$@"
}
# copy_tree DIR: the working tree (uncommitted changes included) into DIR.
copy_tree() {
  mkdir -p "$1"
  (cd "$repo" && tar cf - --exclude .git --exclude dist .) | (cd "$1" && tar xf -)
}

# Build 9.9.9, 9.9.10 and 9.9.11 from a scratch repo; serve them like GitHub
# does, as $base/vX.Y.Z/<asset>.
src=$root/src
copy_tree "$src"
g -C "$src" init -q
g -C "$src" add -A
g -C "$src" commit -q -m base
srv=$root/srv
build() {
  printf '%s\n' "$1" >"$src/VERSION"
  g -C "$src" commit -q -am "v$1"
  sh "$src/scripts/build-release.sh" "$srv/v$1" >"$root/out" 2>&1
}
check "builds a release" build 9.9.9
build 9.9.10
build 9.9.11
printf 'x' >>"$srv/v9.9.11/backdrop-v9.9.11.zip" # corrupt: checksum must fail

python3 -u -m http.server 0 --bind 127.0.0.1 --directory "$srv" >"$root/http.log" 2>&1 &
server=$!
trap 'kill "$server" 2>/dev/null; rm -rf "$root"' EXIT
trap 'exit 130' INT TERM
i=0
until grep -q 'port [0-9]' "$root/http.log" 2>/dev/null; do
  i=$((i + 1))
  [ "$i" -lt 100 ] || { fail "start a local HTTP server"; finish; }
  sleep 0.1
done
port=$(sed -n 's/.* port \([0-9][0-9]*\).*/\1/p' "$root/http.log" | head -n 1)
base=http://127.0.0.1:$port

# Build output.
d=$srv/v9.9.9
check "writes the ZIP, install.sh and SHA256SUMS" test -f "$d/backdrop-v9.9.9.zip" -a -f "$d/install.sh" -a -f "$d/SHA256SUMS"
check "stamps the version into install.sh" grep -q '^RELEASE_VERSION=9.9.9 ' "$d/install.sh"
check "SHA256SUMS matches the files" sh -c 'cd "$1" && { sha256sum -c SHA256SUMS || shasum -a 256 -c SHA256SUMS; } >/dev/null 2>&1' _ "$d"
python3 -c 'import sys, zipfile; print("\n".join(zipfile.ZipFile(sys.argv[1]).namelist()))' "$d/backdrop-v9.9.9.zip" >"$root/list"
check "puts the repo under a versioned folder" grep -qx 'backdrop-v9.9.9/bin/dotfiles' "$root/list"
check "includes the version file" grep -qx 'backdrop-v9.9.9/VERSION' "$root/list"

# pipe FETCHER VERSION [ARGS...]: download VERSION's install.sh and pipe it
# into sh, as the README does, in the scratch HOME.
newhome() { n=$((n + 1)); H=$root/home$n; mkdir -p "$H"; }
pipe() {
  fetcher=$1 v=$2
  shift 2
  case $fetcher in
    curl) curl -fsSL "$base/v$v/install.sh" ;;
    wget) wget -qO- "$base/v$v/install.sh" ;;
  esac | HOME=$H DOTFILES_RELEASE_BASE=$base DOTFILES_SKEL_DIR=$root/no-skel sh -s -- "$@" >"$root/out" 2>&1
}

# curl | sh, with a profile.
newhome
check "installs with curl | sh" pipe curl 9.9.9 --profile example
check "installs the release's files" test "$(cat "$H/.dotfiles/VERSION")" = 9.9.9
check "verifies the checksum" out_has '^verified SHA-256'
check "makes the CLI executable" test -x "$H/.dotfiles/bin/dotfiles"
check "links the CLI into ~/.local/bin" test "$(readlink "$H/.local/bin/dotfiles")" = "$H/.dotfiles/bin/dotfiles"
check "runs dotfiles init" grep -q '^# >>> dotfiles ' "$H/.zshrc"
check "points the blocks at ~/.dotfiles" grep -qF 'DOTFILES_DIR="$HOME/.dotfiles"' "$H/.zshrc"
check "selects the profile" test "$(cat "$H/.config/dotfiles/host")" = example
check "runs to the end of the piped script" out_has '^done: open a new terminal'
check "reports the installed version" sh -c '"$1" version | grep -qx "dotfiles 9.9.9"' _ "$H/.local/bin/dotfiles"

# Upgrade over that install: local profiles carry over, edits are backed up.
mkdir -p "$H/.dotfiles/hosts/mine"
printf 'export MINE=1\n' >"$H/.dotfiles/hosts/mine/env.sh"
printf '# local edit\n' >>"$H/.dotfiles/sh/env.sh"
check "upgrades an earlier release" pipe curl 9.9.10
check "installs the new version" test "$(cat "$H/.dotfiles/VERSION")" = 9.9.10
check "moves the old install aside" test "$(cat "$H/.dotfiles.previous-9.9.9/VERSION")" = 9.9.9
check "keeps local edits in the old install" grep -q '^# local edit$' "$H/.dotfiles.previous-9.9.9/sh/env.sh"
check "does not carry edits to shared files" fails grep -q '^# local edit$' "$H/.dotfiles/sh/env.sh"
check "carries over profiles made locally" test -f "$H/.dotfiles/hosts/mine/env.sh"
check "keeps the selected profile" test "$(cat "$H/.config/dotfiles/host")" = example

# wget | sh.
if command -v wget >/dev/null 2>&1; then
  newhome
  check "installs with wget | sh" pipe wget 9.9.9 --no-init
  check "installs the files with wget" test "$(cat "$H/.dotfiles/VERSION" 2>/dev/null)" = 9.9.9
fi

# Options.
newhome
pipe curl 9.9.9 --no-init
check "--no-init leaves the entry files alone" test ! -e "$H/.zshrc"
newhome
pipe curl 9.9.9 --version 9.9.10 --no-init
check "--version installs another release" test "$(cat "$H/.dotfiles/VERSION" 2>/dev/null)" = 9.9.10
newhome
pipe curl 9.9.9 --dir "$H/opt/df"
check "--dir installs elsewhere" test -f "$H/opt/df/bin/dotfiles"
check "points the blocks at --dir" grep -qF 'DOTFILES_DIR="$HOME/opt/df"' "$H/.zshrc"
# run_script FILE [ARGS...]: run an install.sh directly, offline, in the scratch HOME.
run_script() {
  script=$1
  shift
  HOME=$H DOTFILES_RELEASE_BASE=http://127.0.0.1:9 sh "$script" "$@" >"$root/out" 2>&1
}
newhome
check "--zip installs without the network" run_script "$d/install.sh" --zip "$d/backdrop-v9.9.9.zip" --no-init
check "installs from the ZIP" test "$(cat "$H/.dotfiles/VERSION" 2>/dev/null)" = 9.9.9

# Refusals: nothing is installed, nothing is touched.
newhome
check "fails on a checksum mismatch" fails pipe curl 9.9.11
check "says the checksum didn't match" out_has 'checksum mismatch'
check "installs nothing after a mismatch" test ! -e "$H/.dotfiles"
newhome
check "fails for a release that doesn't exist" fails pipe curl 9.9.9 --version 1.2.3
check "says it couldn't download" out_has 'could not download'
newhome
mkdir -p "$H/.dotfiles/.git"
check "refuses to replace a git clone" fails pipe curl 9.9.9
check "says to use git pull" out_has 'git pull'
check "leaves the clone alone" test -d "$H/.dotfiles/.git"
newhome
mkdir -p "$H/.dotfiles"
printf 'keep\n' >"$H/.dotfiles/notes.txt"
check "refuses to replace other files" fails pipe curl 9.9.9
check "leaves other files alone" test -f "$H/.dotfiles/notes.txt"
newhome
check "the repo's own install.sh needs --version" fails run_script "$repo/install.sh" --no-init
check "says why" out_has 'pass --version'

# Release notes come from CHANGELOG.md.
cat >"$src/CHANGELOG.md" <<'X'
# Changelog

## Unreleased

## 9.9.10 - 2026-01-02

- Newer change.

## 9.9.9 - 2026-01-01

- The change.
X
check "prints a version's notes" sh -c 'test "$(sh "$1" 9.9.9)" = "- The change."' _ "$src/scripts/release-notes.sh"
check "fails for a version with no notes" fails sh -c 'sh "$1" 1.0.0 2>/dev/null' _ "$src/scripts/release-notes.sh"

# scripts/release.sh, in a scratch clone of the repo with a bare origin.
rel=$root/rel
copy_tree "$rel"
printf '0.0.0\n' >"$rel/VERSION"
g -C "$rel" -c init.defaultBranch=main init -q
for k in user.name=dotfiles-test user.email=test@example.invalid commit.gpgsign=false tag.gpgsign=false core.hooksPath=/dev/null; do
  git -C "$rel" config "${k%%=*}" "${k#*=}"
done
git -C "$rel" add -A
git -C "$rel" commit -q -m base
git init -q --bare "$root/origin.git"
git -C "$rel" remote add origin "$root/origin.git"
git -C "$rel" push -q -u origin main 2>/dev/null
release() { DOTFILES_RELEASE_SKIP_TESTS=1 sh "$rel/scripts/release.sh" "$@" >"$root/out" 2>&1; }
has_tag() { git -C "$1" rev-parse -q --verify "refs/tags/$2" >/dev/null; }

check "rejects a version that isn't X.Y.Z" fails release 1.2
check "rejects a version that isn't newer" fails release 0.0.0
printf 'dirty\n' >>"$rel/README.md"
check "rejects uncommitted changes" fails release 0.1.0
git -C "$rel" checkout -q README.md
check "cuts a release" release 0.1.0
check "writes VERSION" test "$(cat "$rel/VERSION")" = 0.1.0
check "dates the changelog section" grep -qE '^## 0\.1\.0 - [0-9]{4}-[0-9]{2}-[0-9]{2}$' "$rel/CHANGELOG.md"
check "leaves an empty Unreleased section" sh -c 'awk "/^## /{if(on)exit; on=(\$2==\"Unreleased\"); next} on && /[^[:space:]]/{n++} END{exit n}" "$1"' _ "$rel/CHANGELOG.md"
check "commits the release" test "$(git -C "$rel" log -1 --format=%s)" = "release: v0.1.0"
check "tags it" has_tag "$rel" v0.1.0
check "doesn't push without --push" fails has_tag "$root/origin.git" v0.1.0
git -C "$rel" push -q origin main 2>/dev/null
check "rejects an empty Unreleased section" fails release 0.2.0
check "says so" out_has 'nothing under ## Unreleased'
awk '{ print } /^## Unreleased/ { print ""; print "- Another change." }' "$rel/CHANGELOG.md" >"$root/cl" && mv "$root/cl" "$rel/CHANGELOG.md"
git -C "$rel" commit -q -am "another change"
git -C "$rel" push -q origin main 2>/dev/null
check "cuts and pushes with --push" release 0.2.0 --push
check "pushes the tag" has_tag "$root/origin.git" v0.2.0
check "pushes main" test "$(git -C "$root/origin.git" rev-parse main)" = "$(git -C "$rel" rev-parse main)"

finish
