#!/usr/bin/env bash
# harness-session: wraps, but never replaces, a target repo's own gate.
# Retains the full gate output on disk and prints a bounded terminal
# report, so a session doesn't burn context on hundreds of lines of
# framework noise while the full evidence stays available on demand.
# Usage: run-gate.sh <baseline|final> [TARGET_DIR]    (default: current directory)
# Exit: the target gate's own exit code; 2 on invalid phase or missing gate.
set -euo pipefail

PHASE="${1:-}"
case "$PHASE" in
  baseline|final) ;;
  *)
    echo "usage: run-gate.sh <baseline|final> [TARGET_DIR]" >&2
    exit 2
    ;;
esac
TARGET="${2:-.}"

cd "$TARGET"
if [ ! -f scripts/e2e.sh ]; then
  echo "GATE: no scripts/e2e.sh in $TARGET" >&2
  exit 2
fi

TS="$(date +%Y%m%d-%H%M%S)"
LOG="${TMPDIR:-/tmp}/harness-gate-${PHASE}-${TS}-$$.log"

echo "=== run-gate ${PHASE} start: $(date) ===" > "$LOG"

start="$(date +%s)"
set +e
bash scripts/e2e.sh >>"$LOG" 2>&1
status=$?
set -e
end="$(date +%s)"
duration=$((end - start))

echo "=== run-gate ${PHASE} end: $(date) (exit ${status}, ${duration}s) ===" >> "$LOG"

if [ "$status" -eq 0 ]; then
  echo "GATE: green (${PHASE})"
  echo "FULL_LOG: $LOG"
  tail -n 20 "$LOG"
else
  echo "GATE: red (${PHASE})"
  echo "FULL_LOG: $LOG"
  tail -n 80 "$LOG"
fi

exit "$status"
