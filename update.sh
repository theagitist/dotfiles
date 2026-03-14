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

# ── OS-specific package managers ──

if [[ "$OS" == "Darwin" ]]; then
  if command -v brew &>/dev/null; then
    echo "\n→ Updating Homebrew packages..."
    brew update
    brew upgrade || true
    brew cleanup 2>/dev/null || true
    UPDATED+=("Homebrew packages")
    echo "  ✓ Done"
  fi

  # Mac App Store
  if command -v mas &>/dev/null; then
    echo "\n→ Updating Mac App Store apps..."
    if mas upgrade; then
      UPDATED+=("Mac App Store apps")
    else
      ERRORS+=("Mac App Store updates")
    fi
    echo "  ✓ Done"
  else
    SKIPPED+=("Mac App Store (mas not installed)")
  fi
else
  if command -v apt &>/dev/null; then
    echo "\n→ Updating system packages..."
    sudo apt update && sudo apt upgrade -y
    sudo apt autoremove -y 2>/dev/null || true
    UPDATED+=("System packages (apt)")
    echo "  ✓ Done"
  fi
fi

# ── Shared: Vim plugins (Vundle) ──

run "Updating Vim plugins" vim +PluginUpdate +qall

# ── Shared: npm global packages ──

if command -v npm &>/dev/null; then
  echo "\n→ Updating global npm packages..."
  outdated=$(npm outdated -g --json 2>/dev/null)
  if [[ "$outdated" == "{}" || -z "$outdated" ]]; then
    echo "  ✓ All global packages up to date"
    SKIPPED+=("npm global (already up to date)")
  else
    if [[ "$OS" == "Darwin" ]]; then
      npm update -g || ERRORS+=("Updating global npm packages")
    else
      sudo npm update -g || ERRORS+=("Updating global npm packages")
    fi
    UPDATED+=("npm global packages")
    echo "  ✓ Done"
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
      echo "$outdated_pip" | python3 -c "import sys,json; [print(p['name']) for p in json.load(sys.stdin)]" | xargs -r pip3 install --upgrade --break-system-packages 2>/dev/null || ERRORS+=("Updating pip packages")
      UPDATED+=("pip packages")
      echo "  ✓ Done"
    fi
  else
    # Linux: only user-installed packages (system ones managed by apt)
    pip_names=$(pip3 list --user --outdated --format=freeze 2>&1 | grep -v '^\(WARNING\|NOTICE\|ERROR\)' | cut -d'=' -f1 | tr -d '[:space:]' | grep -v '^$' || true)
    if [[ -z "$pip_names" ]]; then
      echo "  ✓ No outdated user pip packages"
      SKIPPED+=("pip user packages (already up to date)")
    else
      echo "$pip_names" | xargs pip3 install --user --upgrade 2>/dev/null || ERRORS+=("Updating pip packages")
      UPDATED+=("pip user packages")
      echo "  ✓ Done"
    fi
  fi
fi

# ── Shared: Composer global packages ──

if command -v composer &>/dev/null; then
  echo "\n→ Updating Composer global packages..."
  if composer global update --no-interaction 2>/dev/null; then
    UPDATED+=("Composer global packages")
  else
    ERRORS+=("Composer global update")
  fi
  echo "  ✓ Done"
else
  SKIPPED+=("Composer (not installed)")
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
      git add -A
      git commit -m "sync $(hostname) $(date +%Y-%m-%d)"
      git push
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

if (( ${#ERRORS[@]} > 0 )); then
  exit 1
fi
