#!/usr/bin/env bash
# harness-session: bounded, read-only "what do I need to start?" report.
# Bundles harness-status's report with the git/plan facts a coding session
# also needs, so an agent can start from one call instead of several.
# Usage: context.sh [--skip FILE] [--busy FILE] [--through N] [--unattended] [--brief] [--outline FILE] [TARGET_DIR]
#        (TARGET_DIR defaults to the current directory)
# --skip FILE is passed to harness-status (see status.sh) so NEXT, PLAN and
# PARALLEL all follow the first feature that is not skipped.
# --brief is for a session dispatched with a brief (harness-run pasted the
# feature entry and plan section): the plan section is not repeated, and a
# == Session protocol == section prints the protocol 2.9 card plus the repo's
# AGENTS.md Rules and Needs-a-human sections, so the session never reads
# SKILL.md, AGENTS.md or the protocol files.
# --busy FILE: ids whose parallel lane is still running (M46-001, rolling
# lanes); PARALLEL then lists only lanes that can start beside them.
# --through N (M61-001): lanes may come from later milestones up to N (the
# run's range); without it, only NEXT's milestone.
# --unattended (M61-004, harness-continuous): a dependency that is deferred
# with notes starting "Needs a human: verify" (built, merged, gate green, only
# a human check left) counts as met for lanes.
# --outline FILE: the task points to an approved plan or outline from another
# workflow (M43-001). Prints its path and a SKIP_BRIEF hint (protocol 1.1);
# a path that does not exist prints "not found" and no hint.
# Exit codes: delegated from harness-status — 0 report printed; 2 harness
# file broken; 3 harness not initialized.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
STATUS="$SCRIPT_DIR/../../harness-status/scripts/status.sh"
SKIP=(); BRIEF=0; OUTLINE=""; BUSY=/dev/null; THROUGH=""; UNATTENDED=0
while [ $# -gt 0 ]; do
  case "$1" in
    --skip) SKIP=(--skip "${2:?--skip needs a file}"); shift 2 ;;
    --busy) BUSY="${2:?--busy needs a file}"; shift 2 ;;
    --through) THROUGH="${2:?--through needs a milestone}"; shift 2 ;;
    --unattended) UNATTENDED=1; shift ;;
    --brief) BRIEF=1; shift ;;
    --outline) OUTLINE="${2:?--outline needs a file}"; shift 2 ;;
    *) break ;;
  esac
done
TARGET="${1:-.}"
# M47-002: refresh the run board last (guarded; never changes output or exit code)
_bt="$(cd "$TARGET" 2>/dev/null && pwd)" || _bt=.; _bs="$SCRIPT_DIR/../../harness-run/scripts/board.sh"
# shellcheck disable=SC2317,SC2329 # runs from the EXIT trap
board() { local r; r="$(cd "$_bt" && cd "$(git rev-parse --git-common-dir 2>/dev/null)/.." 2>/dev/null && pwd)" || return 0
  [ -s "$r/.harness-run/start" ] || return 0
  [ "$(tail -n1 "$r/.harness-run/events.log" 2>/dev/null | cut -d' ' -f2)" != run-end ] || return 0
  bash "$_bs" "$_bt" >/dev/null 2>&1 || true; }
trap board EXIT

# Brief, not history (M34-009): completed milestones collapse to one line.
rc=0; report="$(bash "$STATUS" ${SKIP[@]+"${SKIP[@]}"} "$TARGET")" || rc=$?
if [ "$rc" -ne 0 ]; then printf '%s\n' "$report"; exit "$rc"; fi
printf '%s\n' "$report" | awk '
  function flush() { if (done > 0) print "M" first "-M" last " complete (" done " milestones)"; done = 0; print "" }
  inm && /^$/ { next }
  /^== /{ if (inm) flush(); inm = ($0 == "== Milestones =="); print; next }
  inm && /^M[0-9]+: [0-9]+\/[0-9]+ passing/ {
    split($2, a, "/"); k = substr($1, 2, length($1) - 2)
    if (a[1] == a[2]) { if (done == 0) first = k; last = k; done++; next }
  }
  { print }'
# Bug kind (M59-001): the reported symptom is the spec; never brief it.
if printf '%s\n' "$report" | grep -q '^  kind: bug$'; then
  echo 'SKIP_BRIEF: bug — do not run harness-brief; its checks are the reported symptom'
