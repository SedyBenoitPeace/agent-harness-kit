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
# Inside a run (.harness-run/start in the main repo, found from a lane
# worktree too) it appends `<epoch> gate <id|-> <phase> <start|green|red>`
# to .harness-run/events.log; the id comes from a lane/<id> branch (M47-001).
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
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
# M47-001: one events.log line, only inside a run
ev() { local root; root="$(cd "$(git rev-parse --git-common-dir 2>/dev/null)/.." 2>/dev/null && pwd)" || return 0
  [ ! -f "$root/.harness-run/start" ] || echo "$(date +%s) $*" >> "$root/.harness-run/events.log"; }
# M47-002: refresh the run board last (guarded; never changes output or exit code)
_bt="$(cd . 2>/dev/null && pwd)" || _bt=.; _bs="$HERE/../../harness-run/scripts/board.sh"
# shellcheck disable=SC2317,SC2329 # runs from the EXIT trap
board() { local r; r="$(cd "$_bt" && cd "$(git rev-parse --git-common-dir 2>/dev/null)/.." 2>/dev/null && pwd)" || return 0
  [ -s "$r/.harness-run/start" ] || return 0
  [ "$(tail -n1 "$r/.harness-run/events.log" 2>/dev/null | cut -d' ' -f2)" != run-end ] || return 0
  bash "$_bs" "$_bt" >/dev/null 2>&1 || true; }
trap board EXIT
gate_id="$(git branch --show-current 2>/dev/null || true)"
case "$gate_id" in lane/?*) gate_id="${gate_id#lane/}" ;; *) gate_id=- ;; esac
GREEN_FILE=""
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  GREEN_FILE="$(git rev-parse --git-path harness-gate-green)"
fi

if [ "$PHASE" = baseline ] && [ -n "$GREEN_FILE" ] && [ -f "$GREEN_FILE" ] \
   && [ "${HARNESS_GATE_REUSE:-1}" != 0 ] && [ -z "$(git status --porcelain)" ] \
   && [ "$(fingerprint)" = "$(cat "$GREEN_FILE")" ]; then
  ev gate "$gate_id" baseline green
  echo "GATE: green (baseline reused: the tree is identical, apart from PROGRESS.md and docs/plans/, to the last green gate run in this clone; HARNESS_GATE_REUSE=0 runs it)"
  exit 0
fi

TS="$(date +%Y%m%d-%H%M%S)"
LOG="${TMPDIR:-/tmp}/harness-gate-${PHASE}-${TS}-$$.log"

echo "=== run-gate ${PHASE} start: $(date) ===" > "$LOG"

ev gate "$gate_id" "$PHASE" start
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

if [ "$status" -eq 0 ]; then ev gate "$gate_id" "$PHASE" green; else ev gate "$gate_id" "$PHASE" red; fi
if [ "$status" -eq 0 ]; then
  echo "GATE: green (${PHASE})"
  echo "FULL_LOG: $LOG"
  tail -n 20 "$LOG" | cut -c1-300
else
  echo "GATE: red (${PHASE})"
  echo "FULL_LOG: $LOG"
  # same capped shape as quiet.sh (M34-008): matched lines plus the tail
  bash "$HERE/quiet.sh" --summary "$LOG"
fi

exit "$status"
