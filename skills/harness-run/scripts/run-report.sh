#!/usr/bin/env bash
# harness-run: script-built report for a finished (or stopped) run. Built only
# from git, FEATURES.json, the skip file and the stop reason: no network, no
# model calls. The file name and every timestamp come from the repo (HEAD's
# commit date), so a fixed repo state always yields identical output.
# Usage: run-report.sh <start-commit> [--skip FILE] [--stop-reason TEXT]
# Writes docs/runs/<YYYY-MM-DD-HHMM>.md and prints its path.
# Exit codes: 0 written; 2 usage error / not a harnessed git repo.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
STATUS="$SCRIPT_DIR/../../harness-status/scripts/status.sh"

START_REF="${1:-}"
[ -n "$START_REF" ] || { echo "usage: run-report.sh <start-commit> [--skip FILE] [--stop-reason TEXT]" >&2; exit 2; }
shift
SKIP_FILE=/dev/null
REASON="not given"
while [ $# -gt 0 ]; do
  case "$1" in
    --skip) SKIP_FILE="${2:?--skip needs a file}"; shift ;;
    --stop-reason) REASON="${2:?--stop-reason needs text}"; shift ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
  shift
done
[ -r "$SKIP_FILE" ] || SKIP_FILE=/dev/null
SKIP_FILE="$(cd "$(dirname "$SKIP_FILE")" && pwd)/$(basename "$SKIP_FILE")"

command -v jq >/dev/null || { echo "ERROR: jq is required" >&2; exit 2; }
START="$(git rev-parse --verify -q "$START_REF^{commit}")" \
  || { echo "unknown start commit: $START_REF" >&2; exit 2; }
cd "$(git rev-parse --show-toplevel)"
[ -f FEATURES.json ] || { echo "no FEATURES.json here" >&2; exit 2; }

fmt='%Y-%m-%d %H:%M'
stamp="$(git log -1 --format=%cd --date=format:%Y-%m-%d-%H%M HEAD)"
out="docs/runs/$stamp.md"
mkdir -p docs/runs

title() { jq -r --arg id "$1" '.features[] | select(.id == $id) | .title' FEATURES.json; }
status_of() { jq -r --arg id "$1" '.features[] | select(.id == $id) | .status' FEATURES.json; }

# ids done: the newest non-skip commit since start naming a passing/review feature
done_lines=""
while IFS=$'\t' read -r hash subject; do
  case "$subject" in "harness-run: skip"*) continue ;; esac
  while IFS= read -r id; do
    if printf '%s' "$subject" | grep -qwF -- "$id"; then
      done_lines="$done_lines$id	$hash
"
    fi
  done < <(jq -r '.features[].id' FEATURES.json)
done < <(git log --reverse --format='%h%x09%s' "$START..HEAD")
done_lines="$(printf '%s' "$done_lines" | awk -F'\t' 'NF { h[$1] = $2; if (!($1 in s)) { s[$1] = 1; ord[++n] = $1 } } END { for (i = 1; i <= n; i++) print ord[i] "\t" h[ord[i]] }')"

# The newest PROGRESS.md entry naming <id> that has a Decisions: line, as one
# line (wrapped continuation lines joined) — M27-003
decisions_of() {
  [ -f PROGRESS.md ] || return 0
  awk -v id="$1" '
    /^## / { if (hit && dec != "") { print dec; exit } hit = index($0, id) > 0; indec = 0; dec = ""; next }
    index($0, id) > 0 { hit = 1 }
    /^- Decisions:/ { indec = 1; dec = $0; next }
    indec && /^  [^ -]/ { sub(/^ +/, ""); dec = dec " " $0; next }
    { indec = 0 }
    END { if (hit && dec != "") print dec }
  ' PROGRESS.md | head -1 | sed 's/^- //'
}

done_out=""; n_done=0
while IFS=$'\t' read -r id hash; do
  [ -n "$id" ] || continue
  st="$(status_of "$id")"
  case "$st" in
    passing) done_out="$done_out- $id — $(title "$id") — $hash
" ;;
    review) done_out="$done_out- $id — $(title "$id") — $hash (review: awaiting the evaluator)
" ;;
    *) continue ;;
  esac
  dec="$(decisions_of "$id")"
  [ -z "$dec" ] || done_out="$done_out  - $dec
"
  n_done=$((n_done + 1))
