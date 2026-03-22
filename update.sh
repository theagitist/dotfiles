#!/usr/bin/env zsh
set -uo pipefail

# ──────────────────────────────────────────────
# Cross-platform System Update Script
# Detects macOS / Linux and runs accordingly
# ──────────────────────────────────────────────

OS="$(uname -s)"
HOST="$(hostname -s 2>/dev/null || hostname)"
ERRORS=()
UPDATED=()
SKIPPED=()
START_TIME=$SECONDS

# ── Logging (keep last 30 days) ──

LOG_DIR="$HOME/.local/log"
[[ -d "$LOG_DIR" ]] || mkdir -p "$LOG_DIR"
LOG="$LOG_DIR/update-$(date +%Y%m%d-%H%M).log"
find "$LOG_DIR" -name "update-*.log" -mtime +30 -delete 2>/dev/null
exec > >(tee -a "$LOG") 2>&1

run() {
  local label="$1"
  shift
  echo "\n→ $label..."
  if "$@"; then
    UPDATED+=("$label")
    echo "  ✓ Done"
  else
    ERRORS+=("$label")
    echo "  ✗ Failed (continuing...)"
  fi
}

echo "=== System Update (${HOST} / ${OS}): $(date '+%Y-%m-%d %H:%M') ==="

# ── Oh My Zsh (shared) ──

if [[ -n "${ZSH:-}" && -f "$ZSH/tools/upgrade.sh" ]]; then
  run "Updating Oh My Zsh" "$ZSH/tools/upgrade.sh"
elif [[ -f "$HOME/.oh-my-zsh/tools/upgrade.sh" ]]; then
  run "Updating Oh My Zsh" "$HOME/.oh-my-zsh/tools/upgrade.sh"
fi

# ── Oh My Zsh custom plugins (git repos) ──

