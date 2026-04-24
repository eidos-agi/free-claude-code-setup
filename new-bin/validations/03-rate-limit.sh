#!/bin/bash
# V3: Rate-limit behavior under burst.
#
# NVIDIA NIM free tier: 40 req/min. GlobalRateLimiter in proxy:
#   - proactive 40/60s rolling window
#   - reactive 60s block on 429
#   - 5 concurrency slots
#   - 3 retries with exponential backoff + jitter
#
# Pass criteria:
#   - ≥40 requests succeed (200 OK)
#   - Overflow handled gracefully (retry-and-succeed, or clean 429 with readable error)
#   - No launcher hang / no session crash / no orphan proxy process
#   - Wall time bounded (no infinite retry loop)

set -u
VALIDATION="V3 rate-limit"
BURST=60
CONCURRENCY=8
TIMEOUT_PER=30
LOG_CACHE="$HOME/.cache/nim-proxy.log"
WORK=$(mktemp -d -t claude-nim-burst-XXXXXX)
trap "rm -rf $WORK" EXIT

echo "=== $VALIDATION ==="
echo "Plan: fire $BURST requests, $CONCURRENCY in flight at a time, each timeout ${TIMEOUT_PER}s"
echo

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh" >/dev/null 2>&1
export PATH="$HOME/.local/bin:$PATH"

# Warm the proxy
claude-nim -p 'warmup' --model claude-haiku-4-20250514 >/dev/null 2>&1
PROXY_PID_BEFORE=$(pgrep -f 'uvicorn server:app' | head -1 || true)
echo "  proxy pid before burst: ${PROXY_PID_BEFORE:-none}"

[ -f "$LOG_CACHE" ] && LOG_START=$(wc -l < "$LOG_CACHE") || LOG_START=0

# One worker: claude-nim call, capture exit + tail of output
worker() {
  local i="$1"
  local t0=$(date +%s)
  timeout "$TIMEOUT_PER" claude-nim --dangerously-skip-permissions \
    -p 'one word: ready' --model claude-haiku-4-20250514 \
    > "$WORK/r$i.out" 2>&1
  local ec=$?
  local t1=$(date +%s)
  echo "$i $ec $((t1-t0))" >> "$WORK/results.txt"
}
export -f worker
export WORK TIMEOUT_PER

echo "  firing burst..."
T_START=$(date +%s)
seq 1 "$BURST" | xargs -n1 -P"$CONCURRENCY" -I{} bash -c 'worker {}' _
T_END=$(date +%s)
WALL=$((T_END - T_START))

# --- analysis ---
SUCCESS=$(awk '$2==0' "$WORK/results.txt" | wc -l)
TIMEOUT_CNT=$(awk '$2==124' "$WORK/results.txt" | wc -l)
OTHER_FAIL=$(awk '$2!=0 && $2!=124' "$WORK/results.txt" | wc -l)

echo
echo "--- burst complete in ${WALL}s ---"
echo "  success (exit 0): $SUCCESS / $BURST"
echo "  timeouts        : $TIMEOUT_CNT"
echo "  other failures  : $OTHER_FAIL"

# Sample a few failed outputs
if [ "$OTHER_FAIL" -gt 0 ] || [ "$TIMEOUT_CNT" -gt 0 ]; then
  echo
  echo "--- sample failed outputs ---"
  awk '$2!=0' "$WORK/results.txt" | head -3 | awk '{print $1}' | while read i; do
    echo "  request #$i (exit code $(awk -v i=$i '$1==i {print $2}' $WORK/results.txt)):"
    head -c 400 "$WORK/r$i.out" | sed 's/^/    /'
    echo
  done
fi

# Proxy health after burst
PROXY_PID_AFTER=$(pgrep -f 'uvicorn server:app' | head -1 || true)
PROBE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 3 http://localhost:8082/ 2>&1)

NEW_POSTS=$(tail -n +$((LOG_START + 1)) "$LOG_CACHE" 2>/dev/null | grep -c 'POST /v1/messages' || true)
NEW_429=$(tail -n +$((LOG_START + 1)) "$LOG_CACHE" 2>/dev/null | grep -c '429' || true)
NEW_500=$(tail -n +$((LOG_START + 1)) "$LOG_CACHE" 2>/dev/null | grep -c '500' || true)
NEW_POSTS=${NEW_POSTS:-0}; NEW_429=${NEW_429:-0}; NEW_500=${NEW_500:-0}

echo
echo "--- proxy log stats for this burst ---"
echo "  POSTs   : $NEW_POSTS"
echo "  429s    : $NEW_429"
echo "  500s    : $NEW_500"
echo
echo "--- proxy health after burst ---"
echo "  pid: ${PROXY_PID_AFTER:-GONE}   HTTP probe: $PROBE"

# --- verdict ---
FAIL=0
if [ "$SUCCESS" -lt 40 ]; then
  echo "  [FAIL] only $SUCCESS requests succeeded (need ≥40)"
  FAIL=1
else
  echo "  [PASS] $SUCCESS requests succeeded (≥40)"
fi

if [ -z "$PROXY_PID_AFTER" ]; then
  echo "  [FAIL] proxy process died during burst"
  FAIL=1
elif [ "$PROBE" != "401" ] && [ "$PROBE" != "200" ]; then
  echo "  [FAIL] proxy unresponsive (probe=$PROBE)"
  FAIL=1
else
  echo "  [PASS] proxy survived burst (pid $PROXY_PID_AFTER, probe $PROBE)"
fi

if [ "$NEW_500" -gt "$((BURST / 4))" ]; then
  echo "  [FAIL] too many 500s ($NEW_500) — proxy-side bug under load"
  FAIL=1
else
  echo "  [PASS] proxy 500-rate acceptable ($NEW_500)"
fi

if [ "$WALL" -gt 600 ]; then
  echo "  [FAIL] burst took ${WALL}s (>10min) — likely stuck in retry loop"
  FAIL=1
else
  echo "  [PASS] burst completed in ${WALL}s (bounded)"
fi

echo
if [ "$FAIL" -eq 0 ]; then
  echo "=== $VALIDATION: PASS ==="
  exit 0
else
  echo "=== $VALIDATION: FAIL ==="
  exit 1
fi
