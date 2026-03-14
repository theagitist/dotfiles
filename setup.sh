#!/usr/bin/env zsh
set -uo pipefail

# ──────────────────────────────────────────────
# Dotfiles Bootstrap Script
# Installs dependencies required by .zshrc,
# .aliases, .tmux.conf, and update.sh
# Safe to run multiple times (idempotent)
# ──────────────────────────────────────────────

OS="$(uname -s)"
MISSING=()
INSTALLED=()
SKIPPED=()

info()  { echo "  → $1" }
ok()    { echo "  ✓ $1"; INSTALLED+=("$1") }
skip()  { echo "  · $1 (already installed)"; SKIPPED+=("$1") }
fail()  { echo "  ✗ $1"; MISSING+=("$1") }

install_package() {
  local name="$1"
  local brew_name="${2:-$1}"
  local apt_name="${3:-$1}"

  if command -v "$name" &>/dev/null; then
    skip "$name"
    return
  fi

  info "Installing $name..."
  if [[ "$OS" == "Darwin" ]]; then
    brew install "$brew_name" && ok "$name" || fail "$name"
  else
    sudo apt-get install -y "$apt_name" && ok "$name" || fail "$name"
  fi
}

echo "=== Dotfiles Setup ($(hostname) / ${OS}) ==="
echo ""

# ── Package manager check ──

if [[ "$OS" == "Darwin" ]]; then
  if ! command -v brew &>/dev/null; then
    echo "Homebrew not found. Install it first:"
    echo '  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
    exit 1
  fi
  brew update
else
  sudo apt-get update
fi

# ── Oh My Zsh ──

echo "\n── Oh My Zsh ──"
if [[ -d "$HOME/.oh-my-zsh" ]]; then
  skip "oh-my-zsh"
else
  info "Installing oh-my-zsh..."
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended && ok "oh-my-zsh" || fail "oh-my-zsh"
fi

# ── Oh My Zsh custom plugins ──

echo "\n── Oh My Zsh Plugins ──"
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

if [[ -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]]; then
  skip "zsh-syntax-highlighting"
else
  info "Installing zsh-syntax-highlighting..."
  git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" && ok "zsh-syntax-highlighting" || fail "zsh-syntax-highlighting"
fi

if [[ -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]]; then
  skip "zsh-autosuggestions"
else
  info "Installing zsh-autosuggestions..."
  git clone https://github.com/zsh-users/zsh-autosuggestions.git "$ZSH_CUSTOM/plugins/zsh-autosuggestions" && ok "zsh-autosuggestions" || fail "zsh-autosuggestions"
fi

# ── Oh My Zsh Dracula theme ──

echo "\n── Dracula Theme ──"
if [[ -d "$ZSH_CUSTOM/themes/dracula" ]]; then
  skip "dracula theme"
else
  info "Installing Dracula theme..."
  git clone https://github.com/dracula/zsh.git "$ZSH_CUSTOM/themes/dracula" && \
    ln -s "$ZSH_CUSTOM/themes/dracula/dracula.zsh-theme" "$ZSH_CUSTOM/themes/dracula.zsh-theme" && \
    ok "dracula theme" || fail "dracula theme"
fi

# ── CLI tools ──

echo "\n── CLI Tools ──"
install_package "eza" "eza" "eza"
install_package "zoxide" "zoxide" "zoxide"
install_package "gh" "gh" "gh"

# bat: different package names per OS
if command -v bat &>/dev/null || command -v batcat &>/dev/null; then
  skip "bat"
else
  info "Installing bat..."
  if [[ "$OS" == "Darwin" ]]; then
    brew install bat && ok "bat" || fail "bat"
  else
    sudo apt-get install -y bat && ok "bat" || fail "bat"
  fi
fi

# nvm + node
echo "\n── Node (via nvm) ──"
export NVM_DIR="$HOME/.nvm"
if [[ -d "$NVM_DIR" ]]; then
  skip "nvm"
