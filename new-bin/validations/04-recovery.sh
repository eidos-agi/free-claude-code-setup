#!/bin/bash
# V4: Auto-recovery from failure modes.
#
# 4a: Proxy killed mid-session (SIGKILL) — next claude-nim invocation must
#     relaunch proxy and succeed.
# 4b: "WSL shutdown" simulated by killing ALL proxy processes + clearing any
#     listening state — next invocation must come up clean from scratch.
# 4c: Actual Windows reboot — documented manual, not automated.
#
# Pass: scenarios 4a and 4b both succeed on the NEXT claude-nim call, no
# manual intervention required.

set -u
VALIDATION="V4 recovery"
LOG_CACHE="$HOME/.cache/nim-proxy.log"
WORK=$(mktemp -d -t claude-nim-recovery-XXXXXX)
trap "rm -rf $WORK" EXIT

echo "=== $VALIDATION ==="

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh" >/dev/null 2>&1
export PATH="$HOME/.local/bin:$PATH"

# Warm proxy
echo "--- warmup ---"
claude-nim -p 'warmup' --model claude-haiku-4-20250514 >/dev/null 2>&1
PROXY_PID=$(pgrep -f 'uvicorn server:app' | head -1 || true)
echo "  initial proxy pid: $PROXY_PID"
echo

FAIL=0

# ==== 4a: mid-session crash ====
echo "--- 4a: mid-session SIGKILL ---"
if [ -z "$PROXY_PID" ]; then
  echo "  [FAIL] no proxy running before 4a"
  FAIL=1
else
  kill -9 "$PROXY_PID" 2>/dev/null
  sleep 1
  if pgrep -f 'uvicorn server:app' >/dev/null; then
    echo "  [WARN] proxy still running after kill -9 (retry)"
    pkill -9 -f 'uvicorn server:app' 2>/dev/null
    sleep 1
  fi
  STILL=$(pgrep -f 'uvicorn server:app' | head -1 || true)
  echo "  post-kill proxy pid: ${STILL:-none}"

  # Now invoke claude-nim — expect launcher's lazy-start to kick in
  [ -f "$LOG_CACHE" ] && LOG_START=$(wc -l < "$LOG_CACHE") || LOG_START=0
  T0=$(date +%s)
  timeout 60 claude-nim --dangerously-skip-permissions -p 'one word: recover' \
    --model claude-haiku-4-20250514 > "$WORK/4a.out" 2>&1
  EC=$?
  T1=$(date +%s)
  NEW_PID=$(pgrep -f 'uvicorn server:app' | head -1 || true)
  # Proxy restart truncates the log, so count total POSTs — any ≥1 means served.
  NEW_POSTS=$(grep -c 'POST /v1/messages' "$LOG_CACHE" 2>/dev/null)
  NEW_POSTS=${NEW_POSTS:-0}

  echo "  recovery exit: $EC   took: $((T1-T0))s   new pid: ${NEW_PID:-none}   proxy POSTs: $NEW_POSTS"
  echo "  output tail:"
  head -c 200 "$WORK/4a.out" | sed 's/^/    /'
  echo
  if [ "$EC" -eq 0 ] && [ -n "$NEW_PID" ] && [ "$NEW_PID" != "$PROXY_PID" ] && [ "$NEW_POSTS" -ge 1 ]; then
    echo "  [PASS] 4a recovered with new proxy pid $NEW_PID"
  else
    echo "  [FAIL] 4a did not recover cleanly"
    FAIL=1
  fi
fi

# ==== 4b: full proxy purge (simulates WSL shutdown effect on proxy state) ====
echo
echo "--- 4b: full proxy purge ---"
pkill -9 -f 'uvicorn server:app' 2>/dev/null
pkill -9 -f 'uv run uvicorn' 2>/dev/null
sleep 2
STILL=$(pgrep -f 'uvicorn server:app' | head -1 || true)
if [ -n "$STILL" ]; then
  echo "  [WARN] proxy still pid $STILL after purge"
fi

# Confirm port 8082 is free
CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 2 http://localhost:8082/ 2>&1)
echo "  port 8082 probe after purge: $CODE (expect 000 or failure)"

# Now invoke claude-nim — this simulates "user opens terminal fresh"
[ -f "$LOG_CACHE" ] && LOG_START=$(wc -l < "$LOG_CACHE") || LOG_START=0
T0=$(date +%s)
timeout 120 claude-nim --dangerously-skip-permissions -p 'one word: up' \
  --model claude-haiku-4-20250514 > "$WORK/4b.out" 2>&1
EC=$?
T1=$(date +%s)
NEW_PID=$(pgrep -f 'uvicorn server:app' | head -1 || true)
# Proxy restart truncates the log (launcher uses > not >>), so just count total
# POSTs in current log — any ≥1 means the request was served.
NEW_POSTS=$(grep -c 'POST /v1/messages' "$LOG_CACHE" 2>/dev/null)
NEW_POSTS=${NEW_POSTS:-0}

echo "  recovery exit: $EC   took: $((T1-T0))s   new pid: ${NEW_PID:-none}   proxy POSTs: $NEW_POSTS"
echo "  output tail:"
head -c 200 "$WORK/4b.out" | sed 's/^/    /'
echo
if [ "$EC" -eq 0 ] && [ -n "$NEW_PID" ] && [ "$NEW_POSTS" -ge 1 ]; then
  echo "  [PASS] 4b recovered from full purge"
else
  echo "  [FAIL] 4b did not recover"
  FAIL=1
fi

# ==== 4c: documented manual ====
echo
echo "--- 4c: Windows reboot (documented manual) ---"
echo "  After Windows reboot, open Ubuntu terminal → run 'claude-nim -p \"hi\"'."
echo "  Equivalent to 4b since WSL cold-start starts with no proxy."
echo "  [NOTE] not automated; passes by equivalence if 4b passes."

echo
if [ "$FAIL" -eq 0 ]; then
  echo "=== $VALIDATION: PASS ==="
  exit 0
else
  echo "=== $VALIDATION: FAIL ==="
  exit 1
fi
