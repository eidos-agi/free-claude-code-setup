#!/bin/bash
# run-all.sh — sequence all 5 always-on validations; bail on first FAIL.
#
# Usage (as dshanklin):
#   ./new-bin/validations/run-all.sh
# With reproducibility test (needs root):
#   sudo -E ./new-bin/validations/run-all.sh --include-v5
#
# Exit codes:
#   0 — all validations passed
#   1 — at least one validation failed
#   2 — a validation was skipped due to missing prerequisite

set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
INCLUDE_V5=0
for arg in "$@"; do
  case "$arg" in
    --include-v5) INCLUDE_V5=1 ;;
    *) echo "unknown arg: $arg"; exit 2 ;;
  esac
done

LOG_DIR="$HOME/.cache/claude-nim-validations/$(date +%Y-%m-%d-%H%M%S)"
mkdir -p "$LOG_DIR"

run_one() {
  local name="$1"
  local script="$2"
  local log="$LOG_DIR/$name.log"
  echo ""
  echo "########################################################"
  echo "# $name"
  echo "########################################################"
  bash "$script" 2>&1 | tee "$log"
  local ec=${PIPESTATUS[0]}
  echo "$name exit=$ec" >> "$LOG_DIR/summary.txt"
  return $ec
}

VALIDATIONS=(
  "V1-tool-use:01-tool-use.sh"
  "V2-no-leak:02-no-leak.sh"
  "V3-rate-limit:03-rate-limit.sh"
  "V4-recovery:04-recovery.sh"
)
[ "$INCLUDE_V5" -eq 1 ] && VALIDATIONS+=("V5-reproducibility:05-reproducibility.sh")

OVERALL=0
for v in "${VALIDATIONS[@]}"; do
  name="${v%%:*}"
  script="$DIR/${v##*:}"
  if ! run_one "$name" "$script"; then
    OVERALL=1
    echo ""
    echo "[run-all] $name FAILED — bailing, subsequent validations skipped"
    break
  fi
done

echo
echo "========================================================"
echo "summary (logs: $LOG_DIR):"
cat "$LOG_DIR/summary.txt" 2>/dev/null | sed 's/^/  /'
echo "overall exit: $OVERALL"
echo "========================================================"
exit "$OVERALL"
