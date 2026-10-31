#!/usr/bin/env bash
# harness-brief: counts review rounds in the brief itself (M42-001), so the
# cap holds however the reviewer runs (subagent or a separate CLI process).
# Usage: review-round.sh BRIEF.md          before every reviewer dispatch
#        review-round.sh --ready BRIEF.md  after a READY verdict
# The count is line 2 of the brief: <!-- Review rounds: N[, READY] -->.
# Exits 3 with a STOP line instead of starting round 3. To allow a fresh
# review after the human has revised the brief, the human deletes that line.
set -euo pipefail

ready=0
[ "${1:-}" = --ready ] && { ready=1; shift; }
brief="${1:?usage: review-round.sh [--ready] BRIEF.md}"
[ -f "$brief" ] || { echo "review-round: $brief not found" >&2; exit 2; }
max=2

n="$(sed -n 's/^<!-- Review rounds: \([0-9][0-9]*\).*-->$/\1/p' "$brief" | head -1)"
n="${n:-0}"

if [ "$ready" -eq 1 ]; then
  next="<!-- Review rounds: $n, READY -->"
elif grep -q '^<!-- Review rounds: [0-9]*, READY -->$' "$brief"; then
  echo "STOP: brief is already READY, hand it off to planning"
  exit 3
elif [ $((n + 1)) -gt "$max" ]; then
  echo "STOP: round cap reached, show remaining gaps to the human"
  exit 3
else
  n=$((n + 1)); next="<!-- Review rounds: $n -->"
fi

tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT
# drop any old counter, then put the new one on line 2 (under the title)
grep -v '^<!-- Review rounds: .*-->$' "$brief" \
  | awk -v c="$next" 'NR == 1 { print; print c; next } { print }' > "$tmp"
cat "$tmp" > "$brief"
echo "review-round: ${next#<!-- }" | sed 's/ -->$//' 
