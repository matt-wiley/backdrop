# hosts/example/rc.zsh
#
# Interactive zsh settings for machines using this profile. To start a profile
# of your own, copy this whole directory:
#   cp -R hosts/example hosts/<name>
#
# This file loads right after zsh/rc.zsh, so anything here wins: redefine an
# alias to change it, or remove one you don't want on these machines:
#   alias gs='git status'
#   unalias la 2>/dev/null
#
# Plugins that must load last go in the shared list, which loads at the first
# prompt, after this file:
#   _df_load_last+=(/path/to/plugin.zsh)
#
# Completion functions can't be added here: zsh/rc.zsh has already set up
# completion by the time this file loads. Add them in zsh/rc.zsh instead.

# With DOTFILES_TRACE=1, print this file's name as it loads, so you can check
# that the profile is being used.
_df_trace "hosts/${DOTFILES_PROFILE-}/rc.zsh"
