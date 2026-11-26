# hosts/example/env.sh
#
# PATH entries and exported variables for machines using this profile. To
# start a profile of your own, copy this whole directory:
#   cp -R hosts/example hosts/<name>
#
# This file loads right after sh/env.sh, in the same shells, so the same rules
# apply: POSIX sh, no output, no subprocesses, exports only. Because it loads
# second, it wins:
#   _df_path_prepend "$HOME/work/bin"   # searched before every shared entry
#   export EDITOR=nano                  # replaces the shared value

# With DOTFILES_TRACE=1, print this file's name as it loads, so you can check
# that the profile is being used.
_df_trace "hosts/${DOTFILES_PROFILE-}/env.sh"
