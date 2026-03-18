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
install_package "ncdu" "ncdu" "ncdu"
install_package "htop" "htop" "htop"
install_package "bpytop" "bpytop" "bpytop"
install_package "tldr" "tldr" "tldr"
install_package "rg" "ripgrep" "ripgrep"
install_package "jq" "jq" "jq"
install_package "w3m" "w3m" "w3m"
install_package "duf" "duf" "duf"
install_package "entr" "entr" "entr"

# direnv
install_package "direnv" "direnv" "direnv"
install_package "yq" "yq" "yq"
install_package "glow" "glow" "glow"

# curlie
if command -v curlie &>/dev/null; then
  skip "curlie"
else
  info "Installing curlie..."
  if [[ "$OS" == "Darwin" ]]; then
    brew install curlie && ok "curlie" || fail "curlie"
  else
    CURLIE_VERSION=$(curl -s "https://api.github.com/repos/rs/curlie/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
    curl -Lo /tmp/curlie.tar.gz "https://github.com/rs/curlie/releases/latest/download/curlie_${CURLIE_VERSION}_linux_amd64.tar.gz" && \
      tar xf /tmp/curlie.tar.gz -C /tmp curlie && \
      sudo install /tmp/curlie /usr/local/bin && \
      rm -f /tmp/curlie /tmp/curlie.tar.gz && \
      ok "curlie" || fail "curlie"
  fi
fi

# fzf
echo "\n── fzf ──"
if command -v fzf &>/dev/null; then
  skip "fzf"
else
  info "Installing fzf..."
  if [[ "$OS" == "Darwin" ]]; then
    brew install fzf && ok "fzf" || fail "fzf"
  else
    sudo apt-get install -y fzf && ok "fzf" || fail "fzf"
  fi
fi

# delta (git pager)
if command -v delta &>/dev/null; then
  skip "delta"
else
  info "Installing delta..."
  if [[ "$OS" == "Darwin" ]]; then
    brew install git-delta && ok "delta" || fail "delta"
  else
    DELTA_VERSION=$(curl -s "https://api.github.com/repos/dandavison/delta/releases/latest" | grep -Po '"tag_name": "\K[^"]*')
    curl -Lo /tmp/delta.deb "https://github.com/dandavison/delta/releases/latest/download/git-delta_${DELTA_VERSION}_amd64.deb" && \
      sudo dpkg -i /tmp/delta.deb && \
      rm -f /tmp/delta.deb && \
      ok "delta" || fail "delta"
  fi
fi

# fd: brew uses "fd", Ubuntu uses "fd-find" with binary "fdfind"
if command -v fd &>/dev/null || command -v fdfind &>/dev/null; then
  skip "fd"
else
  info "Installing fd..."
  if [[ "$OS" == "Darwin" ]]; then
    brew install fd && ok "fd" || fail "fd"
  else
    sudo apt-get install -y fd-find && ok "fd" || fail "fd"
  fi
fi

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

# vim-plug + vim plugins
echo "\n── Vim ──"
PLUG_FILE="$HOME/.vim/autoload/plug.vim"
if [[ -f "$PLUG_FILE" ]]; then
  skip "vim-plug"
else
  info "Installing vim-plug..."
  curl -fLo "$PLUG_FILE" --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim && ok "vim-plug" || fail "vim-plug"
fi
if [[ -f "$PLUG_FILE" ]]; then
  info "Installing vim plugins..."
  vim +PlugInstall +qall 2>/dev/null && ok "vim plugins" || fail "vim plugins"
fi
install_package "curl" "curl" "curl"
install_package "dig" "bind" "dnsutils"
install_package "zip" "zip" "zip"
install_package "git-extras" "git-extras" "git-extras"
# lazygit: brew on macOS, binary release on Linux
if command -v lazygit &>/dev/null; then
  skip "lazygit"
else
  info "Installing lazygit..."
  if [[ "$OS" == "Darwin" ]]; then
    brew install lazygit && ok "lazygit" || fail "lazygit"
  else
    LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
    curl -Lo /tmp/lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz" && \
      tar xf /tmp/lazygit.tar.gz -C /tmp lazygit && \
      sudo install /tmp/lazygit /usr/local/bin && \
      rm -f /tmp/lazygit /tmp/lazygit.tar.gz && \
      ok "lazygit" || fail "lazygit"
  fi
fi
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

# ── Timezone ──

echo "\n── Timezone ──"
DESIRED_TZ="America/Vancouver"
CURRENT_TZ=$(cat /etc/timezone 2>/dev/null || readlink /etc/localtime 2>/dev/null | sed 's|.*/zoneinfo/||')
if [[ "$CURRENT_TZ" == "$DESIRED_TZ" ]]; then
  skip "timezone ($DESIRED_TZ)"
else
  info "Setting timezone to $DESIRED_TZ..."
  if [[ "$OS" == "Darwin" ]]; then
    sudo systemsetup -settimezone "$DESIRED_TZ" 2>/dev/null && ok "timezone" || fail "timezone"
  else
    sudo timedatectl set-timezone "$DESIRED_TZ" && ok "timezone" || fail "timezone"
  fi
fi

# ── Cron: weekly update ──

echo "\n── Cron ──"
if crontab -l 2>/dev/null | grep -q "update.sh"; then
  skip "weekly update cron"
else
  info "Adding weekly update cron (Saturday midnight)..."
  (crontab -l 2>/dev/null; echo "0 0 * * 6 $HOME/update.sh >> $HOME/.local/log/update-cron.log 2>&1") | crontab - && ok "weekly update cron" || fail "weekly update cron"
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
