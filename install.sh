#!/bin/sh
# install.sh: install a dotfiles release without git.
#
#   curl -fsSL https://github.com/matt-wiley/backdrop/releases/latest/download/install.sh | sh
#   wget -qO- https://github.com/matt-wiley/backdrop/releases/latest/download/install.sh | sh
#
# Pass options after `sh -s --`, for example: ... | sh -s -- --profile laptop
#
# Each release attaches a copy of this script with RELEASE_VERSION filled in,
# so it installs its own release unless --version picks another.
# Everything runs inside main(), called on the last line, so a download cut
# short never runs half a script.

REPO=matt-wiley/backdrop
NAME=backdrop
RELEASE_VERSION=@VERSION@ # stamped by scripts/build-release.sh

usage() {
  cat <<USAGE
usage: install.sh [options]

Installs a release of $REPO and runs \`dotfiles init\`.

options:
  --version X.Y.Z   install this release (default: ${RELEASE_VERSION})
  --dir PATH        install here (default: ~/.dotfiles)
  --profile NAME    select this machine's profile (passed to dotfiles init)
  --no-init         install the files only; don't run dotfiles init
  --zip FILE        install from a downloaded release ZIP, without the network
  -h, --help        show this help

environment:
  DOTFILES_RELEASE_BASE   where releases are downloaded from
                          (default: https://github.com/$REPO/releases/download)
USAGE
}

say() { printf '%s\n' "$*"; }
warn() { printf 'install.sh: warning: %s\n' "$*" >&2; }
die() { printf 'install.sh: %s\n' "$*" >&2; exit 1; }

# fetch URL FILE: download with curl or wget.
fetch() {
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL -o "$2" "$1" </dev/null
  elif command -v wget >/dev/null 2>&1; then
    wget -q -O "$2" "$1" </dev/null
  else
    die "needs curl or wget to download the release"
  fi
}

# sha256 FILE: print the file's SHA-256, or nothing if no tool can.
sha256() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{ print $1 }'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{ print $1 }'
  elif command -v openssl >/dev/null 2>&1; then
    openssl dgst -sha256 "$1" | awk '{ print $NF }'
  fi
}

# extract ZIP DIR: unzip with whatever this machine has.
extract() {
  if command -v unzip >/dev/null 2>&1; then
    unzip -q -o "$1" -d "$2" </dev/null
  elif command -v python3 >/dev/null 2>&1; then
    python3 -m zipfile -e "$1" "$2" </dev/null
  elif command -v bsdtar >/dev/null 2>&1; then
    bsdtar -xf "$1" -C "$2" </dev/null
  else
    die "needs unzip, python3 or bsdtar to extract the release"
  fi
}

main() {
  set -eu
  version=$RELEASE_VERSION dir=$HOME/.dotfiles profile= init=1 zip=
  while [ $# -gt 0 ]; do
    case $1 in
      --version) [ $# -ge 2 ] || die "--version needs a value"; version=${2#v}; shift 2 ;;
      --version=*) version=${1#--version=}; version=${version#v}; shift ;;
      --dir) [ $# -ge 2 ] || die "--dir needs a path"; dir=$2; shift 2 ;;
      --dir=*) dir=${1#--dir=}; shift ;;
      --profile) [ $# -ge 2 ] || die "--profile needs a name"; profile=$2; shift 2 ;;
      --profile=*) profile=${1#--profile=}; shift ;;
      --no-init) init=0; shift ;;
      --zip) [ $# -ge 2 ] || die "--zip needs a file"; zip=$2; shift 2 ;;
      --zip=*) zip=${1#--zip=}; shift ;;
      -h | --help) usage; return 0 ;;
      *) die "unknown option: $1 (see --help)" ;;
    esac
  done
  case $dir in /*) ;; *) dir=$PWD/$dir ;; esac
  dir=${dir%/}
  base=${DOTFILES_RELEASE_BASE:-https://github.com/$REPO/releases/download}

  tmp=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-install.XXXXXX")
  stage=
  trap 'rm -rf "$tmp"; [ -z "$stage" ] || rm -rf "$stage"' EXIT
  trap 'exit 130' INT TERM

  # 1. Get the ZIP: a local file, or a verified download.
  if [ -n "$zip" ]; then
    [ -f "$zip" ] || die "no such file: $zip"
    cp "$zip" "$tmp/release.zip"
    say "using    $zip"
  else
    case $version in
      @*) die "this copy of install.sh isn't from a release; pass --version X.Y.Z" ;;
    esac
    asset=$NAME-v$version.zip
    url=$base/v$version
    say "download $url/$asset"
    fetch "$url/$asset" "$tmp/release.zip" || die "could not download $url/$asset (is v$version a published release?)"
    fetch "$url/SHA256SUMS" "$tmp/SHA256SUMS" || die "could not download $url/SHA256SUMS; not installing an unverified release"
    want=$(awk -v f="$asset" '$2 == f || $2 == "*" f { print $1 }' "$tmp/SHA256SUMS")
    [ -n "$want" ] || die "SHA256SUMS has no entry for $asset"
    have=$(sha256 "$tmp/release.zip")
    if [ -z "$have" ]; then
      warn "no sha256sum, shasum or openssl here; skipping the checksum check"
    elif [ "$have" != "$want" ]; then
      die "checksum mismatch for $asset; not installing (expected $want, got $have)"
    else
      say "verified SHA-256 of $asset"
    fi
  fi

  # 2. Extract next to the target, so the final move stays on one filesystem.
  parent=$(dirname "$dir")
  mkdir -p "$parent"
  stage=$(mktemp -d "$parent/.dotfiles-install.XXXXXX")
  extract "$tmp/release.zip" "$stage"
  set -- "$stage"/*/
  [ $# -eq 1 ] && [ -f "$1/bin/dotfiles" ] && [ -f "$1/VERSION" ] ||
    die "the ZIP doesn't look like a $NAME release"
  new=${1%/}
  new_version=$(cat "$new/VERSION")
  chmod +x "$new/bin/dotfiles" "$new/install.sh" # extractors other than unzip drop modes

  # 3. Make room: replace an earlier release, never a git clone or other files.
  if [ -e "$dir" ] && [ -n "$(ls -A "$dir" 2>/dev/null)" ]; then
    if [ -e "$dir/.git" ]; then
      die "$dir is a git clone; update it with git pull instead"
    fi
    [ -f "$dir/VERSION" ] && [ -f "$dir/bin/dotfiles" ] ||
      die "$dir exists and isn't a dotfiles install; move it or pass --dir"
    old_version=$(cat "$dir/VERSION")
    backup=$dir.previous-$old_version
    [ ! -e "$backup" ] || backup=$backup-$(date +%Y%m%d%H%M%S)
    # Profiles made on this machine aren't in the release; carry them over.
    for p in "$dir"/hosts/*/; do
      [ -d "$p" ] || continue
      p=${p%/}
      [ -e "$new/hosts/${p##*/}" ] || cp -R "$p" "$new/hosts/"
    done
    mv "$dir" "$backup"
    say "moved    $old_version to $backup (copy back any files you changed there)"
  elif [ -e "$dir" ]; then
    rmdir "$dir"
  fi
  mv "$new" "$dir"
  say "installed $NAME $new_version in $dir"

  # 4. Put the CLI on PATH (the env layer adds ~/.local/bin).
  link=$HOME/.local/bin/dotfiles
  if [ -L "$link" ] || [ ! -e "$link" ]; then
    mkdir -p "$HOME/.local/bin"
    ln -sfn "$dir/bin/dotfiles" "$link"
    say "linked   $link"
  else
    warn "$link exists and isn't a symlink; left it alone"
  fi

  # 5. Inject the blocks. stdin is the piped script itself, so keep it away from children.
  if [ "$init" -eq 1 ]; then
    if [ -n "$profile" ]; then
      "$dir/bin/dotfiles" init --profile "$profile" </dev/null
    else
      "$dir/bin/dotfiles" init </dev/null
    fi
    say "done: open a new terminal, then run \`dotfiles doctor\`"
  else
    say "done: run \`$dir/bin/dotfiles init\` to activate it"
  fi
}

main "$@"
