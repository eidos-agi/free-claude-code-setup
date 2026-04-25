#!/usr/bin/env bash
# V2 (mac): Zero Anthropic traffic under realistic misuse scenarios.
#
# Soft-proof strategy on macOS:
#   - Primary (positive): proxy log shows POST /v1/messages for each scenario
#       — proves the request was served by the local proxy, not Anthropic.
#   - Secondary: the isolated $HOME/claude-nim-home/.claude/.credentials.json
#       never acquires real Anthropic OAuth content (strict regex —
#       claudeAiOauth, sk-ant-, api.anthropic. NOT generic 'accessToken'
#       which would false-positive on MCP server OAuth blobs).
#
# The WSL test took a `/proc/net/tcp` snapshot looking for hits on Anthropic
# IP ranges. We deliberately omit that on macOS: any host claude session
# (including the one that may have spawned this test) holds an ESTABLISHED
# connection to api.anthropic.com, polluting the signal. PID-scoping it
# would race the launcher's exec'd child. Lean on the proxy-log proof —
# it's the strict positive signal anyway.
#
# SAFETY: this test temporarily writes a fake .credentials.json at
# $HOME/.claude/.credentials.json. Real file (if any) is backed up to a
# temp path and restored on EXIT via a trap that survives errors and SIGINT.
# On macOS Claude Code stores OAuth in Keychain, not in this file, so most
# users won't have a real one — but the safety mechanism is still active.

set -u
VALIDATION="V2 no-leak (mac)"
LOG_CACHE="$HOME/.cache/nim-proxy.log"
ISOLATED_HOME="$HOME/claude-nim-home"
WORK=$(mktemp -d -t claude-nim-noleak)

REAL_CRED="$HOME/.claude/.credentials.json"
CRED_BAK=""

restore() {
  # Restore real credentials if we backed them up
  if [ -n "$CRED_BAK" ] && [ -f "$CRED_BAK" ]; then
    cp "$CRED_BAK" "$REAL_CRED" 2>/dev/null || true
    rm -f "$CRED_BAK"
  elif [ -n "$CRED_BAK_FLAG" ]; then
    # Sentinel flag: real file did not exist — make sure we don't leave fake
    rm -f "$REAL_CRED"
  fi
  rm -rf "$WORK" 2>/dev/null || true
}
CRED_BAK_FLAG=""
trap restore EXIT INT TERM

TIMEOUT=$(command -v gtimeout || command -v timeout || true)
[ -z "$TIMEOUT" ] && { echo "[$VALIDATION] need GNU timeout — brew install coreutils" >&2; exit 1; }

echo "=== $VALIDATION ==="

mkdir -p "$ISOLATED_HOME/.claude"

run_scenario() {
  local name="$1"
  local envpfx="$2"
  echo "--- scenario: $name ---"
  local log_start=0
  [ -f "$LOG_CACHE" ] && log_start=$(wc -l < "$LOG_CACHE")

  if [ -n "$envpfx" ]; then
    env $envpfx "$TIMEOUT" 90 claude-nim --dangerously-skip-permissions \
      -p 'one word: ready' --model claude-haiku-4-20250514 \
      > "$WORK/$name.out" 2>&1
  else
    "$TIMEOUT" 90 claude-nim --dangerously-skip-permissions \
      -p 'one word: ready' --model claude-haiku-4-20250514 \
      > "$WORK/$name.out" 2>&1
  fi
  local ec=$?

  local new_posts=0
  if [ -f "$LOG_CACHE" ]; then
    local cur_lines
    cur_lines=$(wc -l < "$LOG_CACHE")
    if [ "$cur_lines" -lt "$log_start" ]; then
      new_posts=$(grep -c 'POST /v1/messages' "$LOG_CACHE" || echo 0)
    else
      new_posts=$(tail -n +$((log_start + 1)) "$LOG_CACHE" | grep -c 'POST /v1/messages' || echo 0)
    fi
  fi
  new_posts=${new_posts:-0}

  printf "  exit=%d  proxy-POSTs=%d\n" "$ec" "$new_posts"
  echo "  output head: $(head -c 140 "$WORK/$name.out" | tr '\n' ' ') ..."
  echo "$name|$ec|$new_posts" >> "$WORK/summary.tsv"
  echo
}

echo "--- warmup ---"
claude-nim -p 'warmup' --model claude-haiku-4-20250514 >/dev/null 2>&1
echo

# 1. baseline
run_scenario "baseline" ""

# 2. polluted env
run_scenario "polluted-env" "ANTHROPIC_API_KEY=sk-ant-fake-would-leak-if-used"

# 3. cached OAuth in real $HOME/.claude (backed up, restored on exit)
mkdir -p "$HOME/.claude"
if [ -f "$REAL_CRED" ]; then
  CRED_BAK=$(mktemp)
  cp "$REAL_CRED" "$CRED_BAK"
else
  CRED_BAK_FLAG="absent"
fi
cat > "$REAL_CRED" <<'JSONEOF'
{"claudeAiOauth":{"accessToken":"fake-oauth-token-would-leak-if-read","refreshToken":"fake","expiresAt":9999999999,"subscriptionType":"pro"}}
JSONEOF
run_scenario "oauth-cached" ""
# Trap will restore on exit, but proactively restore now too so subsequent
# scenarios (and any failure point after this) see normal state.
if [ -n "$CRED_BAK" ]; then
  cp "$CRED_BAK" "$REAL_CRED"; rm -f "$CRED_BAK"; CRED_BAK=""
elif [ "$CRED_BAK_FLAG" = "absent" ]; then
  rm -f "$REAL_CRED"; CRED_BAK_FLAG=""
fi

# 4. proxy cold — kill the listener and let claude-nim auto-restart
PORT=${NIM_PROXY_PORT:-8082}
PIDS=$(lsof -nP -ti tcp:"$PORT" -sTCP:LISTEN 2>/dev/null || true)
[ -n "$PIDS" ] && kill -9 $PIDS 2>/dev/null || true
sleep 1
run_scenario "proxy-cold" ""

# ==== report ====
echo "--- summary ---"
printf "%-20s %6s %14s\n" "scenario" "exit" "proxy-POSTs"
FAIL=0
while IFS='|' read -r name ec posts; do
  [ -z "$name" ] && continue
  printf "%-20s %6s %14s\n" "$name" "${ec:-?}" "${posts:-?}"
  [ "${posts:-0}" -lt 1 ] && FAIL=1
done < "$WORK/summary.tsv"
echo

ISO_CRED="$ISOLATED_HOME/.claude/.credentials.json"
echo "--- isolated credentials ($ISO_CRED) ---"
if [ -f "$ISO_CRED" ]; then
  # Strict regex: only flag actual Anthropic OAuth markers, not generic
  # 'accessToken' which mcpOAuth blobs (Vercel, GitHub MCP, etc) also use.
  if grep -qE 'claudeAiOauth|sk-ant-|api\.anthropic' "$ISO_CRED" 2>/dev/null; then
    echo "  [FAIL] contains Anthropic OAuth markers:"
    head -c 200 "$ISO_CRED" | sed 's/^/    /'
    FAIL=1
  else
    SIZE=$(stat -f%z "$ISO_CRED" 2>/dev/null || echo '?')
    echo "  [PASS] no Anthropic OAuth markers ($SIZE bytes — non-Anthropic content like mcpOAuth is fine)"
  fi
else
  echo "  [PASS] absent"
fi
echo

if [ "$FAIL" -eq 0 ]; then
  echo "=== $VALIDATION: PASS ==="
  exit 0
else
  echo "=== $VALIDATION: FAIL ==="
  exit 1
fi
