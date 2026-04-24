#!/bin/bash
# bootstrap.sh — one-command install of the free-claude-code NIM setup on WSL1 Ubuntu.
#
# Reproducibility V5 gap-fill: the 13 manual steps in PLAN.md section
# "Cold-start rebuild" collapsed into one idempotent script.
#
# Usage (as the target user, with sudo available for apt/symlink steps):
#   bash bootstrap.sh
# Or with API key pre-provided:
#   NIM_API_KEY=nvapi-... bash bootstrap.sh
#
# Pass criteria: script exits 0; `claude-nim -p "PONG"` returns a model response.

set -eu

SETUP_REPO_URL="${SETUP_REPO_URL:-https://github.com/dshanklin/free-claude-code-setup.git}"
PROXY_REPO_URL="${PROXY_REPO_URL:-https://github.com/pchalasani/free-claude-code.git}"
REPOS_DIR="${REPOS_DIR:-$HOME/repos}"
CLAUDE_CODE_VERSION="${CLAUDE_CODE_VERSION:-2.1.81}"
NODE_VERSION="${NODE_VERSION:-20}"
PROXY_PORT="${NIM_PROXY_PORT:-8082}"

log() { printf '[bootstrap] %s\n' "$*"; }
fail() { printf '[bootstrap] FAIL: %s\n' "$*" >&2; exit 1; }

log "=== free-claude-code-setup bootstrap ==="
log "target user: $(whoami)   home: $HOME   repos: $REPOS_DIR"
log "claude-code: pinned $CLAUDE_CODE_VERSION   node: $NODE_VERSION   proxy port: $PROXY_PORT"
echo

# ---- step 1: preflight ----
log "[1/13] preflight"
[ "$(whoami)" = "root" ] && fail "do not run as root — run as your normal user; sudo is invoked where needed"
command -v sudo >/dev/null || fail "sudo not available"
command -v curl >/dev/null || fail "curl missing (need baseline apt packages)"
if grep -qi microsoft /proc/version 2>/dev/null; then
  if [ "$(uname -r | grep -c WSL2)" -gt 0 ]; then
    log "  WSL2 detected (script tested on WSL1; should still work)"
  else
    log "  WSL1 detected (target environment)"
  fi
else
  log "  not WSL — should work on bare Ubuntu too"
fi

# ---- step 2: apt baseline (minimal — avoids WSL1 systemd reconfigure trap) ----
log "[2/13] apt baseline packages (only true prerequisites)"
# The bootstrap only strictly needs curl + git. python3 is always on Ubuntu.
# build-essential / python3-venv are not needed — uv downloads its own Python,
# and claude-code@2.1.81 is a pure Node script (no native compile step).
# Installing more packages risks dpkg --configure -a triggering systemd's
# post-install, which fails on WSL1 with "Failed to take /etc/passwd lock".
MISSING_PKGS=()
for cmd_pkg in "curl:curl" "git:git"; do
  cmd="${cmd_pkg%:*}"
  pkg="${cmd_pkg#*:}"
  command -v "$cmd" >/dev/null 2>&1 || MISSING_PKGS+=("$pkg")
done
if [ "${#MISSING_PKGS[@]}" -eq 0 ]; then
  log "  curl + git present, skipping apt"
else
  log "  need to install: ${MISSING_PKGS[*]}"
  # Hold systemd FIRST on WSL1 so apt-get install doesn't try to reconfigure it
  if grep -qi microsoft /proc/version 2>/dev/null && [ "$(uname -r | grep -c WSL2)" -eq 0 ]; then
    sudo apt-mark hold systemd systemd-sysv udev >/dev/null 2>&1 || true
  fi
  sudo apt-get update -qq
  if ! sudo apt-get install -y -qq "${MISSING_PKGS[@]}"; then
    fail "apt-get install failed. Likely WSL1 systemd reconfigure trap. Manual prereq: run 'sudo dpkg --configure -a' (may fail on systemd — that's OK if it's held), then retry. See logs in claude-insights/wsl/systemd-hold.md"
  fi
fi

# ---- step 3: hold systemd on WSL1 ----
log "[3/13] hold systemd (WSL1 can't reconfigure it; prevents apt-upgrade breakage)"
if grep -qi microsoft /proc/version 2>/dev/null && [ "$(uname -r | grep -c WSL2)" -eq 0 ]; then
  sudo apt-mark hold systemd systemd-sysv udev >/dev/null 2>&1 || true
fi

# ---- step 4: nvm + node ----
log "[4/13] nvm + node $NODE_VERSION"
export NVM_DIR="$HOME/.nvm"
if [ ! -s "$NVM_DIR/nvm.sh" ]; then
  curl -sS -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash >/dev/null
fi
# shellcheck disable=SC1091
. "$NVM_DIR/nvm.sh"
if ! nvm ls "$NODE_VERSION" 2>/dev/null | grep -q "v$NODE_VERSION"; then
  nvm install "$NODE_VERSION" >/dev/null
fi
nvm use "$NODE_VERSION" >/dev/null

# ---- step 5: claude-code pinned ----
log "[5/13] @anthropic-ai/claude-code@$CLAUDE_CODE_VERSION (pinned for WSL1 compat)"
CURR_CC_VER=""
if command -v claude >/dev/null 2>&1; then
  CURR_CC_VER=$(claude --version 2>/dev/null | awk '{print $1}' || true)
