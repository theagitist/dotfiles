# dotfiles

![version](https://img.shields.io/badge/version-0.0.1-blue)

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
| `.zshrc` | zsh with Dracula theme, oh-my-zsh plugins, lazy-loaded nvm, bun, fzf, direnv, SSH agent, vi mode with cursor shape indicators, AUTO_CD, CORRECT, history settings, macOS/Linux guards |
| `.vimrc` | vim config with vim-plug, coc.nvim, fzf, NERDTree, fugitive, Dracula theme, persistent undo, Space leader |
| `.tmux.conf` | tmux with vi mode, Dracula theme, resurrect/continuum, thumbs (quick-copy), prefix-less Alt bindings, pane border labels, auto-rename windows, security hardening, cross-platform lock |
| `.gitconfig` | shared git config with delta pager (side-by-side, Dracula), histogram diffs, aliases (switch/restore), auto-stash rebase, auto-setup remote, rerere, diff3 merge, local include for machine-specific settings |
| `.aliases` | portable aliases for eza, bat, fd, zoxide, lazygit, trash-cli, duf, curlie, mkcd, grep color, config editing, system info |
| `setup.sh` | idempotent bootstrap script — installs all dependencies, sets timezone, adds weekly update cron |
| `update.sh` | system maintenance script — updates packages, bun, node, tmux plugins, renews certs, cleans git branches, logs to `~/.local/log` |

## Dependencies

All managed by `setup.sh`:

- [oh-my-zsh](https://github.com/ohmyzsh/ohmyzsh) + Dracula theme, zsh-syntax-highlighting, zsh-autosuggestions, [you-should-use](https://github.com/MichaelAquilina/zsh-you-should-use), extract, dirhistory, copypath
- [vim](https://www.vim.org) + [vim-plug](https://github.com/junegunn/vim-plug) + [coc.nvim](https://github.com/neoclide/coc.nvim)
- [tmux](https://github.com/tmux/tmux) + [TPM](https://github.com/tmux-plugins/tpm) (resurrect, continuum, yank, menus, [thumbs](https://github.com/fcsonline/tmux-thumbs))
- [nvm](https://github.com/nvm-sh/nvm) + Node.js (lazy-loaded)
- [bun](https://bun.sh)
- [delta](https://github.com/dandavison/delta), [eza](https://github.com/eza-community/eza), [bat](https://github.com/sharkdp/bat), [zoxide](https://github.com/ajeetdsouza/zoxide), [fd](https://github.com/sharkdp/fd), [ripgrep](https://github.com/BurntSushi/ripgrep), [fzf](https://github.com/junegunn/fzf), [jq](https://github.com/jqlang/jq), [duf](https://github.com/muesli/duf), [entr](https://github.com/eradman/entr), [w3m](https://w3m.sourceforge.net)
- [trash-cli](https://github.com/andreafrancia/trash-cli), [direnv](https://direnv.net), [curlie](https://github.com/rs/curlie), [yq](https://github.com/mikefarah/yq), [glow](https://github.com/charmbracelet/glow)
- [lazygit](https://github.com/jesseduffield/lazygit), [gh](https://cli.github.com), [git-extras](https://github.com/tj/git-extras)
- [ncdu](https://dev.yorhel.nl/ncdu), [htop](https://htop.dev), [bpytop](https://github.com/aristocratos/bpytop), [tldr](https://tldr.sh)
- [awscli](https://aws.amazon.com/cli/)
- Linux-only: nginx, certbot, vlock
