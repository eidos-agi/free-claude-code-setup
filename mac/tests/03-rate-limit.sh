#!/usr/bin/env bash
# V3 (mac): Rate-limit behavior under burst.
#
# NIM free tier: 40 req/min. Proxy GlobalRateLimiter is proactive (40/60s rolling),
# reactive on 429s, with retries.
#
# Pass criteria:
#   - ≥40 requests succeed (200 OK)
#   - Overflow handled gracefully (clean retry-and-succeed or readable 429)
#   - No launcher hang / no session crash / no orphan proxy
#   - Wall time bounded (no infinite retry loop)

set -u
VALIDATION="V3 rate-limit (mac)"
BURST=${BURST:-60}
CONCURRENCY=${CONCURRENCY:-8}
# Each claude-nim invocation issues ~2 proxy calls (init + inference). With
# NIM's 40/min cap, concurrency 8, and step-3.5-flash averaging ~7s, the tail
# of clients can sit in the proxy's rate-limit queue past 30s. 60s tolerates
# normal queue-and-serve behaviour without masking a real hang.
TIMEOUT_PER=${TIMEOUT_PER:-60}
LOG_CACHE="$HOME/.cache/nim-proxy.log"
WORK=$(mktemp -d -t claude-nim-burst)
trap "rm -rf $WORK" EXIT

TIMEOUT=$(command -v gtimeout || command -v timeout || true)
[ -z "$TIMEOUT" ] && { echo "[$VALIDATION] need GNU timeout — brew install coreutils" >&2; exit 1; }

echo "=== $VALIDATION ==="
echo "Plan: fire $BURST requests, $CONCURRENCY in flight at a time, each timeout ${TIMEOUT_PER}s"
echo

# Warm the proxy
claude-nim -p 'warmup' --model claude-haiku-4-20250514 >/dev/null 2>&1
PROXY_PID_BEFORE=$(pgrep -f 'uvicorn server:app' | head -1 || true)
echo "  proxy pid before burst: ${PROXY_PID_BEFORE:-none}"

[ -f "$LOG_CACHE" ] && LOG_START=$(wc -l < "$LOG_CACHE") || LOG_START=0

worker() {
  local i="$1"
  local t0=$(date +%s)
  "$TIMEOUT" "$TIMEOUT_PER" claude-nim --dangerously-skip-permissions \
    -p 'one word: ready' --model claude-haiku-4-20250514 \
    > "$WORK/r$i.out" 2>&1
  local ec=$?
  local t1=$(date +%s)
  echo "$i $ec $((t1-t0))" >> "$WORK/results.txt"
}
export -f worker
export WORK TIMEOUT_PER TIMEOUT

echo "  firing burst..."
T_START=$(date +%s)
seq 1 "$BURST" | xargs -n1 -P"$CONCURRENCY" -I{} bash -c 'worker {}' _
T_END=$(date +%s)
WALL=$((T_END - T_START))

SUCCESS=$(awk '$2==0' "$WORK/results.txt" | wc -l | tr -d ' ')
TIMEOUT_CNT=$(awk '$2==124' "$WORK/results.txt" | wc -l | tr -d ' ')
OTHER_FAIL=$(awk '$2!=0 && $2!=124' "$WORK/results.txt" | wc -l | tr -d ' ')

echo
echo "--- burst complete in ${WALL}s ---"
echo "  success (exit 0): $SUCCESS / $BURST"
echo "  timeouts        : $TIMEOUT_CNT"
echo "  other failures  : $OTHER_FAIL"

if [ "$OTHER_FAIL" -gt 0 ] || [ "$TIMEOUT_CNT" -gt 0 ]; then
  echo
  echo "--- sample failed outputs ---"
  awk '$2!=0' "$WORK/results.txt" | head -3 | awk '{print $1}' | while read i; do
    echo "  request #$i (exit $(awk -v i=$i '$1==i {print $2}' $WORK/results.txt)):"
    head -c 400 "$WORK/r$i.out" | sed 's/^/    /'
    echo
  done
fi

PROXY_PID_AFTER=$(pgrep -f 'uvicorn server:app' | head -1 || true)
PORT=${NIM_PROXY_PORT:-8082}
PROBE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 3 "http://localhost:${PORT}/" 2>&1)

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
