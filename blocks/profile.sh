# >>> dotfiles v1 >>> managed by `dotfiles init`; do not edit inside
DOTFILES_DIR="@DOTFILES_DIR@"   # repo path, written by init
[ -r "$DOTFILES_DIR/sh/env.sh" ] && . "$DOTFILES_DIR/sh/env.sh"
[ -r "$DOTFILES_DIR/hosts/${DOTFILES_PROFILE-}/env.sh" ] && . "$DOTFILES_DIR/hosts/${DOTFILES_PROFILE-}/env.sh"
# <<< dotfiles <<<