ZSH_CUSTOM="${ZSH_CUSTOM:-${ZSH:-$HOME/.oh-my-zsh}/custom}"
echo "\n→ Updating oh-my-zsh custom plugins..."
omz_updated=0
for plugin_dir in "$ZSH_CUSTOM"/plugins/*(N/); do
  if [[ -d "$plugin_dir/.git" ]]; then
    plugin_name="${plugin_dir:t}"
    echo "  → $plugin_name"
    if git -C "$plugin_dir" pull --rebase --quiet 2>/dev/null; then
      omz_updated=$((omz_updated + 1))
    else
      ERRORS+=("omz plugin: $plugin_name")
      echo "    ✗ Failed"
    fi
  fi
done
if (( omz_updated > 0 )); then
  UPDATED+=("oh-my-zsh custom plugins ($omz_updated)")
  echo "  ✓ Updated $omz_updated plugins"
else
  echo "  ✓ All plugins up to date"
fi

# ── OS-specific package managers ──

if [[ "$OS" == "Darwin" ]]; then
  if command -v brew &>/dev/null; then
    echo "\n→ Updating Homebrew packages..."
    if brew update && brew upgrade; then
      brew cleanup 2>/dev/null || true
      UPDATED+=("Homebrew packages")
      echo "  ✓ Done"
    else
      ERRORS+=("Homebrew packages")
      echo "  ✗ Failed (continuing...)"
    fi
  fi

  # Mac App Store
  if command -v mas &>/dev/null; then
    echo "\n→ Updating Mac App Store apps..."
    if mas upgrade; then
      UPDATED+=("Mac App Store apps")
      echo "  ✓ Done"
    else
      ERRORS+=("Mac App Store updates")
      echo "  ✗ Failed (continuing...)"
    fi
  else
    SKIPPED+=("Mac App Store (mas not installed)")
  fi
else
  if command -v apt-get &>/dev/null; then
    echo "\n→ Updating system packages..."
    if sudo apt-get update && sudo apt-get upgrade -y; then
      sudo apt-get autoremove -y 2>/dev/null || true
      UPDATED+=("System packages (apt)")
      echo "  ✓ Done"
    else
      ERRORS+=("System packages (apt)")
      echo "  ✗ Failed (continuing...)"
    fi
  fi
fi

# ── Shared: Vim plugins (vim-plug) ──

run "Updating Vim plugins" vim +PlugUpdate +qall

# ── Shared: tmux plugins (TPM) ──

if [[ -x "$HOME/.tmux/plugins/tpm/bin/update_plugins" ]]; then
  run "Updating tmux plugins" "$HOME/.tmux/plugins/tpm/bin/update_plugins" all
fi

# ── Shared: bun ──

if command -v bun &>/dev/null; then
  run "Updating bun" bun upgrade
fi

# ── Shared: nvm + node ──

if [[ -s "$NVM_DIR/nvm.sh" ]]; then
  source "$NVM_DIR/nvm.sh"
  echo "\n→ Checking for Node.js updates..."
  current=$(nvm current)
  latest=$(nvm version-remote node 2>/dev/null)
  if [[ "$current" != "$latest" && -n "$latest" ]]; then
    run "Updating Node.js ($current → $latest)" nvm install node --reinstall-packages-from=current
    nvm alias default node
  else
    echo "  ✓ Node.js $current is latest"
    SKIPPED+=("Node.js (already up to date)")
  fi
fi

# ── Shared: npm global packages ──

if command -v npm &>/dev/null; then
  echo "\n→ Updating global npm packages..."
  outdated=$(npm outdated -g --json 2>/dev/null)
  if [[ "$outdated" == "{}" || -z "$outdated" ]]; then
    echo "  ✓ All global packages up to date"
    SKIPPED+=("npm global (already up to date)")
  else
    if [[ "$OS" == "Darwin" ]]; then
      if npm update -g; then
        UPDATED+=("npm global packages")
        echo "  ✓ Done"
      else
        ERRORS+=("npm global packages")
        echo "  ✗ Failed (continuing...)"
      fi
    else
      if sudo npm update -g; then
        UPDATED+=("npm global packages")
        echo "  ✓ Done"
      else
        ERRORS+=("npm global packages")
        echo "  ✗ Failed (continuing...)"
      fi
    fi
  fi
fi

# ── Shared: pip packages ──

if command -v pip3 &>/dev/null; then
  echo "\n→ Updating pip packages..."
  if [[ "$OS" == "Darwin" ]]; then
    outdated_pip=$(pip3 list --outdated --format=json 2>/dev/null)
    if [[ "$outdated_pip" == "[]" || -z "$outdated_pip" ]]; then
      echo "  ✓ All pip packages up to date"
      SKIPPED+=("pip (already up to date)")
    else
      if echo "$outdated_pip" | python3 -c "import sys,json; [print(p['name']) for p in json.load(sys.stdin)]" | xargs pip3 install --user --upgrade 2>/dev/null; then
        UPDATED+=("pip packages")
        echo "  ✓ Done"
      else
        ERRORS+=("pip packages")
        echo "  ✗ Failed (continuing...)"
      fi
    fi
  else
    # Linux: only user-installed packages (system ones managed by apt)
    pip_names=$(pip3 list --user --outdated --format=freeze 2>&1 | grep -v '^\(WARNING\|NOTICE\|ERROR\)' | cut -d'=' -f1 | tr -d '[:space:]' | grep -v '^$' || true)
    if [[ -z "$pip_names" ]]; then
      echo "  ✓ No outdated user pip packages"
      SKIPPED+=("pip user packages (already up to date)")
    else
      if echo "$pip_names" | xargs pip3 install --user --upgrade 2>/dev/null; then
        UPDATED+=("pip user packages")
        echo "  ✓ Done"
      else
        ERRORS+=("pip user packages")
        echo "  ✗ Failed (continuing...)"
      fi
    fi
  fi
fi

# ── Shared: Composer global packages ──

if command -v composer &>/dev/null; then
  echo "\n→ Updating Composer global packages..."
  if composer global update --no-interaction 2>/dev/null; then
    UPDATED+=("Composer global packages")
    echo "  ✓ Done"
  else
    ERRORS+=("Composer global update")
    echo "  ✗ Failed (continuing...)"
  fi
else
  SKIPPED+=("Composer (not installed)")
fi

# ── Linux-only: GitHub release binaries ──

if [[ "$OS" != "Darwin" ]]; then
  # lazygit
  if command -v lazygit &>/dev/null; then
    echo "\n→ Checking lazygit updates..."
    current_lg=$(lazygit --version 2>/dev/null | grep -Po 'version=\K[^,]+' || echo "0")
    latest_lg=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
    if [[ -n "$latest_lg" && "$current_lg" != "$latest_lg" ]]; then
      run "Updating lazygit ($current_lg → $latest_lg)" bash -c "
        curl -Lo /tmp/lazygit.tar.gz \"https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_\${1}_Linux_x86_64.tar.gz\" && \
        tar xf /tmp/lazygit.tar.gz -C /tmp lazygit && \
        sudo install /tmp/lazygit /usr/local/bin && \
        rm -f /tmp/lazygit /tmp/lazygit.tar.gz
      " -- "$latest_lg"
    else
      echo "  ✓ lazygit $current_lg is latest"
      SKIPPED+=("lazygit (already up to date)")
    fi
  fi

  # delta
  if command -v delta &>/dev/null; then
    echo "\n→ Checking delta updates..."
    current_delta=$(delta --version 2>/dev/null | awk '{print $2}')
    latest_delta=$(curl -s "https://api.github.com/repos/dandavison/delta/releases/latest" | grep -Po '"tag_name": "\K[^"]*')
    if [[ -n "$latest_delta" && "$current_delta" != "$latest_delta" ]]; then
      run "Updating delta ($current_delta → $latest_delta)" bash -c "
        curl -Lo /tmp/delta.deb \"https://github.com/dandavison/delta/releases/latest/download/git-delta_\${1}_amd64.deb\" && \
        sudo dpkg -i /tmp/delta.deb && \
        rm -f /tmp/delta.deb
      " -- "$latest_delta"
    else
      echo "  ✓ delta $current_delta is latest"
      SKIPPED+=("delta (already up to date)")
    fi
  fi

  # curlie
  if command -v curlie &>/dev/null; then
    echo "\n→ Checking curlie updates..."
    current_curlie=$(curlie --version 2>/dev/null | grep -Po '[\d.]+' | head -1 || echo "0")
    latest_curlie=$(curl -s "https://api.github.com/repos/rs/curlie/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
    if [[ -n "$latest_curlie" && "$current_curlie" != "$latest_curlie" ]]; then
      run "Updating curlie ($current_curlie → $latest_curlie)" bash -c "
        curl -Lo /tmp/curlie.tar.gz \"https://github.com/rs/curlie/releases/latest/download/curlie_\${1}_linux_amd64.tar.gz\" && \
        tar xf /tmp/curlie.tar.gz -C /tmp curlie && \
        sudo install /tmp/curlie /usr/local/bin && \
        rm -f /tmp/curlie /tmp/curlie.tar.gz
      " -- "$latest_curlie"
    else
      echo "  ✓ curlie $current_curlie is latest"
      SKIPPED+=("curlie (already up to date)")
    fi
  fi

  # himalaya (cargo install updates if newer version available)
  if command -v himalaya &>/dev/null && command -v cargo &>/dev/null; then
    echo "\n→ Checking himalaya updates..."
    current_himalaya=$(himalaya --version 2>/dev/null | awk '{print $2}' || echo "0")
    latest_himalaya=$(gh api repos/pimalaya/himalaya/releases/latest --jq '.tag_name' 2>/dev/null | sed 's/^v//')
    if [[ -n "$latest_himalaya" && "$current_himalaya" != "$latest_himalaya" ]]; then
      run "Updating himalaya ($current_himalaya → $latest_himalaya)" cargo install himalaya --features oauth2 --locked
    else
      echo "  ✓ himalaya $current_himalaya is latest"
      SKIPPED+=("himalaya (already up to date)")
    fi
  fi

  # fzf (if installed from GitHub, not apt)
  if command -v fzf &>/dev/null && [[ -d "$HOME/.fzf" ]]; then
    run "Updating fzf" bash -c "cd $HOME/.fzf && git pull && ./install --key-bindings --completion --no-update-rc"
  fi
fi

# ── macOS-only: software updates ──

if [[ "$OS" == "Darwin" ]]; then
  run "Checking macOS software updates" softwareupdate -l
fi

# ── Linux-only: Certbot & health checks ──

if [[ "$OS" != "Darwin" ]]; then
  if command -v certbot &>/dev/null; then
    run "Renewing SSL certificates" sudo certbot renew
  fi

  # Check for failed systemd services
  echo "\n→ Checking systemd services..."
  failed=$(systemctl --failed --no-legend 2>/dev/null)
  if [[ -z "$failed" ]]; then
    echo "  ✓ All services healthy"
  else
    echo "  ⚠ Failed services:"
    echo "$failed" | sed 's/^/    /'
    ERRORS+=("Failed systemd services")
  fi
fi

# ── Shared: Claude Code config sync ──

echo "\n→ Syncing Claude Code config..."
if [[ -d ~/.claude/.git ]]; then
  (
    cd ~/.claude
    git pull --rebase
    if [[ -n "$(git status --porcelain)" ]]; then
      git diff --name-only --cached
      git diff --name-only
      echo "  ⚠ Uncommitted changes in ~/.claude — review before committing"
    fi
    echo "  ✓ Done"
  ) || { ERRORS+=("Claude Code sync"); echo "  ✗ Failed (continuing...)" }
else
  echo "  Skipped — no git repo at ~/.claude"
fi

# ── Shared: Git housekeeping ──

echo "\n→ Cleaning up stale git branches..."
stale_count=0
for repo in ~/projects/*(N/) ~/work/*(N/) ; do
  if [[ -d "$repo/.git" ]]; then
    # Use pushd/popd instead of subshell so stale_count persists
    pushd "$repo" &>/dev/null || continue
    git fetch --prune 2>/dev/null
    main_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
    [[ -z "$main_branch" ]] && main_branch="main"
    merged=$(git branch --merged "$main_branch" 2>/dev/null | grep -v "^\*" | grep -v "$main_branch" | grep -v "master")
    if [[ -n "$merged" ]]; then
      echo "$merged" | xargs git branch -d 2>/dev/null
      stale_count=$((stale_count + $(echo "$merged" | wc -l | tr -d ' ')))
    fi
    popd &>/dev/null
  fi
done
if (( stale_count > 0 )); then
  echo "  ✓ Cleaned $stale_count merged branches"
else
  echo "  ✓ No stale branches found"
fi

# ── Summary ──

ELAPSED=$(( SECONDS - START_TIME ))
MINS=$(( ELAPSED / 60 ))
SECS=$(( ELAPSED % 60 ))
W=48  # inner width between ║ chars

row() {
  local text="$1"
  local pad=$(( W - ${#text} ))
  (( pad < 0 )) && pad=0
  printf "║%s%*s║\n" "$text" "$pad" ""
}

divider() {
  printf "╠"
  printf '─%.0s' {1..$W}
  printf "╣\n"
}

echo "\n"
printf "╔"
printf '═%.0s' {1..$W}
printf "╗\n"
row "         UPDATE COMPLETE — ${HOST}"
divider
row "  Date:     $(date '+%Y-%m-%d %H:%M')"
row "  OS:       ${OS} ($(uname -r | cut -d- -f1))"
row "  Uptime:   $(uptime | sed 's/.*up //' | sed 's/,.*load.*//' | sed 's/^ *//')"
row "  Duration: ${MINS}m ${SECS}s"
divider

