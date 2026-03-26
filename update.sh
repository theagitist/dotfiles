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
CERT_WARNINGS=()
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

# Ensure nvm is loaded so npm is on PATH (needed after node upgrades)
if [[ -s "$NVM_DIR/nvm.sh" ]] && ! command -v npm &>/dev/null; then
  source "$NVM_DIR/nvm.sh"
fi

if command -v npm &>/dev/null; then
  echo "\n→ Updating global npm packages..."
  outdated=$(npm outdated -g --json 2>/dev/null)
  if [[ "$outdated" == "{}" || -z "$outdated" ]]; then
    echo "  ✓ All global packages up to date"
    SKIPPED+=("npm global (already up to date)")
  else
    # Use npm directly (not sudo) — nvm-managed npm isn't in sudo's PATH
    if npm update -g; then
      UPDATED+=("npm global packages")
      echo "  ✓ Done"
    else
      ERRORS+=("npm global packages")
      echo "  ✗ Failed (continuing...)"
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
  COMPOSER_HOME="${COMPOSER_HOME:-$(composer global config home 2>/dev/null)}"
  if [[ -f "$COMPOSER_HOME/composer.json" ]]; then
    echo "\n→ Updating Composer global packages..."
    if composer global update --no-interaction 2>/dev/null; then
      UPDATED+=("Composer global packages")
      echo "  ✓ Done"
    else
      ERRORS+=("Composer global update")
      echo "  ✗ Failed (continuing...)"
    fi
  else
    SKIPPED+=("Composer global (no packages installed)")
  fi
else
  SKIPPED+=("Composer (not installed)")
fi

# ── Linux-only: GitHub release binaries ──

if [[ "$OS" != "Darwin" ]]; then
  # lazygit
  if command -v lazygit &>/dev/null; then
    echo "\n→ Checking lazygit updates..."
    current_lg=$(lazygit --version 2>/dev/null | grep -Po '(?<=, )version=\K[^,]+' || echo "0")
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
    current_curlie=$(curlie version 2>/dev/null | grep -Po '[\d.]+' | head -1 || echo "0")
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
    current_himalaya=$(himalaya --version 2>/dev/null | head -1 | awk '{print $2}' | sed 's/^v//' || echo "0")
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

# ── Shared: Certbot SSL renewal ──

