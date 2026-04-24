#!/bin/bash
# V2: Zero Anthropic traffic under realistic misuse scenarios.
#
# Soft-proof strategy (no iptables, no tcpdump):
#   - Primary (positive): proxy log shows POST /v1/messages for each scenario
#       — proves the request was served by the local proxy, not Anthropic
#   - Secondary (negative): one ss snapshot taken RIGHT AFTER each scenario
#       — grep for established connections to Anthropic IPs (best-effort; WSL1
#       /proc/net/tcp scoping may miss cross-session sockets)
#   - Tertiary: the isolated $HOME/claude-nim-home/.claude/.credentials.json
#       never acquires real Anthropic OAuth content
#
# Scenarios (all via claude-nim, since the launcher is the intended entry point):
#   1. baseline — plain claude-nim -p
#   2. polluted — ANTHROPIC_API_KEY=sk-ant-fake set in env (launcher must clear)
#   3. oauth    — valid-looking OAuth placed in $HOME/.claude before call
#   4. cold     — proxy killed before call (launcher must auto-restart)

set -u
VALIDATION="V2 no-leak"
LOG_CACHE="$HOME/.cache/nim-proxy.log"
ISOLATED_HOME="$HOME/claude-nim-home"
WORK=$(mktemp -d -t claude-nim-noleak-XXXXXX)
trap "rm -rf $WORK" EXIT

# Anthropic IPv4 subnet in /proc/net/tcp hex (little-endian):
#   160.79.104.0/23 → prefix 0A684F (160.79.104.*) or 0A694F (160.79.105.*)
HEX_IPV4='0A684F|0A694F'
# IPv6 prefix 2607:6bc0::/32 in /proc/net/tcp6 shows address as 07266BC0...
HEX_IPV6='07266BC0'

echo "=== $VALIDATION ==="

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh" >/dev/null 2>&1
export PATH="$HOME/.local/bin:$PATH"

snapshot_tcp() {
  awk 'NR>1 {print $3}' /proc/net/tcp  2>/dev/null
  awk 'NR>1 {print $3}' /proc/net/tcp6 2>/dev/null
}

count_anthropic_hits() {
  local addrs="$1"
  local h=0 h6=0
  h=$(echo "$addrs" | grep -cE "^($HEX_IPV4)" || true)
  h6=$(echo "$addrs" | grep -cE "$HEX_IPV6" || true)
  echo $((h + h6))
}

# Ensure isolation dir exists
mkdir -p "$ISOLATED_HOME/.claude"

run_scenario() {
  local name="$1"
  local envpfx="$2"
  echo "--- scenario: $name ---"
  [ -f "$LOG_CACHE" ] && local log_start=$(wc -l < "$LOG_CACHE") || local log_start=0

  # Run the command with optional env prefix
  if [ -n "$envpfx" ]; then
    env $envpfx timeout 90 claude-nim --dangerously-skip-permissions \
      -p 'one word: ready' --model claude-haiku-4-20250514 \
      > "$WORK/$name.out" 2>&1
  else
    timeout 90 claude-nim --dangerously-skip-permissions \
      -p 'one word: ready' --model claude-haiku-4-20250514 \
      > "$WORK/$name.out" 2>&1
  fi
  local ec=$?

  # Immediate snapshot of TCP state
  local addrs
  addrs=$(snapshot_tcp)
  local leak_hits
  leak_hits=$(count_anthropic_hits "$addrs")

  local new_posts=0
  if [ -f "$LOG_CACHE" ]; then
    # Handle log truncation: if current file is smaller than our start offset,
    # the proxy was restarted and the log was overwritten (launcher uses > not >>).
    local cur_lines
    cur_lines=$(wc -l < "$LOG_CACHE")
    if [ "$cur_lines" -lt "$log_start" ]; then
      new_posts=$(grep -c 'POST /v1/messages' "$LOG_CACHE" || echo 0)
    else
      new_posts=$(tail -n +$((log_start + 1)) "$LOG_CACHE" | grep -c 'POST /v1/messages' || echo 0)
    fi
  fi

  printf "  exit=%d  Anthropic-tcp-hits=%d  proxy-POSTs=%d\n" "$ec" "$leak_hits" "$new_posts"
  echo "  output head: $(head -c 140 "$WORK/$name.out" | tr '\n' ' ') ..."
  echo "$name|$ec|$leak_hits|$new_posts" >> "$WORK/summary.tsv"
  echo
}

# Warm up (not a scenario)
echo "--- warmup ---"
claude-nim -p 'warmup' --model claude-haiku-4-20250514 >/dev/null 2>&1
echo

# 1. baseline
run_scenario "baseline" ""

# 2. polluted env
run_scenario "polluted-env" "ANTHROPIC_API_KEY=sk-ant-fake-would-leak-if-used"

# 3. cached OAuth present in real HOME (not isolated)
mkdir -p "$HOME/.claude"
CRED_BAK=""
if [ -f "$HOME/.claude/.credentials.json" ]; then
  CRED_BAK=$(mktemp)
  cp "$HOME/.claude/.credentials.json" "$CRED_BAK"
fi
cat > "$HOME/.claude/.credentials.json" <<'JSONEOF'
{"claudeAiOauth":{"accessToken":"fake-oauth-token-would-leak-if-read","refreshToken":"fake","expiresAt":9999999999,"subscriptionType":"pro"}}
JSONEOF
run_scenario "oauth-cached" ""
# Restore state
if [ -n "$CRED_BAK" ]; then cp "$CRED_BAK" "$HOME/.claude/.credentials.json"; rm -f "$CRED_BAK"
else rm -f "$HOME/.claude/.credentials.json"; fi

# 4. proxy cold — kill and let launcher auto-start
pkill -9 -f 'uvicorn server:app' 2>/dev/null
sleep 1
run_scenario "proxy-cold" ""

# ==== report ====
echo "--- summary ---"
printf "%-20s %6s %16s %14s\n" "scenario" "exit" "anthropic-hits" "proxy-POSTs"
FAIL=0
while IFS='|' read -r name ec leak posts; do
  [ -z "$name" ] && continue
  printf "%-20s %6s %16s %14s\n" "$name" "${ec:-?}" "${leak:-?}" "${posts:-?}"
  [ "${leak:-0}"  -gt 0 ] && FAIL=1
  [ "${posts:-0}" -lt 1 ] && FAIL=1
done < "$WORK/summary.tsv"
echo

# Isolation check
ISO_CRED="$ISOLATED_HOME/.claude/.credentials.json"
echo "--- isolated credentials ($ISO_CRED) ---"
if [ -f "$ISO_CRED" ]; then
  if grep -qE 'claudeAiOauth|accessToken|sk-ant-' "$ISO_CRED" 2>/dev/null; then
    echo "  [FAIL] contains real-looking OAuth content:"
    head -c 200 "$ISO_CRED" | sed 's/^/    /'
    FAIL=1
  else
    echo "  [PASS] empty or non-OAuth ($(stat -c%s "$ISO_CRED" 2>/dev/null || echo '?') bytes)"
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
