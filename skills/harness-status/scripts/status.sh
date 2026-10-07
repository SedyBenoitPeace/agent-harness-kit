#!/usr/bin/env bash
# harness-status: read-only "where am I?" report for a harnessed repo.
# Usage: status.sh [--run-gate] [--skip FILE] [TARGET_DIR]    (default: current directory)
# --skip FILE: one feature id per line; NEXT excludes those ids, their
# transitive dependents, and dependency-less features that follow them.
# Waiting on a human (M29-002): a deferred feature whose notes start with
# "Needs a human:" is listed with its question; failing features whose
# depends_on reaches one are HELD and never selected, in both modes.
# Exit codes: 0 report printed; 2 harness file broken; 3 harness not initialized.
set -euo pipefail

RUN_GATE=0
SKIP_FILE=""
TARGET="."
while [ $# -gt 0 ]; do
  case "$1" in
    --run-gate) RUN_GATE=1 ;;
    --skip) SKIP_FILE="${2:?--skip needs a file}"; shift ;;
    *) TARGET="$1" ;;
  esac
  shift
done
[ -z "$SKIP_FILE" ] || SKIP_FILE="$(cd "$(dirname "$SKIP_FILE")" && pwd)/$(basename "$SKIP_FILE")"
cd "$TARGET"

if [ ! -f FEATURES.json ] || [ ! -f PROGRESS.md ]; then
  echo "HARNESS NOT INITIALIZED: FEATURES.json and/or PROGRESS.md missing."
  echo "Scaffold it with the harness-initial-setup skill (or harness-protocol-planning.md)."
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
  | "passing \([.[] | select(.status == "passing")] | length), failing \([.[] | select(.status == "failing")] | length), deferred \([.[] | select(.status == "deferred")] | length), superseded \([.[] | select(.status == "superseded")] | length)\([.[] | select(.status == "review")] | length | if . > 0 then ", review \(.)" else "" end)"
' FEATURES.json

jq -r '[.features[] | select(.status == "review") | .id] | if length > 0 then "\n== Awaiting evaluator ==\nREVIEW: \(join(" "))" else empty end' FEATURES.json

# held: failing id -> the id it waits on, through depends_on, transitively
# shellcheck disable=SC2016 # jq program: $w, $cur are jq variables
HELD_DEF='def held: ([.features[] | select(.status == "deferred" and ((.notes // "") | tostring | startswith("Needs a human:"))) | .id]) as $w
  | [.features[] | select(.status == "failing")] as $hf
  | def hstep: . as $cur | reduce $hf[] as $x ($cur;
      if has($x.id) then .
      else (($x.depends_on // []) | if type == "array" then . else [] end
            | map(select(. as $d | $cur | has($d))) | first) as $hit
        | if $hit then .[$x.id] = $hit else . end
      end);
    ($w | map({key: ., value: ""}) | from_entries | until(. == hstep; hstep))
    | with_entries(select(.value != "")); '
jq -r "$HELD_DEF"'
  held as $h
  | [.features[] | select(.status == "deferred" and ((.notes // "") | tostring | startswith("Needs a human:")))] as $w
  | if ($w | length) == 0 then empty else
      "\n== Waiting on a human ==",
      ($w[] | "WAITING ON HUMAN: \(.id) — \(.notes | sub("^Needs a human: *"; ""))"),
      ($h | to_entries[] | "HELD: \(.key) — depends on \(.value)")
    end
' FEATURES.json

echo
echo "== Next feature (lowest milestone, then lowest id, among failing) =="
# Optional effort hint (low|medium|high|max): one indented line under NEXT.
# paths (M29-003): where the feature works, so a builder starts reading there.
EFFORT_DEF='def effort_line: (if (.effort | type) == "string" and .effort != "" then "\n  effort: \(.effort)" else "" end)
  + (if (.paths | type) == "array" and (.paths | length) > 0 then "\n  paths: \(.paths | join(", "))" else "" end); '

if [ -z "$SKIP_FILE" ]; then
jq -r "$EFFORT_DEF$HELD_DEF"'
  held as $h
  | [.features[] | select(.status == "failing") | select(.id as $i | $h | has($i) | not)] | sort_by(.milestone, .id)
  | if length == 0
    then "NEXT: none — nothing failing; plan new work (harness-protocol-planning.md) or run a maintenance pass (harness-protocol-maintenance.md)"
    else "NEXT: \(.[0].id) — \(.[0].title)\n  verify: \(.[0].verify)\(.[0] | effort_line)"
    end
' FEATURES.json
else
# Excluded = listed ids, features depending (depends_on) on an excluded id,
# and features without depends_on that follow an excluded one (they are
# assumed to depend on everything before them). Iterated to a fixpoint.
jq -r --rawfile skip "$SKIP_FILE" "$EFFORT_DEF$HELD_DEF"'
  held as $h
  | ($skip | split("\n") | map(select(length > 0))) as $s
  | ([.features[] | select(.status == "failing") | select(.id as $i | $h | has($i) | not)] | sort_by(.milestone, .id)) as $f
  | def step: . as $ex | reduce range(0; $f | length) as $i ($ex;
      $f[$i] as $x | . as $cur
      | if has($x.id) then .
        elif ($s | index($x.id)) != null then .[$x.id] = "listed"
        else
          ((if ($x.depends_on | type) == "array" then $x.depends_on else [$f[:$i][].id] end)
            | map(select(. as $d | $cur | has($d))) | first // null) as $hit
          | if $hit then .[$x.id] = "depends on \($hit)" else . end
        end);
    ({} | until(. == step; step)) as $ex
  | ($f | map(select(.id as $i | $ex | has($i)))[] | "SKIPPED: \(.id) — \($ex[.id])"),
    ([$f[] | select(.id as $i | $ex | has($i) | not)] as $el
     | if ($el | length) == 0
       then "NEXT: none — nothing eligible: every failing feature is skipped or depends on a skipped one"
       else "NEXT: \($el[0].id) — \($el[0].title)\n  verify: \($el[0].verify)\($el[0] | effort_line)"
       end)
' FEATURES.json
fi

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