# Disk
disk_text=$(df -h / | tail -1 | awk '{printf "%s used of %s (%s free, %s)", $3, $2, $4, $5}')
row "  Disk:     $disk_text"

# Memory
if [[ "$OS" == "Darwin" ]]; then
  mem_used=$(vm_stat 2>/dev/null | awk '/Pages active/ {printf "%.0f", $3*4096/1073741824}')
  mem_total=$(sysctl -n hw.memsize 2>/dev/null | awk '{printf "%.0f", $1/1073741824}')
  [[ -n "$mem_used" && -n "$mem_total" ]] && row "  Memory:   ${mem_used}G used of ${mem_total}G"
else
  mem_text=$(free -h 2>/dev/null | awk '/Mem:/ {printf "%s used of %s (%s free)", $3, $2, $4}')
  [[ -n "$mem_text" ]] && row "  Memory:   $mem_text"
fi

divider

# What got updated
if (( ${#UPDATED[@]} > 0 )); then
  row "  ✓ Updated (${#UPDATED[@]}):"
  for item in "${UPDATED[@]}"; do
    row "      • $item"
  done
fi

# What was skipped
if (( ${#SKIPPED[@]} > 0 )); then
  row "  ⏭ Skipped (${#SKIPPED[@]}):"
  for item in "${SKIPPED[@]}"; do
    row "      • $item"
  done
fi

# Failures
if (( ${#ERRORS[@]} > 0 )); then
  row "  ✗ Failed (${#ERRORS[@]}):"
  for item in "${ERRORS[@]}"; do
    row "      • $item"
  done
fi

divider

# Warnings
warnings=0
if [[ "$OS" != "Darwin" && -f /var/run/reboot-required ]]; then
  row "  ⚠ Reboot required (kernel update pending)"
  warnings=1
fi

disk_pct=$(df / | tail -1 | awk '{gsub(/%/,"",$5); print $5}')
if (( disk_pct > 85 )); then
  row "  ⚠ Disk usage above 85% — consider cleanup"
  warnings=1
fi

if (( warnings == 0 && ${#ERRORS[@]} == 0 )); then
  row "  ✓ All clear — no warnings"
fi

printf "╚"
printf '═%.0s' {1..$W}
printf "╝\n"

echo "\nLog saved to: $LOG"

if (( ${#ERRORS[@]} > 0 )); then
  exit 1
fi
