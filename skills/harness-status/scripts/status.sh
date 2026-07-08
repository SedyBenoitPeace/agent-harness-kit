#!/usr/bin/env bash
# harness-status: read-only "where am I?" report for a harnessed repo.
# Usage: status.sh [--run-gate] [TARGET_DIR]    (default: current directory)
# Exit codes: 0 report printed; 2 harness file broken; 3 harness not initialized.
set -euo pipefail

RUN_GATE=0
TARGET="."
for arg in "$@"; do
  case "$arg" in
    --run-gate) RUN_GATE=1 ;;
    *) TARGET="$arg" ;;
  esac
done
cd "$TARGET"

if [ ! -f FEATURES.json ] || [ ! -f PROGRESS.md ]; then
  echo "HARNESS NOT INITIALIZED: FEATURES.json and/or PROGRESS.md missing."
  echo "Scaffold it with the harness-setup skill (or harness-protocol.md section 1)."
  exit 3
fi

command -v jq >/dev/null || { echo "ERROR: jq is required (brew install jq)" >&2; exit 2; }
jq -e . FEATURES.json >/dev/null 2>&1 \
  || { echo "BROKEN HARNESS: FEATURES.json is not valid JSON — run the harness-audit skill."; exit 2; }

echo "HARNESS STATUS"
echo
echo "== Milestones =="
jq -r '
  .milestones as $m
  | (.features | group_by(.milestone))[]
  | (.[0].milestone | tostring) as $k
  | ([.[] | select(.status == "passing")] | length) as $p
  | "M\($k): \($p)/\(length) passing — \($m[$k] // "?")"
' FEATURES.json

echo
echo "== Totals =="
jq -r '
  .features
  | "passing \([.[] | select(.status == "passing")] | length), failing \([.[] | select(.status == "failing")] | length), deferred \([.[] | select(.status == "deferred")] | length), superseded \([.[] | select(.status == "superseded")] | length)"
' FEATURES.json

echo
echo "== Next feature (lowest milestone, then lowest id, among failing) =="
jq -r '
  [.features[] | select(.status == "failing")] | sort_by(.milestone, .id)
  | if length == 0
    then "NEXT: none — nothing failing; plan new work (protocol section 1) or run a maintenance pass (section 3)"
    else "NEXT: \(.[0].id) — \(.[0].title)\n  verify: \(.[0].verify)"
    end
' FEATURES.json

echo
echo "== Last session (PROGRESS.md) =="
if grep -q '^## ' PROGRESS.md; then
  awk '/^## /{n++} n==1' PROGRESS.md
else
  echo "(no session entries yet)"
fi

if [ "$RUN_GATE" -eq 1 ]; then
  echo
  echo "== Gate =="
  if [ -f scripts/e2e.sh ] && bash scripts/e2e.sh >/dev/null 2>&1; then
    echo "GATE: green (scripts/e2e.sh exit 0)"
  else
    echo "GATE: red or missing — run: bash scripts/e2e.sh"
  fi
fi
