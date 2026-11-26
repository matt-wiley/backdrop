# >>> dotfiles v2 >>> managed by `dotfiles init`; do not edit inside
DOTFILES_DIR="@DOTFILES_DIR@"   # repo path, written by init
[ -r "$HOME/.profile" ] && . "$HOME/.profile"
case $- in *i*) [ -r "$HOME/.bashrc" ] && . "$HOME/.bashrc" ;; esac
# <<< dotfiles <<<
