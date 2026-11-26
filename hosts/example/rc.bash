# hosts/example/rc.bash
#
# Interactive bash settings for machines using this profile. To start a
# profile of your own, copy this whole directory:
#   cp -R hosts/example hosts/<name>
#
# This file loads right after bash/rc.bash, so anything here wins: redefine an
# alias to change it, or remove one you don't want on these machines:
#   alias gs='git status'
#   unalias la 2>/dev/null

# With DOTFILES_TRACE=1, print this file's name as it loads, so you can check
# that the profile is being used.
_df_trace "hosts/${DOTFILES_PROFILE-}/rc.bash"
