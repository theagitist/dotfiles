# dotfiles

Personal configuration files and maintenance scripts. Designed to work on both Linux and macOS.

## Setup

```bash
# Clone on a new machine
git clone --bare git@github.com:theagitist/dotfiles.git ~/.dotfiles
alias dot='git --git-dir=$HOME/.dotfiles --work-tree=$HOME'
dot config status.showUntrackedFiles no
dot checkout
```

If `dot checkout` fails due to existing files, back them up first:
```bash
dot checkout 2>&1 | grep -E "^\s+" | xargs -I{} mv {} {}.bak
dot checkout
```

Then install all dependencies:
```bash
./setup.sh
```

## Usage

```bash
dot add ~/.someconfig
dot commit -m "Add someconfig"
dot push
```

## What's included

| File | Description |
|---|---|
| `.tmux.conf` | tmux config with vi mode, security hardening, Dracula theme, pane highlighting, cross-platform lock |
| `.zshrc` | zsh config with Dracula theme, oh-my-zsh plugins, nvm, bun, history settings, macOS/Linux guards |
| `.aliases` | portable aliases for eza, bat, zoxide, config editing, system info |
| `setup.sh` | idempotent bootstrap script — installs all dependencies on a new machine |
| `update.sh` | system maintenance script — updates packages, renews certs, cleans git branches, logs to `~/.local/log` |

## Dependencies

All managed by `setup.sh`:

- [oh-my-zsh](https://github.com/ohmyzsh/ohmyzsh) + Dracula theme, zsh-syntax-highlighting, zsh-autosuggestions
- [tmux](https://github.com/tmux/tmux) + [TPM](https://github.com/tmux-plugins/tpm)
- [nvm](https://github.com/nvm-sh/nvm) + Node.js
- [bun](https://bun.sh)
- [eza](https://github.com/eza-community/eza), [bat](https://github.com/sharkdp/bat), [zoxide](https://github.com/ajeetdsouza/zoxide), [gh](https://cli.github.com)
- Linux-only: nginx, certbot, vlock