done <<< "$done_lines"

# Supervisor (M25-002) and budget guard (M25-003) signals, when a run left them
supervisor_out=""
for f in .harness-run/decisions/*.skipped.md; do
  [ -f "$f" ] || continue
  id="$(basename "$f" .skipped.md)"
  items="$(sed -n 's/^- //p' "$f" | paste -sd ';' - | sed 's/;/; /g')"
  [ -n "$items" ] && supervisor_out="$supervisor_out- $id — $(title "$id"): $items
"
done
budget_out=""
[ -s .harness-run/budget.log ] && budget_out="$(sed 's/^/- /' .harness-run/budget.log)
"

# skipped: the skip file, with reason and question parsed from the notes
skipped_out=""; n_skipped=0
while IFS= read -r id; do
  [ -n "$id" ] || continue
  note="$(jq -r --arg id "$id" '.features[] | select(.id == $id) | .notes // ""' FEATURES.json)"
  reason="$(printf '%s' "$note" | sed -n 's/.*skipped — \(.*\)\. Question for the human: .*/\1/p')"
  question="$(printf '%s' "$note" | sed -n 's/.*Question for the human: //p')"
  stash="$(git stash list --format='%gd %s' | sed -n "s/^\\(stash@{[0-9]*}\\) .*harness-run skip $id\$/\\1/p" | head -1)"
  skipped_out="$skipped_out- $id — $(title "$id") — reason: ${reason:-no note recorded} — question: ${question:-none recorded}${stash:+ — stash: $stash}
"
  n_skipped=$((n_skipped + 1))
done < "$SKIP_FILE"

# not started: failing features that were neither done nor skipped
deps="$(bash "$STATUS" --skip "$SKIP_FILE" . | sed -n 's/^SKIPPED: \([^ ]*\) — depends on \(.*\)$/\1 \2/p')"
notstarted_out=""; n_not=0
while IFS= read -r id; do
  [ -n "$id" ] || continue
  grep -qxF -- "$id" "$SKIP_FILE" && continue
  on="$(printf '%s\n' "$deps" | sed -n "s/^$id \\(.*\\)\$/\\1/p")"
  why="not reached — $REASON"
  [ -z "$on" ] || why="depends on $on"
  notstarted_out="$notstarted_out- $id — $(title "$id") — $why
"
  n_not=$((n_not + 1))
done < <(jq -r '[.features[] | select(.status == "failing")] | sort_by(.milestone, .id) | .[].id' FEATURES.json)

branch="$(git branch --show-current)"
branches_out=""
while IFS= read -r b; do
  tip="$(git rev-parse "refs/heads/$b")"
  git merge-base --is-ancestor "$START" "$tip" || continue
  git merge-base --is-ancestor "$tip" HEAD || continue
  if [ "$b" = "$branch" ]; then branches_out="$branches_out- $b (current)
"; elif [ "$tip" != "$START" ]; then branches_out="$branches_out- $b
"; fi
done < <(git for-each-ref refs/heads --format='%(refname:short)')
[ -n "$branches_out" ] || branches_out="- ${branch:-detached HEAD} (current)
"

list() { if [ -n "$1" ]; then printf '%s' "$1"; else echo "- none"; fi; }
{
  echo "# Run report $stamp"
  echo
  echo "## Summary"
  echo
  echo "- Start: $(git log -1 --format="%h (%cd)" --date=format:"$fmt" "$START")"
  echo "- End: $(git log -1 --format="%h (%cd)" --date=format:"$fmt" HEAD)"
  echo "- Stop reason: $REASON"
  echo "- Counts: done $n_done · skipped $n_skipped · not started $n_not"
  echo
  echo "## Done"
  echo
  list "$done_out"
  echo
  echo "## Skipped"
  echo
  list "$skipped_out"
  echo
  echo "## Not started"
  echo
  list "$notstarted_out"
  if [ -n "$supervisor_out" ]; then
    echo
    echo "## Supervisor"
    echo
    echo "Work the done-check supervisor thinks a session skipped:"
    echo
    printf '%s' "$supervisor_out"
  fi
  if [ -n "$budget_out" ]; then
    echo
    echo "## Budget"
    echo
    printf '%s' "$budget_out"
  fi
  echo
  echo "## Branches"
  echo
  list "$branches_out"
} > "$out"
echo "$out"
