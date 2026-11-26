#!/bin/sh
# test/install.sh
#
# Checks `dotfiles install`, which installs the tools listed in
# packages.toml with the system package manager. It covers the dry-run plan,
# the exact commands run for each manager, the profile's own package list,
# and runtimes installed through mise.
#
# Nothing is really installed. The suite puts fake versions of sudo,
# apt-get, dnf, pacman and brew at the front of PATH, and they only log how
# they were called. Each case also replaces packages.toml with made-up
# tools, so the results don't depend on what this machine has installed.
#
# Each case runs in a new scratch home directory with its own copy of the
# repo (see test/lib.sh). Run it alone with `sh test/install.sh`.
SUITE=install
. "$(dirname "$0")/lib.sh"

FAKEBIN=$root/fakebin
LOG=$root/log
mkdir -p "$FAKEBIN"
# The fake. sudo and every manager are symlinks to this one script, which
# tells which command it is from the name it was called by. ${0##*/} strips
# the directory from that name. The fake does the following:
#
# - It appends its name and arguments to $LOG, so checks can assert exactly
#   what ran.
# - It exits with an error if FAIL holds its name, to test a failing manager.
# - As sudo, it runs the rest of its arguments, so `sudo apt-get ...` logs
#   both commands.
# - Otherwise, it copies itself into FAKEBIN under the name of each package
#   it was given, so the package appears on PATH as if installed. That lets
#   install's check for commands that are still missing see real results.
#   Options and the words install, update and use are skipped, and ${a%%@*}
#   drops a version such as @1 from a mise spec. mise has no fake of its own
#   at first. It appears when a fake manager installs the mise package.
#
# The heredoc delimiter is quoted ('X'), so $LOG and the other expansions are
# written into the script as they are and expanded when the fake runs. That
# is why FAKEBIN and LOG are exported below.
cat >"$FAKEBIN/fake" <<'X'
#!/bin/sh
me=${0##*/}
printf '%s\n' "$me $*" >>"$LOG"
[ "${FAIL-}" != "$me" ] || exit 1
[ "$me" != sudo ] || exec "$@"
for a in "$@"; do
  case $a in -* | install | update | use) ;; *) cp "$0" "$FAKEBIN/${a%%@*}" ;; esac
done
X
chmod +x "$FAKEBIN/fake"
for m in sudo apt-get dnf pacman brew; do ln -s fake "$FAKEBIN/$m"; done
PATH=$FAKEBIN:$PATH
export FAKEBIN LOG PATH

# setup
#
# Starts a case with a fresh scratch home and a packages.toml that lists
# only made-up tools, each set up to test one thing:
#
# - df-alpha has a package for every manager.
# - df-beta has a different package name on apt, df-beta-tools. Its bin key
#   names commands that package doesn't provide, so after an apt install it
#   still looks missing.
# - df-present is already installed, as a copy of the fake on PATH.
# - df-brewonly has only a brew package, so the other managers skip it.
#
# It also empties the log and removes the tools that earlier cases installed
# into FAKEBIN, so each case starts with nothing installed.
setup() {
  fresh
  rm -f "$LOG" "$FAKEBIN"/df-*
  : >"$LOG"
  cat >"$H/.dotfiles/packages.toml" <<'X'
[df-alpha]
apt = "df-alpha"
dnf = "df-alpha"
pacman = "df-alpha"
brew = "df-alpha"

[df-beta]
bin = "df-beta df-betacmd"
apt = "df-beta-tools"
brew = "df-beta"

[df-present]
apt = "df-present"

[df-brewonly]
brew = "df-brewonly"
X
  cp "$FAKEBIN/fake" "$FAKEBIN/df-present"
}

# logged LINE
#
# Succeeds if a fake was called with exactly LINE, its name followed by its
# arguments.
logged() { grep -qxF -- "$1" "$LOG"; }

# Without --yes, install is a dry run. It prints the plan and the exact
# commands it would run, including what would run with sudo, and runs
# nothing, so the user can review it before agreeing.
setup
check "dry run succeeds" run_cli install --manager apt
check "names the manager" out_has '^manager  apt \(with sudo\)$'
check "skips installed tools" out_has '^ok       df-present$'
check "plans missing tools" out_has '^install  df-alpha via apt \(df-alpha\)$'
check "uses the manager's package name" out_has '^install  df-beta via apt \(df-beta-tools\)$'
check "skips tools without a package" out_has '^skip     df-brewonly \(no apt package'
check "shows the install command" out_has '^would run  sudo apt-get install -y df-alpha df-beta-tools$'
check "says it is a dry run" out_has '^dry run'
check "runs nothing" test ! -s "$LOG"

# With --yes, install runs one install command for all the missing packages,
# and for apt it runs apt-get update first. Afterwards it warns about any
# tool whose commands still aren't on PATH, which here is df-beta.
setup
check "apt install succeeds" run_cli install --manager apt --yes
check "updates apt first" logged 'sudo apt-get update'
check "installs with apt-get" logged 'sudo apt-get install -y df-alpha df-beta-tools'
check "warns when a package's commands don't appear" out_has "df-beta is still missing"
check "does not warn for a tool that appeared" fails out_has "df-alpha is still missing"