fi
SKIPPED_IDS=""
if [ ${#SKIP[@]} -gt 0 ]; then
  skip_report="$(bash "$STATUS" "${SKIP[@]}" "$TARGET")"
  SKIPPED_IDS="$(printf '%s\n' "$skip_report" | sed -n 's/^SKIPPED: \([^ ]*\) .*/\1/p')"
fi
# Approved outline (M43-001): checked before cd, so a relative path is the
# caller's. The brief already exists in another form; never brief it again.
if [ -n "$OUTLINE" ]; then
  echo
  echo "== Approved outline =="
  if [ -f "$OUTLINE" ]; then
    echo "OUTLINE: $OUTLINE"
    echo 'SKIP_BRIEF: approved outline — do not run harness-brief or re-plan it; turn it into FEATURES.json entries plus a plan section (protocol 1.1), then go to harness-run'
    echo 'ENTRY_RULE: every entry records depends_on (ids whose code it cannot build or test without; [] for none; preferred order is not a dependency) and paths (the files it changes or the narrowest folder it owns; never a whole src/ or top-level folder); run-start.sh refuses the run otherwise (protocol 1.4)'
  else
    echo "OUTLINE: not found — $OUTLINE"
  fi
fi
cd "$TARGET"

echo
echo "== Recent commits =="
git log -5 --oneline

echo
echo "== Worktree =="
branch="$(git branch --show-current)"
echo "BRANCH: ${branch:-detached}"
status_short="$(git status --short)"
if [ -z "$status_short" ]; then
  echo 'WORKTREE: clean'
else
  echo 'WORKTREE: dirty'
  echo "$status_short"
fi

next_id="$(jq -r --arg ex "$SKIPPED_IDS" '
  [.features[] | select(.status == "failing" and (.id as $i | ($ex | split("\n") | index($i)) == null))]
  | sort_by(.milestone, .id)
  | if length == 0 then "" else .[0].id end
' FEATURES.json)"

if [ -n "$next_id" ]; then
  jq -r --arg id "$next_id" '.features[] | select(.id == $id) | select((.notes // "") != "") | "NEXT_NOTES: \(.notes)"' FEATURES.json
fi

echo
echo "== Active plan references =="
if [ -n "$next_id" ]; then
  matches="$(grep -ril --include='*.md' "$next_id" docs/plans/active 2>/dev/null || true)"
  if [ -n "$matches" ]; then
    printf '%s\n' "$matches" | sed 's/^/PLAN: /'
    if [ "$BRIEF" -eq 1 ]; then
      echo 'PLAN_SECTION: in your brief'
    else
      # the feature's own plan section (heading naming its id), capped at 30 lines
      printf '%s\n' "$matches" | while IFS= read -r pf; do
        awk -v id="$next_id" '/^## /{ on = (index($0, id) > 0) } on' "$pf" | head -30
      done
    fi
  else
    echo "PLAN: none mentioning $next_id"
  fi
else
  echo 'PLAN: none — no failing feature'
fi

if [ -x scripts/preflight.sh ]; then
  echo 'PREFLIGHT: scripts/preflight.sh'
else
  echo 'PREFLIGHT: absent'
fi

# Parallel lanes for harness-run: declared at planning time, never inferred.
# Eligible = failing, in NEXT's milestone (or up to --through N, M61-001),
# declares depends_on (all passing) and non-empty paths. Greedy from NEXT,
# max 5 (max_lanes in FEATURES.json, M61-001), never two with the same optional exclusive value; fewer than 2
# lanes, or NEXT itself ineligible → sequential.
# --busy (M46-001): running lanes keep their files, exclusive value and cap
# slots; then one new lane is enough, and an ineligible NEXT waits. A line
# "<id> ready" (M61-001) is a finished lane waiting for its milestone: it
# keeps its files and exclusive value but frees its slot.
# Overlap (M45-002): only a named file blocks — a file both features list, or one
# inside the other's directory/glob. Two directories never block: disjoint
# files in a shared folder merge cleanly, and a real conflict is caught at
# merge (lane dropped, redone sequentially). Paths listed in the top-level
# shared_paths (M61-001; absent = README.md and CHANGELOG.md, [] = none)
# never block; merge-lane.sh resolves their conflicts.
# Without --brief, each open feature in range that is not a lane prints
# "  not a lane: <id> — <reason>" (at most 6 lines).
# ponytail: a conflicting lane is rebuilt from scratch; resolve-in-lane if that gets common.
# Archived ids (docs/features-archive.json, M34-010) count as passing.
ARCH=docs/features-archive.json; [ -f "$ARCH" ] || ARCH=/dev/null
[ -e "$BUSY" ] || { echo "context: --busy file not found: $BUSY" >&2; exit 2; }
jq -r --arg ex "$SKIPPED_IDS" --arg busy "$(cat "$BUSY")" --arg through "${THROUGH#[Mm]}" --argjson why "$((1 - BRIEF))" --argjson un "$UNATTENDED" --slurpfile arc "$ARCH" '
  def entry: {s: sub("[*?\\[].*$"; ""), d: (test("[*?\\[]") or endswith("/"))};
  def hit($x; $y): ($x.d and $y.d | not) and (($x.s | startswith($y.s)) or ($y.s | startswith($x.s)));
  def clash($a; $b): first($a[] as $x | $b[] as $y | select(hit($x; $y)) | if $x.d then $y.s else $x.s end) // null;
  (.max_lanes // 5 | if type == "number" and . >= 1 then floor else 5 end) as $cap
  | (.shared_paths // ["README.md", "CHANGELOG.md"]) as $shared
  | def ents: (.paths // []) | map(select(. as $p | $shared | index([$p]) | not)) | map(entry);
  ([$arc[].features[]?, .features[]] | map({key: .id, value: (if $un == 1 and .status == "deferred" and ((.notes // "") | startswith("Needs a human: verify")) then "passing" else .status end)}) | from_entries) as $st
  | ([.features[] | select(.status == "failing" and (.id as $i | ($ex | split("\n") | index($i)) == null))]
      | sort_by(.milestone, .id)) as $f
  | if ($f | length) == 0 then "PARALLEL: none" else
      ($f[0].milestone) as $m0
      | (($through | tonumber? // $m0) | if . < $m0 then $m0 else . end) as $mx
      | def why: if .milestone > $mx then "milestone \(.milestone) is outside this run (--through)"
          elif (.depends_on | type) != "array" then "no depends_on"
          elif (.paths | type) != "array" or (.paths | length) == 0 then "no paths"
          else ([.depends_on[] | select($st[.] != "passing")]) as $d
            | if $d != [] then "depends on \($d | map("\(.) (\($st[.] // "missing"))") | join(", "))" else null end end;
      [ $f[] | select(why == null) ] as $el
      | ($busy | split("\n") | map(select(length > 0) | split(" ") | {id: .[0], ready: (.[1] == "ready")})) as $b
      | ($b | map(.id)) as $bid
      | ([ $f[] | .id as $i | ($b[] | select(.id == $i)) as $bb | {id, p: ents, x: (.exclusive // null), busy: true, ready: $bb.ready} ]) as $seed
      | (if ($b | length) == 0 and (($el | length) == 0 or $el[0].id != $f[0].id) then {l: $seed, r: {}, seq: true}
         else reduce ($el[] | select(.id as $i | $bid | index($i) | not)) as $e ({l: $seed, r: {}, seq: false};
            ($e | ents) as $p | ($e.exclusive // null) as $x
            | ([.l[] | {id, c: clash(.p; $p)} | select(.c != null)] | first) as $c
            | ([.l[] | select($x != null and .x == $x) | .id] | first) as $xc
            | if $c != null then .r[$e.id] = "shares \($c.c) with \($c.id)"
              elif $xc != null then .r[$e.id] = "exclusive \($x) with \($xc)"
              elif ([.l[] | select(.ready | not)] | length) >= $cap then .r[$e.id] = "cap of \($cap) lanes reached"
              else .l += [{id: $e.id, p: $p, x: $x, ready: false}] end) end) as $res
      | ([$res.l[] | select(.busy | not)]) as $new
      | ($new | length) as $nn
      | (if $res.seq | not and $nn >= (if ($b | length) > 0 then 1 else 2 end) then "PARALLEL: " + ($new | map(.id) | join(" ")) else "PARALLEL: none" end),
        (if $why == 1 then
          [ $f[] | . as $g | select(($bid | index($g.id) | not) and (if ($nn >= (if ($b | length) > 0 then 1 else 2 end)) and ($res.seq | not) then ($new | map(.id) | index($g.id) | not) else true end))
            | (why // $res.r[.id] // (if $res.seq and .id != $f[0].id then "NEXT \($f[0].id) is not a lane (\($f[0] | why // "nothing to pair with")), so the run is sequential" elif .id == $f[0].id and ($nn < 2) then null else null end)) as $w
            | select($w != null) | "  not a lane: \(.id) — \($w)" ] | .[:6][]
         else empty end)
    end
' FEATURES.json

# Run readiness (M65-001): the entry check run-start.sh enforces, shown up
# front so a planner fixes entries before a run is refused. Not for a
# dispatched builder (--brief): its run already passed it.
entries=""
if [ "$BRIEF" -eq 0 ]; then
  echo
  echo "== Run readiness =="
  entries="$(bash "$SCRIPT_DIR/../../harness-run/scripts/check-entries.sh" . 2>&1 || true)"
  printf '%s\n' "$entries"
fi

# Harness-upgrade notices: the plugin ships newer templates than the ones
# a repo was scaffolded with. Report the two that matter as facts; the
# skill decides what to offer.
echo
echo "== Harness upgrade =="
upgrade=0
if [ ! -f scripts/e2e.sh ]; then
  echo 'GATE_OUTPUT: no scripts/e2e.sh'
elif grep -q 'FULL_LOG' scripts/e2e.sh; then
  echo 'GATE_OUTPUT: bounded'
else
  echo 'GATE_OUTPUT: unbounded — scripts/e2e.sh has no step wrapper (protocol §1.6, ~5 min retrofit)'
  upgrade=1
fi
SHIPPED_PROTOCOL="$SCRIPT_DIR/../../harness-initial-setup/templates/harness-protocol.md"
PLUGIN_JSON="$SCRIPT_DIR/../../../.claude-plugin/plugin.json"
plugin_version="$(jq -r '.version // "unknown"' "$PLUGIN_JSON" 2>/dev/null || echo unknown)"
stale=""
for f in harness-protocol.md harness-protocol-planning.md harness-protocol-runs.md harness-protocol-maintenance.md; do
  cmp -s "$(dirname "$SHIPPED_PROTOCOL")/$f" "docs/agents/$f" 2>/dev/null || stale="$stale docs/agents/$f"
done
if printf '%s\n' "$entries" | grep -q '^KIT: stale'; then
  echo "PROTOCOL: not compared — plugin $plugin_version is older than this repo's kit (KIT: stale above)"
elif [ ! -f docs/agents/harness-protocol.md ]; then
  echo 'PROTOCOL: missing'
elif [ -z "$stale" ]; then
  echo "PROTOCOL: current (plugin $plugin_version)"
else
  echo "PROTOCOL: outdated —$stale missing or different from the copies shipped with plugin $plugin_version"
  upgrade=1
fi
if [ "$upgrade" -eq 1 ]; then
  echo 'UPGRADE: offer — tell the human once; apply only if they say so, as its own commit before the feature'
else
  echo 'UPGRADE: none'
fi

# Briefed sessions (M38-001): the protocol lines a dispatched session needs,
# so it never cats SKILL.md, AGENTS.md or docs/agents/. The card is the
# shipped protocol 2.9; the repo's own rules come from its AGENTS.md.
if [ "$BRIEF" -eq 1 ]; then
  echo
  echo "== Session protocol =="
  echo "SCRIPTS: $SCRIPT_DIR"
  RUNS="$SCRIPT_DIR/../../harness-initial-setup/templates/harness-protocol-runs.md"
  # the card's bullets only (its intro is for readers of the protocol file)
  awk '/^### 2\.9 /{ on = 1; next } on && /^#/{ exit } on && /^- /{ b = 1 } b' "$RUNS"
  if [ -f AGENTS.md ]; then
    for sec in Rules 'Needs a human'; do
      part="$(awk -v h="## $sec" '$0 == h { on = 1; print; next } on && /^## /{ exit } on' AGENTS.md | head -40)"
      if [ -n "$part" ]; then printf '\n%s\n' "$part"; fi
    done
  fi
fi
