# >>> dotfiles v2 >>> managed by `dotfiles init`; do not edit inside
DOTFILES_DIR="@DOTFILES_DIR@"   # repo path, written by init
[ -r "$DOTFILES_DIR/zsh/rc.zsh" ] && . "$DOTFILES_DIR/zsh/rc.zsh"
[ -r "$DOTFILES_DIR/hosts/${DOTFILES_PROFILE-}/rc.zsh" ] && . "$DOTFILES_DIR/hosts/${DOTFILES_PROFILE-}/rc.zsh"
# <<< dotfiles <<<
