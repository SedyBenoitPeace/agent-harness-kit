#!/usr/bin/env bash
# harness-session: bounded, read-only "what do I need to start?" report.
# Bundles harness-status's report with the git/plan facts a coding session
# also needs, so an agent can start from one call instead of several.
# Usage: context.sh [TARGET_DIR]    (default: current directory)
# Exit codes: delegated from harness-status — 0 report printed; 2 harness
# file broken; 3 harness not initialized.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
STATUS="$SCRIPT_DIR/../../harness-status/scripts/status.sh"
TARGET="${1:-.}"

bash "$STATUS" "$TARGET"
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

next_id="$(jq -r '
  [.features[] | select(.status == "failing")] | sort_by(.milestone, .id)
  | if length == 0 then "" else .[0].id end
' FEATURES.json)"

echo
echo "== Active plan references =="
if [ -n "$next_id" ]; then
  matches="$(grep -ril --include='*.md' "$next_id" docs/plans/active 2>/dev/null || true)"
  if [ -n "$matches" ]; then
    printf '%s\n' "$matches" | sed 's/^/PLAN: /'
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
# max 3; fewer than 2 lanes, or NEXT itself ineligible → sequential.
jq -r '
  def prefix: sub("[*?\\[].*$"; "");
  def overlaps($a; $b): any($a[]; . as $x | any($b[]; . as $y
    | ($x | startswith($y)) or ($y | startswith($x))));
  (.features | map({key: .id, value: .status}) | from_entries) as $st
  | ([.features[] | select(.status == "failing")] | sort_by(.milestone, .id)) as $f
  | if ($f | length) == 0 then "PARALLEL: none" else
      [ $f[] | select(.milestone == $f[0].milestone
          and (.depends_on | type) == "array" and all(.depends_on[]; $st[.] == "passing")
          and (.paths | type) == "array" and (.paths | length) > 0) ] as $el
      | if ($el | length) == 0 or $el[0].id != $f[0].id then "PARALLEL: none" else
          reduce $el[] as $e ([];
            ($e.paths | map(prefix)) as $p
            | if length < 3 and all(.[]; overlaps(.p; $p) | not)
              then . + [{id: $e.id, p: $p}] else . end)
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
SHIPPED_PROTOCOL="$SCRIPT_DIR/../../harness-setup/templates/harness-protocol.md"
PLUGIN_JSON="$SCRIPT_DIR/../../../.claude-plugin/plugin.json"
plugin_version="$(jq -r '.version // "unknown"' "$PLUGIN_JSON" 2>/dev/null || echo unknown)"
if [ ! -f docs/agents/harness-protocol.md ]; then
  echo 'PROTOCOL: missing'
elif cmp -s "$SHIPPED_PROTOCOL" docs/agents/harness-protocol.md; then
  echo "PROTOCOL: current (plugin $plugin_version)"
else
  echo "PROTOCOL: outdated — docs/agents/harness-protocol.md differs from the copy shipped with plugin $plugin_version"
  upgrade=1
fi
if [ "$upgrade" -eq 1 ]; then
  echo 'UPGRADE: offer — tell the human once; apply only if they say so, as its own commit before the feature'
else
  echo 'UPGRADE: none'
fi
