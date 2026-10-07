#!/usr/bin/env bash
# harness-session: wraps, but never replaces, a target repo's own gate.
# Retains the full gate output on disk and prints a bounded terminal
# report, so a session doesn't burn context on hundreds of lines of
# framework noise while the full evidence stays available on demand.
# Usage: run-gate.sh <baseline|final> [TARGET_DIR]    (default: current directory)
# Exit: the target gate's own exit code; 2 on invalid phase or missing gate.
# Baseline reuse (M29-001): every green run records a fingerprint of the
# files it proved (the working tree's git tree, ignored files left out, and
# PROGRESS.md and docs/plans/ left out: bookkeeping no gate should judge);
# a red run deletes it. A baseline on a clean tree with the same fingerprint
# is green without running the gate. HARNESS_GATE_REUSE=0 always runs it.
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

# fingerprint: the git tree of the working tree as the gate sees it, via a
# throwaway index (the real index and the worktree are never touched)
fingerprint() {
  local idx
  idx="$(mktemp)"
  cp "$(git rev-parse --git-path index)" "$idx" 2>/dev/null || rm -f "$idx"
  GIT_INDEX_FILE="$idx" git add -A . >/dev/null 2>&1 \
    && GIT_INDEX_FILE="$idx" git rm -rq --cached --ignore-unmatch PROGRESS.md docs/plans >/dev/null 2>&1 \
    && GIT_INDEX_FILE="$idx" git write-tree
  rm -f "$idx"
}
GREEN_FILE=""
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  GREEN_FILE="$(git rev-parse --git-path harness-gate-green)"
fi

if [ "$PHASE" = baseline ] && [ -n "$GREEN_FILE" ] && [ -f "$GREEN_FILE" ] \
   && [ "${HARNESS_GATE_REUSE:-1}" != 0 ] && [ -z "$(git status --porcelain)" ] \
   && [ "$(fingerprint)" = "$(cat "$GREEN_FILE")" ]; then
  echo "GATE: green (baseline reused: the tree is identical, apart from PROGRESS.md and docs/plans/, to the last green gate run in this clone; HARNESS_GATE_REUSE=0 runs it)"
  exit 0
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

if [ -n "$GREEN_FILE" ]; then
  if [ "$status" -eq 0 ]; then fingerprint > "$GREEN_FILE" || rm -f "$GREEN_FILE"; else rm -f "$GREEN_FILE"; fi
fi

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
