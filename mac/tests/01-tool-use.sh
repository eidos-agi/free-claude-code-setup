#!/usr/bin/env bash
# V1 (mac): Tool use round-trips cleanly through the NIM proxy.
#
# Drives a real Claude Code session through claude-nim — Read + Edit + Bash.
# Pass: disk mutation lands + bash output appears in final response + no 500 in log.
#
# Pure macOS port of new-bin/validations/01-tool-use.sh — no nvm, BSD-stat-friendly,
# uses gtimeout if available (coreutils on Homebrew), else /usr/bin/time-bounded.
set -u
VALIDATION="V1 tool-use (mac)"
SCRATCH=$(mktemp -d -t claude-nim-tool)
FIXTURE="$SCRATCH/fixture.txt"
LOG_CACHE="$HOME/.cache/nim-proxy.log"

cleanup() { rm -rf "$SCRATCH"; }
trap cleanup EXIT

TIMEOUT=$(command -v gtimeout || command -v timeout || true)
[ -z "$TIMEOUT" ] && { echo "[$VALIDATION] need GNU timeout — brew install coreutils" >&2; exit 1; }

printf "line one\nline two\nline three\n" > "$FIXTURE"
echo "=== $VALIDATION ==="
echo "Scratch: $SCRATCH"
echo

[ -f "$LOG_CACHE" ] && LOG_START=$(wc -l < "$LOG_CACHE") || LOG_START=0

PROMPT=$(cat <<EOF
Please do three things, in order, using your tools:
1. Use the Read tool on the file at $FIXTURE
2. Use the Edit tool to replace the exact string "line two" with "HELLO" in that file
3. Use the Bash tool to run: wc -l $FIXTURE

After finishing, tell me the line count from step 3 in your final response.
EOF
)

echo "--- prompt ---"
echo "$PROMPT"
echo
echo "--- claude-nim response ---"
RESPONSE_FILE="$SCRATCH/response.txt"
"$TIMEOUT" 180 claude-nim --dangerously-skip-permissions \
  -p "$PROMPT" \
  --model claude-haiku-4-20250514 \
  > "$RESPONSE_FILE" 2>&1
CLAUDE_EC=$?
cat "$RESPONSE_FILE"
echo
echo "  claude-nim exit: $CLAUDE_EC"
echo

echo "--- verification ---"
FAIL=0

LINE2=$(sed -n '2p' "$FIXTURE" 2>/dev/null)
if [ "$LINE2" = "HELLO" ]; then
  echo "  [PASS] disk edit landed (line 2 = 'HELLO')"
else
  echo "  [FAIL] disk edit missing (line 2 = '$LINE2')"
  FAIL=1
fi

if grep -qE '\b3\b' "$RESPONSE_FILE"; then
  echo "  [PASS] line count (3) surfaced in response"
else
  echo "  [FAIL] line count not in response"
  FAIL=1
fi

if [ -f "$LOG_CACHE" ]; then
  NEW_ERRORS=$(tail -n +$((LOG_START + 1)) "$LOG_CACHE" | grep -c '500 Internal Server Error' || true)
  NEW_ERRORS=${NEW_ERRORS:-0}
  if [ "$NEW_ERRORS" -eq 0 ]; then
    echo "  [PASS] no 500 errors in proxy log (from line $LOG_START)"
  else
    echo "  [FAIL] $NEW_ERRORS 500 errors in proxy log:"
    tail -n +$((LOG_START + 1)) "$LOG_CACHE" | grep -A2 '500 Internal Server Error' | head -20
    FAIL=1
  fi

  NEW_POSTS=$(tail -n +$((LOG_START + 1)) "$LOG_CACHE" | grep -c 'POST /v1/messages' || true)
  NEW_POSTS=${NEW_POSTS:-0}
  if [ "$NEW_POSTS" -ge 1 ]; then
    echo "  [PASS] proxy received $NEW_POSTS POST /v1/messages request(s)"
  else
    echo "  [FAIL] proxy log shows no POST /v1/messages during this run"
    FAIL=1
  fi
fi

echo
if [ "$FAIL" -eq 0 ]; then
  echo "=== $VALIDATION: PASS ==="
  exit 0
else
  echo "=== $VALIDATION: FAIL ==="
  exit 1
fi
