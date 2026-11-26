# Block templates

One template per shell entry file. `dotfiles init` replaces `@DOTFILES_DIR@`
with the repo path and writes the result as the first non-shebang content of
the target file, between the `>>> dotfiles` and `<<< dotfiles` markers.

| Template | Target |
| --- | --- |
| `profile.sh` | `~/.profile` |
| `bash_profile.sh` | `~/.bash_profile` |
| `bashrc.sh` | `~/.bashrc` |
| `zshenv.sh` | `~/.zshenv` |
| `zprofile.sh` | `~/.zprofile` |
| `zshrc.sh` | `~/.zshrc` |

Bump the version (`v1`, `v2`, ...) in the opening marker whenever a template
changes, so `init` can upgrade blocks in place and `doctor` can flag stale ones.
Keep every template on the same version, so `doctor` reports one block version.
