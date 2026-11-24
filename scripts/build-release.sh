#!/bin/sh
# scripts/build-release.sh [OUTDIR]: build the release files for HEAD.
#
# Writes to OUTDIR (default: dist/):
#   backdrop-vX.Y.Z.zip   the whole repo at HEAD, under backdrop-vX.Y.Z/
#   install.sh              the installer, stamped with X.Y.Z
#   SHA256SUMS              checksums of both
# X.Y.Z comes from VERSION as committed at HEAD; uncommitted changes are left out.
set -eu

repo=$(cd "$(dirname "$0")/.." && pwd -P)
out=${1:-$repo/dist}
name=backdrop

git -C "$repo" rev-parse --git-dir >/dev/null 2>&1 || {
  echo "build-release: $repo is not a git repository" >&2
  exit 1
}
version=$(git -C "$repo" show HEAD:VERSION)
case $version in
  *[!0-9.]* | .* | *. | *..* | '') echo "build-release: VERSION '$version' is not X.Y.Z" >&2; exit 1 ;;
esac
[ "$(printf '%s' "$version" | tr -cd . | wc -c)" -eq 2 ] || {
  echo "build-release: VERSION '$version' is not X.Y.Z" >&2
  exit 1
}

mkdir -p "$out"
out=$(cd "$out" && pwd -P)
zip=$name-v$version.zip
rm -f "$out/$zip" "$out/install.sh" "$out/SHA256SUMS"

git -C "$repo" archive --format=zip --prefix="$name-v$version/" -o "$out/$zip" HEAD
git -C "$repo" show HEAD:install.sh |
  sed "s/^RELEASE_VERSION=@VERSION@ /RELEASE_VERSION=$version /" >"$out/install.sh"
grep -q "^RELEASE_VERSION=$version " "$out/install.sh" || {
  echo "build-release: could not stamp the version into install.sh" >&2
  exit 1
}
chmod +x "$out/install.sh"

cd "$out"
if command -v sha256sum >/dev/null 2>&1; then
  sha256sum "$zip" install.sh >SHA256SUMS
else
  shasum -a 256 "$zip" install.sh >SHA256SUMS
fi
echo "built v$version in $out:"
ls -1 "$out" | sed 's/^/  /'
