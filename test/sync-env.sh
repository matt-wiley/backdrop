#!/bin/sh
# test/sync-env.sh
#
# Checks `dotfiles sync-env`, which writes ~/.config/environment.d/dotfiles.conf
# from the variables the env layer exports. On Linux, the desktop session
# and the services systemd starts don't come from a shell, so they never load
# env.sh. systemd reads this file at login instead, which gives them the same
# PATH and variables a shell gets. The file is not shell syntax, so the checks
# focus on what is written, what is skipped, and how systemd reads it.
#
# environment.d is a systemd feature, so the suite runs only on Linux and
# skips itself elsewhere. Each case runs in a new scratch home directory with
# its own copy of the repo (see test/lib.sh). Run it alone with
# `sh test/sync-env.sh`.
SUITE=sync-env
. "$(dirname "$0")/lib.sh"

[ "$(uname -s)" = Linux ] || { echo "skip  sync-env: Linux only"; exit 0; }

# conf
#
# Prints the path of the file sync-env writes in the scratch home.
conf() { printf '%s' "$H/.config/environment.d/dotfiles.conf"; }

# conf_has LINE
#
# Succeeds if the file has a line exactly equal to LINE. -F and -x make grep
# compare whole lines as plain text, so characters such as $ and . in LINE
# aren't read as a pattern.
conf_has() { grep -qxF -- "$1" "$(conf)"; }

# host_env LINE...
#
# Appends each LINE to the example profile's env.sh in the case's copy. The
# ~/.profile block loads the profile's env.sh after the shared one, so its
# exports should end up in the file too.
host_env() { printf '%s\n' "$@" >>"$H/.dotfiles/hosts/example/env.sh"; }

# run_sync
#
# Runs sync-env on its own, without the rest of init.
run_sync() { run_cli sync-env; }

# GEN is systemd's own generator, the program that reads environment.d files
# at login. When it is installed, the tests run it on the file and check what
# a login session would really get. That catches values systemd reads
# differently from how sync-env meant them.
#
# session_env runs the generator with an empty environment and with
# XDG_CONFIG_HOME pointing into the scratch home, so it reads the test's file
# instead of your own and starts from a known PATH.
GEN=/usr/lib/systemd/user-environment-generators/30-systemd-environment-d-generator
session_env() {
  env -i PATH=/usr/bin:/bin HOME="$H" XDG_CONFIG_HOME="$H/.config" "$GEN"
}

# init runs sync-env on Linux, so the file exists right after init.
# ~/.local/bin is created first because _df_path_prepend skips directories
# that don't exist, and the PATH check needs an entry. PATH is written as a
# list ending in ${PATH}, so systemd puts the entries in front of the
# session's PATH instead of replacing it. Only exported variables belong in
# the file. DOTFILES_PROFILE is a plain shell variable, so it must be left
# out.
fresh
mkdir -p "$H/.local/bin"
run_init --profile example
check "init writes the file" test -f "$(conf)"
check "writes variables the env layer exports" conf_has 'DOTFILES_OS=linux'
check "writes PATH as a prefix of the session PATH" conf_has "PATH=$H/.local/bin:\${PATH}"
check "skips variables that aren't exported" fails grep -q '^DOTFILES_PROFILE=' "$(conf)"

# Exports from the profile's env.sh are included too. Values with spaces are
# written as they are, without quotes. LIST contains a colon but is a new
# variable, so there is no session value to extend, and it is written as it
# is too. The profile's PATH entry must come first, as it does in a shell.
#
# systemd expands $ in environment.d values, even when it is escaped, so a
# value containing $ can't be written safely. sync-env skips it with a
# warning. In env.sh, `\$5` inside double quotes gives PRICE a literal dollar
# sign.
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

# Running sync-env again on an unchanged env layer writes the same content
# and reports ok. It must still update the file's timestamp, because doctor
# compares that timestamp with env.sh to decide whether the file is out of
# date. The file is backdated to 2020 first, so a timestamp left alone would
# show up as a doctor warning.
fresh
run_init --profile example
cp "$(conf)" "$root/before"
touch -t 202001010000 "$(conf)"
check "succeeds again" run_sync
check "reports an unchanged file as ok" out_has '^ok '
check "leaves content unchanged" cmp -s "$(conf)" "$root/before"
run_doctor
check "doctor sees the file as current" fails out_has 'is older than'

# sync-env rewrites the whole file each time, so a variable removed from the
# env layer disappears from the file instead of lingering in later sessions.
# Emptying the profile's env.sh removes TEMPVAR.
fresh
host_env 'export TEMPVAR=1'
run_init --profile example
check "writes a host variable" conf_has 'TEMPVAR=1'
printf '' >"$H/.dotfiles/hosts/example/env.sh"
run_sync
check "drops it once removed" fails grep -q '^TEMPVAR=' "$(conf)"

# An env layer that prints breaks the rule that env.sh is silent, so
# sync-env warns. Its variables are still usable, so it writes the file
# anyway.
fresh
host_env 'echo hello from env.sh' 'export NOISY=1'
run_init --profile example
check "warns when the env layer prints" out_has 'printed output'
check "still writes the file" conf_has 'NOISY=1'

# If the env layer fails, here with a syntax error, its variables can't be
# trusted. sync-env must exit non-zero and keep the previous file, so the
# next login still gets the last good environment.
fresh
run_init --profile example
cp "$(conf)" "$root/before"
host_env 'if then fi'
check "fails when the env layer fails" fails run_sync
check "keeps the previous file" cmp -s "$(conf)" "$root/before"

finish