else
  info "Installing nvm..."
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash && ok "nvm" || fail "nvm"
fi
# Load nvm for the rest of this script
[ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"
if command -v nvm &>/dev/null; then
  if command -v node &>/dev/null; then
    skip "node ($(node -v))"
  else
    info "Installing latest Node.js via nvm..."
    nvm install node && nvm alias default node && ok "node ($(node -v))" || fail "node"
  fi
fi

# bun
echo "\n── Bun ──"
if command -v bun &>/dev/null; then
  skip "bun"
else
  info "Installing bun..."
  curl -fsSL https://bun.sh/install | bash && ok "bun" || fail "bun"
fi

install_package "vim" "vim" "vim-gtk3"

# Vundle + vim plugins
echo "\n── Vim ──"
if [[ -d "$HOME/.vim/bundle/Vundle.vim" ]]; then
  skip "vundle"
else
  info "Installing Vundle..."
  git clone https://github.com/VundleVim/Vundle.vim.git "$HOME/.vim/bundle/Vundle.vim" && ok "vundle" || fail "vundle"
fi
if [[ -d "$HOME/.vim/bundle/Vundle.vim" ]]; then
  info "Installing vim plugins..."
  vim +PluginInstall +qall 2>/dev/null && ok "vim plugins" || fail "vim plugins"
  # coc.nvim requires a build step
  if [[ -d "$HOME/.vim/bundle/coc.nvim" && ! -f "$HOME/.vim/bundle/coc.nvim/build/index.js" ]]; then
    info "Building coc.nvim..."
    (cd "$HOME/.vim/bundle/coc.nvim" && npm ci 2>/dev/null) && ok "coc.nvim build" || fail "coc.nvim build"
  fi
fi
install_package "curl" "curl" "curl"
install_package "dig" "bind" "dnsutils"
install_package "zip" "zip" "zip"
install_package "git-extras" "git-extras" "git-extras"
install_package "aws" "awscli" "awscli"

# ── tmux + TPM ──

echo "\n── tmux ──"
install_package "tmux" "tmux" "tmux"

if [[ -d "$HOME/.tmux/plugins/tpm" ]]; then
  skip "tpm"
else
  info "Installing TPM..."
  git clone https://github.com/tmux-plugins/tpm.git "$HOME/.tmux/plugins/tpm" && ok "tpm" || fail "tpm"
fi

# ── Linux-only ──

if [[ "$OS" != "Darwin" ]]; then
  install_package "nginx" "nginx" "nginx"
  install_package "vlock" "vlock" "vlock"
  install_package "certbot" "certbot" "certbot"
  if ! dpkg -l python3-certbot-nginx &>/dev/null; then
    info "Installing certbot nginx plugin..."
    sudo apt-get install -y python3-certbot-nginx && ok "certbot-nginx" || fail "certbot-nginx"
  else
    skip "certbot-nginx"
  fi
fi

# ── Summary ──

echo "\n"
echo "════════════════════════════════════════"
if (( ${#INSTALLED[@]} > 0 )); then
  echo "  ✓ Installed (${#INSTALLED[@]}):"
  for item in "${INSTALLED[@]}"; do echo "      • $item"; done
fi
if (( ${#SKIPPED[@]} > 0 )); then
  echo "  · Already installed (${#SKIPPED[@]}):"
  for item in "${SKIPPED[@]}"; do echo "      • $item"; done
fi
if (( ${#MISSING[@]} > 0 )); then
  echo "  ✗ Failed (${#MISSING[@]}):"
  for item in "${MISSING[@]}"; do echo "      • $item"; done
fi
echo "════════════════════════════════════════"

if (( ${#MISSING[@]} > 0 )); then
  echo "\nSome dependencies failed to install. Check the errors above."
  exit 1
else
  echo "\nAll dependencies satisfied. Restart your shell or run: source ~/.zshrc"
fi
