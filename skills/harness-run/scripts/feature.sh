#!/usr/bin/env bash
# harness-run: the brief for one feature (M38-002). Prints its FEATURES.json
# entry and its plan section, so the orchestrator pastes them into the
# builder's prompt instead of handing it the plan path: the builder then
# never reads FEATURES.json or the plan itself.
# Usage: feature.sh <id> [TARGET_DIR]    (default: current directory)
# Plan section = the `## ` heading in docs/plans/active/*.md naming the id, up
# to the next `## `, capped at 80 lines. Exit 2 = usage error or unknown id.
set -euo pipefail
id="${1:-}"
[ -n "$id" ] || { echo "usage: feature.sh <id> [target]" >&2; exit 2; }
cd "${2:-.}"
command -v jq >/dev/null || { echo "ERROR: jq is required" >&2; exit 2; }
[ -f FEATURES.json ] || { echo "feature: no FEATURES.json here" >&2; exit 2; }
entry="$(jq --arg i "$id" '[.features[] | select(.id == $i)][0] // empty' FEATURES.json)"
[ -n "$entry" ] || { echo "feature: no feature $id in FEATURES.json" >&2; exit 2; }

echo "== Feature $id =="
printf '%s\n' "$entry"
echo
echo "== Plan section =="
found=0
for pf in docs/plans/active/*.md; do
  [ -f "$pf" ] || continue
  section="$(awk -v id="$id" '/^## /{ on = (index($0, id) > 0) } on' "$pf")"
  [ -n "$section" ] || continue
  found=1
  echo "PLAN: $pf"
  printf '%s\n' "$section" | head -80
  n="$(printf '%s\n' "$section" | wc -l | tr -d ' ')"
  [ "$n" -le 80 ] || echo "(section cut at 80 of $n lines: sed -n the rest from $pf)"
done
[ "$found" -eq 1 ] || echo "PLAN: no section naming $id in docs/plans/active/"
