#!/bin/sh
# test/sync-env.sh: the environment.d file `dotfiles sync-env` writes (Linux only).
SUITE=sync-env
. "$(dirname "$0")/lib.sh"

[ "$(uname -s)" = Linux ] || { echo "skip  sync-env: Linux only"; exit 0; }

conf() { printf '%s' "$H/.config/environment.d/dotfiles.conf"; }
conf_has() { grep -qxF -- "$1" "$(conf)"; }
host_env() { printf '%s\n' "$@" >>"$H/.dotfiles/hosts/example/env.sh"; }
run_sync() { run_cli sync-env; }

# systemd's own generator, when present, shows what a login session would get.
GEN=/usr/lib/systemd/user-environment-generators/30-systemd-environment-d-generator
session_env() {
  env -i PATH=/usr/bin:/bin HOME="$H" XDG_CONFIG_HOME="$H/.config" "$GEN"
}

# init writes the file on Linux.
fresh
mkdir -p "$H/.local/bin"
run_init --profile example
check "init writes the file" test -f "$(conf)"
check "writes variables the env layer exports" conf_has 'DOTFILES_OS=linux'
check "writes PATH as a prefix of the session PATH" conf_has "PATH=$H/.local/bin:\${PATH}"
check "skips variables that aren't exported" fails grep -q '^DOTFILES_PROFILE=' "$(conf)"

# Host env.sh is included; values are written literally or skipped.
fresh
mkdir -p "$H/.local/bin" "$H/hostbin"
host_env 'export EDITOR=vim' 'export GREETING="hello world"' \
  'export PRICE="cost \$5"' 'export LIST="a:b"' "_df_path_prepend \"$H/hostbin\""
run_init --profile example
check "includes host exports" conf_has 'EDITOR=vim'
check "keeps spaces in values" conf_has 'GREETING=hello world'
check "writes new list variables literally" conf_has 'LIST=a:b'
check "orders host PATH entries first" conf_has "PATH=$H/hostbin:$H/.local/bin:\${PATH}"
check "skips values with \$" fails grep -q '^PRICE=' "$(conf)"
check "warns about the skipped value" out_has 'skipped PRICE'
if [ -x "$GEN" ]; then
  session_env >"$root/session"
  check "systemd reads values as written" grep -qxF 'GREETING="hello world"' "$root/session"
  check "systemd prepends to the session PATH" grep -qE "^PATH=$H/hostbin:$H/.local/bin:/" "$root/session"
fi

# Re-running is stable, and keeps the file current for doctor.
fresh
run_init --profile example
cp "$(conf)" "$root/before"
touch -t 202001010000 "$(conf)"
check "succeeds again" run_sync
check "reports an unchanged file as ok" out_has '^ok '
check "leaves content unchanged" cmp -s "$(conf)" "$root/before"
run_doctor
check "doctor sees the file as current" fails out_has 'is older than'

# Variables removed from the env layer disappear from the file.
fresh
host_env 'export TEMPVAR=1'
run_init --profile example
check "writes a host variable" conf_has 'TEMPVAR=1'
printf '' >"$H/.dotfiles/hosts/example/env.sh"
run_sync
check "drops it once removed" fails grep -q '^TEMPVAR=' "$(conf)"

# A noisy env layer is reported but still synced.
fresh
host_env 'echo hello from env.sh' 'export NOISY=1'
run_init --profile example
check "warns when the env layer prints" out_has 'printed output'
check "still writes the file" conf_has 'NOISY=1'

# A failing env layer writes nothing and fails.
fresh
run_init --profile example
cp "$(conf)" "$root/before"
host_env 'if then fi'
check "fails when the env layer fails" fails run_sync
check "keeps the previous file" cmp -s "$(conf)" "$root/before"

finish
