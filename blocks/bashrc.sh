# >>> dotfiles v1 >>> managed by `dotfiles init`; do not edit inside
DOTFILES_DIR="@DOTFILES_DIR@"   # repo path, written by init
[ -r "$DOTFILES_DIR/sh/env.sh" ] && . "$DOTFILES_DIR/sh/env.sh"
[ -r "$DOTFILES_DIR/hosts/${DOTFILES_PROFILE-}/env.sh" ] && . "$DOTFILES_DIR/hosts/${DOTFILES_PROFILE-}/env.sh"
case $- in
  *i*)
    [ -r "$DOTFILES_DIR/sh/interactive.sh" ] && . "$DOTFILES_DIR/sh/interactive.sh"
    [ -r "$DOTFILES_DIR/hosts/${DOTFILES_PROFILE-}/interactive.sh" ] && . "$DOTFILES_DIR/hosts/${DOTFILES_PROFILE-}/interactive.sh"
    [ -r "$DOTFILES_DIR/bash/rc.bash" ] && . "$DOTFILES_DIR/bash/rc.bash"
    [ -r "$DOTFILES_DIR/hosts/${DOTFILES_PROFILE-}/rc.bash" ] && . "$DOTFILES_DIR/hosts/${DOTFILES_PROFILE-}/rc.bash"
    ;;
esac
# <<< dotfiles <<<