# The install command for each of the other managers. System managers run
# through sudo, but brew never does.
setup
run_cli install --manager dnf --yes
check "installs with dnf" logged 'sudo dnf install -y df-alpha'
setup
run_cli install --manager pacman --yes
check "installs with pacman" logged 'sudo pacman -S --needed --noconfirm df-alpha'
setup
run_cli install --manager brew --yes
check "installs with brew, without sudo" logged 'brew install df-alpha df-beta df-brewonly'
check "never calls sudo for brew" fails grep -q '^sudo ' "$LOG"

# When every tool with an apt package is already installed, there is nothing
# to do and no manager runs. df-betacmd stands in for df-beta, because any
# one of the commands in its bin key counts.
setup
cp "$FAKEBIN/fake" "$FAKEBIN/df-alpha"
cp "$FAKEBIN/fake" "$FAKEBIN/df-betacmd"
run_cli install --manager apt --yes
check "reports nothing to install" out_has '^nothing to install$'
check "runs no commands" test ! -s "$LOG"

# A manager command that fails must make install fail and name the command,
# so the user doesn't think the tools were installed. FAIL makes the fake
# apt-get exit with an error, and it is unset afterwards so later cases
# aren't affected.
setup
FAIL=apt-get
export FAIL
check "fails when the manager fails" fails run_cli install --manager apt --yes
check "reports the failed command" out_has 'command failed: sudo apt-get update'
unset FAIL

# A profile's packages.toml can add tools and replace a shared tool's table.
# init selects the example profile first, so install reads that profile's
# list.
setup
run_init --profile example
cat >"$H/.dotfiles/hosts/example/packages.toml" <<'X'
[df-gamma]
apt = "df-gamma"

[df-alpha]
apt = "df-alpha-host"
X
run_cli install --manager apt
check "adds profile tools" out_has '^install  df-gamma via apt'
check "lets the profile replace a shared tool" out_has '^install  df-alpha via apt \(df-alpha-host\)$'
check "lists a replaced tool once" test "$(grep -c 'df-alpha via' "$root/out")" -eq 1

# Tools with a mise key are installed with `mise use -g` after the package
# manager has run, because mise itself may be one of the packages being
# installed. When mise is neither available nor planned, those tools are
# skipped with a warning. That check runs only when this machine has no real
# mise on PATH, since install would use a real one. Then a mise table is
# added, so apt installs mise first and the runtime follows. The fake mise
# that the apt install created is removed at the end, so later cases don't
# see mise as installed.
setup
cat >>"$H/.dotfiles/packages.toml" <<'X'

[df-runtime]
mise = "df-runtime@1"
X
run_cli install --manager apt
if ! command -v mise >/dev/null 2>&1; then
  check "skips mise tools when mise can't be installed" out_has 'skipped df-runtime@1: mise'
fi
printf '\n[mise]\napt = "mise"\n' >>"$H/.dotfiles/packages.toml"
run_cli install --manager apt
check "plans mise tools when mise is planned" out_has '^would run  mise use -g df-runtime@1$'
run_cli install --manager apt --yes
check "installs mise first" logged 'sudo apt-get install -y df-alpha df-beta-tools mise'
check "then the runtime" logged 'mise use -g df-runtime@1'
rm -f "$FAKEBIN/mise"

# Tools with no command, such as zsh plugins, list files in a `file` array
# instead. Any one of the files existing counts as installed, and the table's
# name isn't checked as a command, so df-plugin on PATH doesn't count. The
# paths include a space, which arrays allow. `bin` can be an array too, here
# spread over lines with a comment, and the table after it must still be
# read.
setup
mkdir -p "$root/plugin dir"
rm -f "$root/plugin dir/"*
cat >>"$H/.dotfiles/packages.toml" <<X

[df-plugin]
file = [
  "$root/plugin dir/missing.zsh",
  "$root/plugin dir/df-plugin.zsh",  # the one this case creates
]
apt = "df-plugin"

[df-arr]
bin = [
  "df-arr-a",
  "df-arr-b",
]
apt = "df-arr"

[df-inline]
bin = ["df-inline-a", "df-inline-b"]  # a comment
apt = "df-inline"
X
cp "$FAKEBIN/fake" "$FAKEBIN/df-plugin"
cp "$FAKEBIN/fake" "$FAKEBIN/df-arr-b"
cp "$FAKEBIN/fake" "$FAKEBIN/df-inline-b"
run_cli install --manager apt
check "plans a plugin whose files are missing" out_has '^install  df-plugin via apt \(df-plugin\)$'
check "reads a multi-line bin array" out_has '^ok       df-arr$'
check "reads a one-line bin array" out_has '^ok       df-inline$'
: >"$root/plugin dir/df-plugin.zsh"
run_cli install --manager apt
check "counts a plugin whose file exists" out_has '^ok       df-plugin$'
rm -f "$root/plugin dir/df-plugin.zsh"
run_cli install --manager apt --yes
check "warns when a plugin's files don't appear" out_has "df-plugin is still missing; none of .* exists"

# Unknown managers and options are rejected rather than ignored.
setup
check "rejects an unknown manager" fails run_cli install --manager nope
check "rejects an unknown option" fails run_cli install --force

finish
