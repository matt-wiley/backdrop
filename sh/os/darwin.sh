# sh/os/darwin.sh: macOS-only environment. Sourced from env.sh; same rules apply.
# /etc/zprofile runs path_helper after ~/.zshenv, which is why ~/.zprofile
# sources env.sh again: these prepends then land back in front.
_df_trace sh/os/darwin.sh

_df_path_prepend /usr/local/bin
_df_path_prepend /opt/homebrew/bin
