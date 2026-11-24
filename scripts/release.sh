#!/bin/sh
# scripts/release.sh X.Y.Z [--push]: cut a release.
#
# Checks that the tree is clean, on main and up to date, that X.Y.Z is newer
# than VERSION and that CHANGELOG.md has entries under "## Unreleased". Runs
# the tests, then writes VERSION, dates the changelog section, commits
# "release: vX.Y.Z" and tags vX.Y.Z. With --push it pushes main and the tag,
# which starts the release workflow; without it, it prints the push command.
set -eu

repo=$(cd "$(dirname "$0")/.." && pwd -P)
cd "$repo"
die() { printf 'release: %s\n' "$*" >&2; exit 1; }

push=0 version=
for a in "$@"; do
  case $a in
    --push) push=1 ;;
    -h | --help) sed -n '2,9s/^# \{0,1\}//p' "$0"; exit 0 ;;
    -*) die "unknown option: $a" ;;
    *) version=${a#v} ;;
  esac
done
[ -n "$version" ] || die "usage: scripts/release.sh X.Y.Z [--push]"

# semver_parts X.Y.Z: print "X Y Z", or fail.
semver_parts() {
  case $1 in *[!0-9.]* | .* | *. | *..* | '') return 1 ;; esac
  printf '%s\n' "$1" | awk -F. 'NF == 3 { print $1 + 0, $2 + 0, $3 + 0; ok = 1 } END { exit !ok }'
}
new=$(semver_parts "$version") || die "'$version' is not X.Y.Z"
old=$(semver_parts "$(cat VERSION)") || die "VERSION is not X.Y.Z"
newer=$(printf '%s\n%s\n' "$old" "$new" | awk 'NR == 1 { a = $1; b = $2; c = $3 }
  NR == 2 { print ($1 > a || ($1 == a && ($2 > b || ($2 == b && $3 > c)))) }')
[ "$newer" -eq 1 ] || die "$version is not newer than $(cat VERSION)"

[ "$(git rev-parse --abbrev-ref HEAD)" = main ] || die "releases are cut from main"
[ -z "$(git status --porcelain)" ] || die "the working tree has uncommitted changes"
git fetch -q origin main
[ "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" ] || die "main is not the same as origin/main; pull or push first"
! git rev-parse -q --verify "refs/tags/v$version" >/dev/null || die "tag v$version already exists"

unreleased=$(awk '/^## / { if (on) exit; on = ($2 == "Unreleased"); next } on && /[^[:space:]]/ { n++ } END { print n + 0 }' CHANGELOG.md)
[ "$unreleased" -gt 0 ] || die "CHANGELOG.md has nothing under ## Unreleased"

if [ "${DOTFILES_RELEASE_SKIP_TESTS-}" = 1 ]; then
  echo "release: skipping the tests (DOTFILES_RELEASE_SKIP_TESTS=1, for test/release.sh)"
else
  echo "release: running the tests"
  bin/dotfiles test >/dev/null 2>&1 || die "bin/dotfiles test failed; run it to see why"
fi

printf '%s\n' "$version" >VERSION
today=$(date +%Y-%m-%d)
awk -v v="$version" -v d="$today" '
  !done && /^## Unreleased[[:space:]]*$/ { print; print ""; print "## " v " - " d; done = 1; next }
  { print }' CHANGELOG.md >CHANGELOG.md.new
mv CHANGELOG.md.new CHANGELOG.md

git add VERSION CHANGELOG.md
git commit -q -m "release: v$version"
git tag -a "v$version" -m "v$version"
echo "release: committed and tagged v$version"

if [ "$push" -eq 1 ]; then
  git push --atomic origin main "v$version"
  echo "release: pushed; the release workflow publishes it"
else
  echo "release: publish with: git push --atomic origin main v$version"
fi
