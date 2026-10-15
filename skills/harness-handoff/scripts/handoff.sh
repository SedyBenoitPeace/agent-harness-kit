#!/usr/bin/env bash
# harness-handoff: verify the session-end ritual and print the next agent's prompt.
# Usage: handoff.sh [--run-gate|--skip-gate] [TARGET_DIR]    (default: current directory)
# Exit codes: 0 ready (prompt printed); 1 blocked; 2 harness file broken; 3 not initialized.
set -euo pipefail

SKIP_GATE=0
RUN_GATE=0
TARGET="."
for arg in "$@"; do
  case "$arg" in
    --skip-gate) SKIP_GATE=1 ;;
    --run-gate) RUN_GATE=1 ;;
    *) TARGET="$arg" ;;
  esac
done
cd "$TARGET"

if [ ! -f FEATURES.json ] || [ ! -f PROGRESS.md ]; then
  echo "HARNESS NOT INITIALIZED: FEATURES.json and/or PROGRESS.md missing."
  echo "Scaffold it with the harness-initial-setup skill (or harness-protocol-planning.md)."
  exit 3
fi

command -v jq >/dev/null || { echo "ERROR: jq is required (brew install jq)" >&2; exit 2; }
jq -e . FEATURES.json >/dev/null 2>&1 \
  || { echo "BROKEN HARNESS: FEATURES.json is not valid JSON — run the harness-audit skill."; exit 2; }
[ -f AGENTS.md ] \
  || { echo "BROKEN HARNESS: AGENTS.md missing — the handoff prompt starts there. Run the harness-audit skill."; exit 2; }

# plain-string accumulation (not arrays): empty-array expansion under
# `set -u` breaks on the bash 3.2 that macOS ships
BLOCKED=""
WARNINGS=""

# ritual step 1: everything committed
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  if [ -n "$(git status --porcelain)" ]; then
    BLOCKED="${BLOCKED}BLOCKED: uncommitted changes in the tree — commit (or stash) before handing off
"
  fi
else
  WARNINGS="${WARNINGS}WARNING: not a git repo — clean-tree check skipped
"
fi

# ritual step 2: gate. Never run by default (M34-001): reuse the fingerprint
# harness-session/run-gate.sh records on every green run (same recipe: the
# working tree's git tree, PROGRESS.md and docs/plans/ left out); anything
# else is a NOTE, because the next session's baseline gate runs it anyway.
fingerprint() {
  local idx
  idx="$(mktemp)"
  cp "$(git rev-parse --git-path index)" "$idx" 2>/dev/null || rm -f "$idx"
  GIT_INDEX_FILE="$idx" git add -A . >/dev/null 2>&1 \
    && GIT_INDEX_FILE="$idx" git rm -rq --cached --ignore-unmatch PROGRESS.md docs/plans >/dev/null 2>&1 \
    && GIT_INDEX_FILE="$idx" git write-tree
  rm -f "$idx"
}
GATE_LINE=""
if [ "$SKIP_GATE" -eq 1 ]; then
  WARNINGS="${WARNINGS}WARNING: gate not confirmed (--skip-gate); the next session's baseline gate runs it
"
elif [ "$RUN_GATE" -eq 1 ]; then
  if [ ! -f scripts/e2e.sh ]; then
    BLOCKED="${BLOCKED}BLOCKED: no gate found (scripts/e2e.sh) — a handoff without a gate hands off unproven work
"
  elif ! bash scripts/e2e.sh >/dev/null 2>&1; then
    BLOCKED="${BLOCKED}BLOCKED: gate is red — run: bash scripts/e2e.sh and fix before handing off
"
  else
    GATE_LINE="GATE: green (run now)"
  fi
else
  GREEN_FILE=""
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 && GREEN_FILE="$(git rev-parse --git-path harness-gate-green)"
  if [ -n "$GREEN_FILE" ] && [ -f "$GREEN_FILE" ] && [ "$(fingerprint)" = "$(cat "$GREEN_FILE")" ]; then
    GATE_LINE="GATE: green (last green run, unchanged)"
  else
    WARNINGS="${WARNINGS}NOTE: gate not confirmed for the latest changes; the next session's baseline gate runs it (--run-gate runs it now)
"
  fi
fi

if [ -n "$BLOCKED" ]; then
  echo "HANDOFF BLOCKED"
  printf '%s' "$BLOCKED"
  exit 1
fi

echo "HANDOFF READY"
[ -z "$GATE_LINE" ] || echo "$GATE_LINE"
printf '%s' "$WARNINGS"

# the prompt's opening depends on whether the target carries the protocol doc
if [ -f docs/agents/harness-protocol.md ]; then
  OPEN="Read AGENTS.md, then docs/agents/harness-protocol.md section 2, and"
  PLAN_OPEN="Read AGENTS.md, then docs/agents/harness-protocol.md section 1, and"
  [ -f docs/agents/harness-protocol-planning.md ] \
    && PLAN_OPEN="Read AGENTS.md, then docs/agents/harness-protocol-planning.md, and"
else
  OPEN="Read AGENTS.md and"
  PLAN_OPEN="Read AGENTS.md and"
fi

NEXT="$(jq -r '
  [.features[] | select(.status == "failing")] | sort_by(.milestone, .id)
  | if length == 0 then "" else "\(.[0].id) — \(.[0].title) (verify: \(.[0].verify))" end
' FEATURES.json)"

echo
echo "== Prompt for the next agent (any vendor) =="
if [ -n "$NEXT" ]; then
  cat <<EOF
$OPEN perform exactly ONE coding session. The next feature is
$NEXT.
Confirm bash scripts/e2e.sh is green before starting; implement test-first;
flip the status to passing only when the verify criterion is proven; append
a PROGRESS.md entry; commit; then STOP — do not start another feature.
EOF
else
  cat <<EOF
$PLAN_OPEN plan the next milestone: nothing is failing. Interview me about
what to build next, append the agreed features to FEATURES.json with
falsifiable verify criteria, and write no feature code this session. Keep
bash scripts/e2e.sh green.
EOF
fi
echo "== End prompt =="
