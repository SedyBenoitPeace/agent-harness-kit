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
