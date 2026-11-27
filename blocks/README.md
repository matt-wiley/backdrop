# Block templates

One template per entry file: each shell startup file, and `~/.gitconfig`.
`dotfiles init` replaces `@DOTFILES_DIR@` with the repo path and writes the
result as the first non-shebang content of the target file, between the
`>>> dotfiles` and `<<< dotfiles` markers.

| Template | Target |
| --- | --- |
| `profile.sh` | `~/.profile` |
| `bash_profile.sh` | `~/.bash_profile` |
| `bashrc.sh` | `~/.bashrc` |
| `zshenv.sh` | `~/.zshenv` |
| `zprofile.sh` | `~/.zprofile` |
| `zshrc.sh` | `~/.zshrc` |
| `gitconfig` | `~/.gitconfig` |

The git template has no `.sh` extension because it's git config, not shell
code. git doesn't expand `$HOME`, so in that block `init` writes a repo path
inside your home directory as `~/...` instead. `doctor` reads the repo path
from its `path = ".../git/config"` line, since it has no `DOTFILES_DIR` line,
so keep that line in the template.

Bump the version (`v1`, `v2`, ...) in the opening marker whenever a template
changes, so `init` can upgrade blocks in place and `doctor` can flag stale ones.
Keep every template on the same version, so `doctor` reports one block version.
