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

## Usage

```bash
dot add ~/.someconfig
dot commit -m "Add someconfig"
dot push
```

## What's included

| File | Description |
|---|---|
| `.tmux.conf` | tmux config with vi mode, security hardening, Dracula theme, cross-platform lock |

## Dependencies

- [tmux](https://github.com/tmux/tmux) + [TPM](https://github.com/tmux-plugins/tpm)
