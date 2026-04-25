#!/usr/bin/env bash
# bootstrap.sh (mac) — one-command setup of the free-claude-code NIM proxy on macOS.
#
# Mac counterpart to ../bootstrap.sh. Skips all WSL-specific steps (systemd hold,
# resolv.conf pinning, version-pinned Linux Claude Code). Uses Homebrew when
# helpful, but doesn't require it — uv is the only hard prerequisite, and the
# script will install it if missing.
#
# Usage:
#   bash mac/bootstrap.sh
#   NIM_API_KEY=nvapi-... bash mac/bootstrap.sh
#
# Pass criteria: script exits 0; `claude-nim --version` returns a model response.

set -eu

REPO_ROOT="$(cd "$(dirname "$(/usr/bin/python3 -c 'import os,sys;print(os.path.realpath(sys.argv[1]))' "$0")")/.." && pwd)"
PROXY_DIR="$REPO_ROOT/proxy"
ENV_FILE="$PROXY_DIR/.env"
PROXY_PORT="${NIM_PROXY_PORT:-8082}"

log() { printf '[bootstrap] %s\n' "$*"; }
fail() { printf '[bootstrap] FAIL: %s\n' "$*" >&2; exit 1; }

log "=== free-claude-code-setup mac bootstrap ==="
log "user: $(whoami)   home: $HOME   repo: $REPO_ROOT   port: $PROXY_PORT"

# ---- 1. preflight ----
log "[1/9] preflight"
[ "$(uname)" = "Darwin" ] || fail "this is the macOS bootstrap — use ../bootstrap.sh on Linux/WSL"
[ "$(whoami)" = "root" ] && fail "do not run as root"
command -v curl >/dev/null || fail "curl missing"
command -v git  >/dev/null || fail "git missing"
[ -d "$PROXY_DIR" ] || fail "proxy dir not found at $PROXY_DIR — clone the repo with --recurse or git subtree was incomplete"

# ---- 2. uv (only hard dep — bundles its own Python 3.14) ----
log "[2/9] uv"
if [ ! -x "$HOME/.local/bin/uv" ] && ! command -v uv >/dev/null 2>&1; then
    log "  installing uv via astral.sh installer"
    curl -LsSf https://astral.sh/uv/install.sh | sh >/dev/null 2>&1
fi
export PATH="$HOME/.local/bin:$PATH"
log "  uv: $(uv --version)"

# ---- 3. claude CLI present? ----
log "[3/9] claude CLI"
if ! command -v claude >/dev/null 2>&1 && [ ! -x "$HOME/.local/bin/claude" ]; then
    log "  no claude on PATH — try installing one of:"
    log "    npm install -g @anthropic-ai/claude-code"
    log "    or download the macOS installer from https://www.anthropic.com/claude-code"
    log "  bootstrap will continue but the smoke test will fail until claude is installed."
else
    CLAUDE_PATH="$(command -v claude || echo $HOME/.local/bin/claude)"
    log "  claude: $CLAUDE_PATH ($($CLAUDE_PATH --version 2>/dev/null || echo unknown))"
fi

# ---- 4. provision proxy/.env ----
log "[4/9] proxy/.env"
if [ ! -f "$ENV_FILE" ]; then
    TEMPLATE=""
    if   [ -f "$PROXY_DIR/.env.example" ]; then TEMPLATE="$PROXY_DIR/.env.example"
    elif [ -f "$REPO_ROOT/env.template"   ]; then TEMPLATE="$REPO_ROOT/env.template"
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
    # macOS sed needs -i ''
    sed -i '' "s|^NVIDIA_NIM_API_KEY=.*|NVIDIA_NIM_API_KEY=\"$API_KEY\"|" "$ENV_FILE"
    chmod 600 "$ENV_FILE"
    log "  wrote $ENV_FILE (mode 600)"
else
    log "  $ENV_FILE exists (skipping)"
fi

# ---- 5. uv sync (downloads Python 3.14 + proxy deps) ----
log "[5/9] uv sync"
(
    cd "$PROXY_DIR"
    uv sync --quiet
)
log "  venv: $(ls "$PROXY_DIR/.venv/bin/python" 2>&1)"

# ---- 6. chmod launchers ----
log "[6/9] chmod launchers"
for f in claude-nim stop-nim-proxy check-nim; do
    [ -f "$REPO_ROOT/mac/bin/$f" ] && chmod +x "$REPO_ROOT/mac/bin/$f"
done

# ---- 7. symlink into a writable PATH dir ----
log "[7/9] symlink launchers onto PATH"
TARGET_DIR=""
for d in /opt/homebrew/bin /usr/local/bin "$HOME/.local/bin"; do
    if [ -d "$d" ] && [ -w "$d" ]; then TARGET_DIR="$d"; break; fi
done
if [ -z "$TARGET_DIR" ]; then
    mkdir -p "$HOME/.local/bin"
    TARGET_DIR="$HOME/.local/bin"
    log "  using $TARGET_DIR — make sure it's on your PATH"
fi
for f in claude-nim stop-nim-proxy check-nim claude-nim-watch claude-nim-dashboard; do
    src="$REPO_ROOT/mac/bin/$f"
    [ -f "$src" ] || continue
    ln -sfn "$src" "$TARGET_DIR/$f"
    log "  $TARGET_DIR/$f -> $(readlink "$TARGET_DIR/$f")"
done

# ---- 8. python sanity ----
# uv ships a pre-installed cpython-3.14.0rc2 that lands a typing internal
# pydantic 2.12.5 asserts on. proxy/.python-version pins 3.14.3 so a fresh
# uv sync should fetch stable. Verify and re-sync onto stable if uv picked rc.
log "[8/9] python sanity (avoid 3.14.0rc2 -> pydantic ForwardRef assert)"
PROXY_PY="$PROXY_DIR/.venv/bin/python"
if [ -x "$PROXY_PY" ]; then
    PY_VER=$("$PROXY_PY" --version 2>&1 | awk '{print $2}')
    case "$PY_VER" in
        *rc*|*a[0-9]*|*b[0-9]*)
            log "  detected pre-release Python in venv: $PY_VER — repinning to 3.14.3 stable"
            (
                cd "$PROXY_DIR"
                uv python pin 3.14.3 >/dev/null
                uv venv --python 3.14.3 --clear >/dev/null
                uv sync --quiet
            )
            log "  rebuilt: $($PROXY_PY --version 2>&1)"
            ;;
        *)
            log "  ok: $PY_VER"
            ;;
    esac
else
    fail "proxy venv missing at $PROXY_PY — step 5 should have created it"
fi

# ---- 9. smoke test ----
log "[9/9] smoke test"
mkdir -p "$HOME/.cache" "$HOME/claude-nim-home/.claude"
if ! command -v claude-nim >/dev/null 2>&1; then
    fail "claude-nim not on PATH after symlink (TARGET_DIR=$TARGET_DIR). Add it to PATH and retry."
fi
RESP=$(timeout 120 claude-nim --dangerously-skip-permissions \
    -p 'Respond with exactly: PONG' \
    --model claude-haiku-4-20250514 2>&1 || true)
echo "  response:"
echo "$RESP" | head -10 | sed 's/^/    /'
if echo "$RESP" | grep -qiE 'pong|proxy ready|ready|hello'; then
    log "  received model response — bootstrap SUCCESS"
    log "=== bootstrap done — try:  claude-nim ==="
    exit 0
else
    fail "smoke test got unexpected response (see above). Try: tail -30 \$HOME/.cache/nim-proxy.log"
fi
