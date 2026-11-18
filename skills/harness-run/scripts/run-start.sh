#!/usr/bin/env bash
# harness-run: give a continuous run clean run state. No model calls.
# Ignores .harness-run/ (committing .gitignore alone), archives the previous
# run's logs under .harness-run/previous/<its run-id>/ (<its start commit>/
# for a run without a run-id; kept, never deleted), then writes a fresh
# start, run-id (<epoch>-<pid>), an empty skip and busy, no STOP and no
# board-opened, logs `run-start - <commit>` to events.log and opens the run
# board once (M47-001).
# Usage: run-start.sh <target>
# Prints only `BOARD: <path to board.html>` (from board.sh --open).
set -euo pipefail
t="${1:-}"; [ -d "$t" ] || { echo "usage: run-start.sh <target>" >&2; exit 2; }
here="$(cd "$(dirname "$0")" && pwd)"
cd "$t"
if ! git check-ignore -q .harness-run; then
  echo ".harness-run/" >> .gitignore
  git add .gitignore && git commit -q -m "harness-run: ignore run state" -- .gitignore
fi
d=.harness-run; mkdir -p "$d"
if [ -s "$d/start" ]; then
  if [ -s "$d/run-id" ]; then p="$d/previous/$(cat "$d/run-id")"; else p="$d/previous/$(cat "$d/start")"; fi
  for f in cost.log run-cost models.log usage.log budget.log decisions results events.log; do
    [ -e "$d/$f" ] || continue
    mkdir -p "$p"; mv "$d/$f" "$p/"
  done
fi
git rev-parse HEAD > "$d/start"
echo "$(date +%s)-$$" > "$d/run-id"
: > "$d/skip"
: > "$d/busy"
rm -f "$d/STOP" "$d/board-opened"
echo "$(date +%s) run-start - $(cat "$d/start")" > "$d/events.log"
{ bash "$here/board.sh" . --open 2>/dev/null || true; } | grep '^BOARD: ' || true
