# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="dracula"

plugins=(
    git
    git-extras
    colored-man-pages
    aws
    sudo
    zoxide
    history-substring-search
    zsh-syntax-highlighting
    zsh-autosuggestions
)

source "$ZSH/oh-my-zsh.sh"

# ── History ──

HISTSIZE=50000
SAVEHIST=50000
setopt SHARE_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE

# ── Environment ──

export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export EDITOR=vim
export SUDO_EDITOR="vim -u NONE"

# ── PATH ──

export PATH="$HOME/.local/bin:$PATH"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# ── nvm ──

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && source "$NVM_DIR/bash_completion"

# ── macOS-only ──

if [[ "$(uname -s)" == "Darwin" ]]; then
  # bun completions
  [ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

  # Antigravity
  export PATH="$HOME/.antigravity/antigravity/bin:$PATH"
fi

# ── Aliases ──

[ -f "$HOME/.aliases" ] && source "$HOME/.aliases"
