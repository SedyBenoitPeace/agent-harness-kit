#!/usr/bin/env bash
# harness-session: bounded, read-only "what do I need to start?" report.
# Bundles harness-status's report with the git/plan facts a coding session
# also needs, so an agent can start from one call instead of several.
# Usage: context.sh [--skip FILE] [TARGET_DIR]    (default: current directory)
# --skip FILE is passed to harness-status (see status.sh) so NEXT, PLAN and
# PARALLEL all follow the first feature that is not skipped.
# Exit codes: delegated from harness-status — 0 report printed; 2 harness
# file broken; 3 harness not initialized.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
STATUS="$SCRIPT_DIR/../../harness-status/scripts/status.sh"
SKIP=()
if [ "${1:-}" = "--skip" ]; then SKIP=(--skip "${2:?--skip needs a file}"); shift 2; fi
TARGET="${1:-.}"

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
SKIPPED_IDS=""
if [ ${#SKIP[@]} -gt 0 ]; then
  skip_report="$(bash "$STATUS" "${SKIP[@]}" "$TARGET")"
  SKIPPED_IDS="$(printf '%s\n' "$skip_report" | sed -n 's/^SKIPPED: \([^ ]*\) .*/\1/p')"
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
    # the feature's own plan section (heading naming its id), capped at 30 lines
    printf '%s\n' "$matches" | while IFS= read -r pf; do
      awk -v id="$next_id" '/^## /{ on = (index($0, id) > 0) } on' "$pf" | head -30
    done
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
# Eligible = failing, in NEXT's milestone, declares depends_on (all passing)
# and non-empty paths. Greedy from NEXT over non-overlapping glob prefixes,
# max 3, never two with the same optional exclusive value; fewer than 2 lanes, or NEXT itself ineligible → sequential.
jq -r --arg ex "$SKIPPED_IDS" '
  def prefix: sub("[*?\\[].*$"; "");
  def overlaps($a; $b): any($a[]; . as $x | any($b[]; . as $y
    | ($x | startswith($y)) or ($y | startswith($x))));
  (.features | map({key: .id, value: .status}) | from_entries) as $st
  | ([.features[] | select(.status == "failing" and (.id as $i | ($ex | split("\n") | index($i)) == null))]
      | sort_by(.milestone, .id)) as $f
  | if ($f | length) == 0 then "PARALLEL: none" else
      [ $f[] | select(.milestone == $f[0].milestone
          and (.depends_on | type) == "array" and all(.depends_on[]; $st[.] == "passing")
          and (.paths | type) == "array" and (.paths | length) > 0) ] as $el
      | if ($el | length) == 0 or $el[0].id != $f[0].id then "PARALLEL: none" else
          reduce $el[] as $e ([];
            ($e.paths | map(prefix)) as $p
            | ($e.exclusive // null) as $x
            | if length < 3 and all(.[]; overlaps(.p; $p) | not)
                and ($x == null or all(.[]; .x != $x))
              then . + [{id: $e.id, p: $p, x: $x}] else . end)
          | if length >= 2 then "PARALLEL: " + (map(.id) | join(" ")) else "PARALLEL: none" end
        end
    end
' FEATURES.json

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
if [ ! -f docs/agents/harness-protocol.md ]; then
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
