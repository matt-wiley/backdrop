#!/bin/sh
# scripts/release-notes.sh X.Y.Z: print the CHANGELOG.md section for X.Y.Z.
set -eu
repo=$(cd "$(dirname "$0")/.." && pwd -P)
[ $# -eq 1 ] || { echo "usage: scripts/release-notes.sh X.Y.Z" >&2; exit 2; }
awk -v v="$1" '
  /^## / { if (on) exit; on = ($2 == v) ; next }
  on { print }
' "$repo/CHANGELOG.md" | sed -e '/./,$!d' >"${TMPDIR:-/tmp}/release-notes.$$"
if [ ! -s "${TMPDIR:-/tmp}/release-notes.$$" ]; then
  rm -f "${TMPDIR:-/tmp}/release-notes.$$"
  echo "release-notes: no section for $1 in CHANGELOG.md" >&2
  exit 1
fi
cat "${TMPDIR:-/tmp}/release-notes.$$"
rm -f "${TMPDIR:-/tmp}/release-notes.$$"