if command -v certbot &>/dev/null; then
  if sudo certbot certificates 2>/dev/null | grep -q "Certificate Name"; then
    # Kill any stuck certbot processes before renewing
    if pgrep -f certbot &>/dev/null; then
      echo "\n→ Killing stuck certbot processes..."
      sudo pkill -9 -f certbot 2>/dev/null || true
      sleep 2
    fi

    # Snap-specific: fix broken plugins and restart if needed
    if command -v snap &>/dev/null && snap list certbot &>/dev/null 2>&1; then
      # Check for disabled/broken certbot-dns-* plugins that block snap
      broken_plugins=$(snap list --all 2>/dev/null | grep 'certbot-dns-' | grep 'disabled' | awk '{print $1}' | sort -u)
      if [[ -n "$broken_plugins" ]]; then
        echo "\n→ Fixing broken certbot snap plugins..."
        for plugin in ${(f)broken_plugins}; do
          echo "  → Removing broken $plugin"
          sudo snap remove --purge "$plugin" 2>/dev/null || true
        done
        # Reinstall plugins cleanly
        for plugin in ${(f)broken_plugins}; do
          echo "  → Reinstalling $plugin"
          sudo snap install "$plugin" 2>/dev/null || true
          sudo snap connect certbot:plugin "$plugin" 2>/dev/null || true
        done
      fi
      # Restart snap certbot to clear stale state
      sudo snap restart certbot 2>/dev/null || true
      sleep 1
    fi

    echo "\n→ Renewing SSL certificates..."
    renew_output=$(sudo certbot renew --no-random-sleep-on-renew 2>&1)

    # If "Another instance" persists after cleanup, retry once
    if echo "$renew_output" | grep -q "Another instance of Certbot is already running"; then
      echo "  ⚠ Lock conflict detected, retrying..."
      sudo pkill -9 -f certbot 2>/dev/null || true
      if command -v snap &>/dev/null && snap list certbot &>/dev/null 2>&1; then
        sudo snap stop certbot 2>/dev/null || true
        sudo snap start certbot 2>/dev/null || true
      fi
      sleep 3
      renew_output=$(sudo certbot renew --no-random-sleep-on-renew 2>&1)
    fi

    echo "$renew_output"

    if echo "$renew_output" | grep -q "Another instance of Certbot is already running"; then
      ERRORS+=("SSL certificates (certbot lock — manual intervention needed)")
      echo "  ✗ Certbot locked after retry"
    else
      # Parse failed cert names and attempt force-renewal for each
      failed_certs=()
      while IFS= read -r line; do
        cert_name=$(echo "$line" | sed 's|.*/live/||;s|/.*||')
        [[ -n "$cert_name" ]] && failed_certs+=("$cert_name")
      done < <(echo "$renew_output" | grep '/etc/letsencrypt/live/.*\(failure\)')

      fixed_certs=()
      still_broken=()
      if (( ${#failed_certs[@]} > 0 )); then
        echo "\n→ Retrying ${#failed_certs[@]} failed certificate(s) with --force-renewal..."
        for cert in "${failed_certs[@]}"; do
          # Read the authenticator from the renewal config
          auth=$(grep '^authenticator' "/etc/letsencrypt/renewal/${cert}.conf" 2>/dev/null | awk '{print $3}')
          [[ -z "$auth" ]] && auth="nginx"
          # Read domain(s) from the renewal config
          domains=$(sudo certbot certificates --cert-name "$cert" 2>/dev/null | grep "Domains:" | sed 's/.*Domains: //')
          [[ -z "$domains" ]] && domains="$cert"
          # Build -d flags
          d_flags=""
          for d in ${(z)domains}; do
            d_flags="$d_flags -d $d"
          done

          echo "  → Retrying $cert (authenticator: $auth)..."
          retry_output=$(sudo certbot certonly --"$auth" $d_flags --force-renewal --non-interactive 2>&1)
          if [[ $? -eq 0 ]]; then
            echo "    ✓ Fixed"
            fixed_certs+=("$cert")
          else
            # Extract the reason for the summary
            reason=$(echo "$retry_output" | grep -E '(Detail:|error:)' | head -1 | sed 's/.*Detail: //;s/.*error: //' | cut -c1-60)
            [[ -z "$reason" ]] && reason="unknown error"
            echo "    ✗ Still failing: $reason"
            still_broken+=("$cert")
            CERT_WARNINGS+=("$cert — $reason")
          fi
        done
      fi

      renew_successes=$(echo "$renew_output" | grep -c "(success)" || true)
      total_ok=$(( renew_successes + ${#fixed_certs[@]} ))
      total_fail=${#still_broken[@]}

      if (( total_fail > 0 && total_ok > 0 )); then
        UPDATED+=("SSL certificates ($total_ok ok, $total_fail broken)")
        echo "  ⚠ Partial: $total_ok renewed, $total_fail still failing"
      elif (( total_fail > 0 )); then
        ERRORS+=("SSL certificates ($total_fail broken)")
        echo "  ✗ Failed (continuing...)"
      elif (( total_ok > 0 )); then
        UPDATED+=("SSL certificates ($total_ok renewed)")
        echo "  ✓ Done"
      else
        UPDATED+=("SSL certificates")
        echo "  ✓ All up to date"
      fi
    fi
  else
    SKIPPED+=("SSL certificates (none configured)")
  fi
fi

# ── Linux-only: health checks ──

if [[ "$OS" != "Darwin" ]]; then
  # Syncthing: ensure service is running
  if command -v syncthing &>/dev/null; then
    echo "\n→ Checking syncthing service..."
    if systemctl --user is-active syncthing.service &>/dev/null; then
      echo "  ✓ syncthing service is running"
      SKIPPED+=("syncthing (running)")
    else
      run "Restarting syncthing service" systemctl --user start syncthing.service
    fi
  fi

  # Check for failed systemd services — auto-reset certbot failures
  echo "\n→ Checking systemd services..."
  failed=$(systemctl --failed --no-legend 2>/dev/null)
  if [[ -n "$failed" ]]; then
    # Reset certbot-related failures (transient lock issues)
    for svc in certbot.service snap.certbot.renew.service; do
      if echo "$failed" | grep -q "$svc"; then
        echo "  → Resetting failed $svc"
        sudo systemctl reset-failed "$svc" 2>/dev/null
      fi
    done
    # Re-check after resets
    failed=$(systemctl --failed --no-legend 2>/dev/null)
  fi
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
W=$(( $(tput cols 2>/dev/null || echo 80) - 2 ))  # terminal width minus ║ borders

row() {
  local text="$1"
  # Truncate if too long for the box
  if (( ${#text} > W )); then
    text="${text:0:$((W-1))}…"
  fi
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

# Cert warnings (individual broken certs with reasons)
if (( ${#CERT_WARNINGS[@]} > 0 )); then
  row "  ⚠ Broken certificates:"
  for item in "${CERT_WARNINGS[@]}"; do
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