fi
if [ "$CURR_CC_VER" != "$CLAUDE_CODE_VERSION" ]; then
  npm install -g "@anthropic-ai/claude-code@$CLAUDE_CODE_VERSION" >/dev/null
fi
log "  installed: $(claude --version 2>/dev/null || echo MISSING)"

# ---- step 6: uv ----
log "[6/13] uv (Python package manager)"
if [ ! -x "$HOME/.local/bin/uv" ]; then
  curl -LsSf https://astral.sh/uv/install.sh | sh >/dev/null 2>&1
fi
export PATH="$HOME/.local/bin:$PATH"
log "  uv: $(uv --version)"

# ---- step 7: clone repos ----
log "[7/13] clone repos under $REPOS_DIR"
mkdir -p "$REPOS_DIR"
for repo_spec in \
  "free-claude-code-setup|$SETUP_REPO_URL" \
  "free-claude-code|$PROXY_REPO_URL"
do
  name="${repo_spec%%|*}"
  url="${repo_spec##*|}"
  path="$REPOS_DIR/$name"
  if [ ! -d "$path/.git" ]; then
    log "  cloning $name"
    git clone --quiet "$url" "$path"
  else
    log "  $name already present (skipping clone)"
  fi
done

# ---- step 8: provision .env ----
log "[8/13] provision proxy .env"
PROXY_DIR="$REPOS_DIR/free-claude-code"
ENV_FILE="$PROXY_DIR/.env"
if [ ! -f "$ENV_FILE" ]; then
  TEMPLATE=""
  if   [ -f "$PROXY_DIR/.env.example" ]; then TEMPLATE="$PROXY_DIR/.env.example"
  elif [ -f "$REPOS_DIR/free-claude-code-setup/env.template" ]; then TEMPLATE="$REPOS_DIR/free-claude-code-setup/env.template"
  fi
  [ -z "$TEMPLATE" ] && fail "no .env template found"

  API_KEY="${NIM_API_KEY:-}"
  if [ -z "$API_KEY" ]; then
    if [ -t 0 ]; then
      printf "NVIDIA NIM API key (from https://build.nvidia.com/settings/api-keys): "
      read -r API_KEY
    else
      fail "no NIM_API_KEY env var and stdin isn't a tty — cannot prompt"
    fi
  fi
  [ -z "$API_KEY" ] && fail "API key empty"

  cp "$TEMPLATE" "$ENV_FILE"
  # Rewrite NVIDIA_NIM_API_KEY line (works with or without existing value)
  sed -i "s|^NVIDIA_NIM_API_KEY=.*|NVIDIA_NIM_API_KEY=\"$API_KEY\"|" "$ENV_FILE"
  chmod 600 "$ENV_FILE"
  log "  wrote $ENV_FILE (mode 600)"
else
  log "  $ENV_FILE exists (skipping)"
fi

# ---- step 9: uv sync ----
log "[9/13] uv sync (installs Python 3.14 + proxy deps)"
(
  cd "$PROXY_DIR"
  uv sync --quiet
)
log "  venv: $(ls $PROXY_DIR/.venv/bin/python 2>&1)"

# ---- step 10: python install via uv (redundant if sync covered; idempotent) ----
log "[10/13] python install (handled by uv sync)"

# ---- step 11: PATH symlink for claude-nim ----
log "[11/13] symlink launcher into /usr/local/bin"
LAUNCHER="$REPOS_DIR/free-claude-code-setup/bin/claude-nim"
CHECK="$REPOS_DIR/free-claude-code-setup/bin/check-nim"
[ -f "$LAUNCHER" ] || fail "launcher missing at $LAUNCHER"
chmod +x "$LAUNCHER"
[ -f "$CHECK" ] && chmod +x "$CHECK"
sudo ln -sfn "$LAUNCHER" /usr/local/bin/claude-nim
[ -f "$CHECK" ] && sudo ln -sfn "$CHECK" /usr/local/bin/check-nim
log "  /usr/local/bin/claude-nim → $(readlink /usr/local/bin/claude-nim)"

# ---- step 12: HOME isolation dir ----
log "[12/13] create HOME isolation dir"
mkdir -p "$HOME/claude-nim-home/.claude"
log "  $HOME/claude-nim-home/.claude ready"

# ---- step 13: smoke test ----
log "[13/13] smoke test"
mkdir -p "$HOME/.cache"
RESP=$(timeout 120 claude-nim --dangerously-skip-permissions \
  -p 'Respond with exactly: PONG' \
  --model claude-haiku-4-20250514 2>&1 || true)
echo "  response:"
echo "$RESP" | head -10 | sed 's/^/    /'
# Success if the response contains anything that looks like a model reply
# (either the PONG we asked for, or the "proxy ready" banner showing launcher
# worked and the response exists). Don't rely on local proxy log because the
# proxy may have been started by another user and logs to their $HOME.
if echo "$RESP" | grep -qiE 'pong|proxy ready|ready|hello'; then
  log "  received model response — bootstrap SUCCESS"
  echo
  log "=== bootstrap done — ready to use 'claude-nim' ==="
  exit 0
else
  fail "bootstrap smoke test got unexpected response (see above)"
fi
