# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# ── PATH (before oh-my-zsh so plugins can find binaries) ──

export PATH="$HOME/.local/bin:$PATH"
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

ZSH_THEME="dracula"

plugins=(
    git
    git-extras
    colored-man-pages
    aws
    sudo
    zoxide
    extract
    dirhistory
    copypath
    history-substring-search
    you-should-use
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
setopt HIST_FIND_NO_DUPS
setopt HIST_REDUCE_BLANKS
setopt AUTO_CD
setopt CORRECT

# ── Environment ──

export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export EDITOR=vim
export SUDO_EDITOR="vim -u NONE"

# ── nvm (lazy-loaded for faster shell startup) ──

export NVM_DIR="$HOME/.nvm"

_nvm_lazy_load() {
  unset -f nvm node npm npx
  [ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"
  [ -s "$NVM_DIR/bash_completion" ] && source "$NVM_DIR/bash_completion"
}

nvm()  { _nvm_lazy_load; nvm "$@" }
node() { _nvm_lazy_load; node "$@" }
npm()  { _nvm_lazy_load; npm "$@" }
npx()  { _nvm_lazy_load; npx "$@" }

# ── macOS-only ──

if [[ "$(uname -s)" == "Darwin" ]]; then
  # bun completions
  [ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

  # Antigravity
  export PATH="$HOME/.antigravity/antigravity/bin:$PATH"
fi

# ── Vi mode for line editing ──

bindkey -v
export KEYTIMEOUT=1

# Cursor shape: beam for insert, block for normal
function zle-keymap-select {
  if [[ $KEYMAP == vicmd ]] || [[ $1 == 'block' ]]; then
    echo -ne '\e[2 q'
  else
    echo -ne '\e[6 q'
  fi
}
zle -N zle-keymap-select

# Start with beam cursor (insert mode)
function zle-line-init { echo -ne '\e[6 q' }
zle -N zle-line-init

# Keep Ctrl+R for reverse history search (vi mode disables it)
bindkey '^R' history-incremental-search-backward

# ── fzf ──

[ -f "$HOME/.fzf.zsh" ] && source "$HOME/.fzf.zsh" || eval "$(fzf --zsh 2>/dev/null)"

# ── direnv ──

command -v direnv &>/dev/null && eval "$(direnv hook zsh)"

# ── Aliases ──

[ -f "$HOME/.aliases" ] && source "$HOME/.aliases"
