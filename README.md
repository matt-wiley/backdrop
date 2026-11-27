# backdrop

Shell dotfiles for bash, zsh and POSIX `sh` on Linux and macOS: each setting is written once, and a small injected block at the top of each startup file loads it.

## Install

You need Linux or macOS, and git. Clone the repo, put the `dotfiles` command on your `PATH`, and run `init`:

```sh
git clone https://github.com/matt-wiley/backdrop.git ~/.dotfiles
mkdir -p ~/.local/bin
ln -s ~/.dotfiles/bin/dotfiles ~/.local/bin/dotfiles
~/.dotfiles/bin/dotfiles init --profile <name>
```

Then open a new terminal and run `dotfiles doctor`. [Getting started](docs/user/01-getting-started.md) explains profiles and each step.

Your edits are ordinary commits in the clone. To pick up changes from another machine, run `git pull`, then `dotfiles doctor`; if it says a block is out of date, run `dotfiles init`.

## Where to put a setting

|  | Every machine | One profile |
| --- | --- | --- |
| **Scripts need it** (`PATH`, exports) | `sh/env.sh` | `hosts/<profile>/env.sh` |
| **Only you need it** (aliases, options, prompt, tools, plugins) | `zsh/rc.zsh` or `bash/rc.bash` | `hosts/<profile>/rc.zsh` or `rc.bash` |
| **Git** (settings, aliases, global ignores) | `git/config`, `git/ignore` | None yet; one machine's settings go below the block in `~/.gitconfig` |

## Documentation

- [Getting started](docs/user/01-getting-started.md): set up a machine and add your own settings.
- [Editing the layers](docs/user/02-editing-layers.md): examples for each kind of change, layer by layer.
- [Spec](docs/developer/specs/dotfiles-system-spec.md): the design and the reasons behind it.
