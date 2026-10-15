#!/usr/bin/env bash
# harness-run: give a continuous run clean run state. No model calls.
# Ignores .harness-run/ (committing .gitignore alone), archives the previous
# run's logs under .harness-run/previous/<its start commit>/ (kept, never
# deleted), then writes a fresh start, an empty skip and no STOP.
# Usage: run-start.sh <target>
set -euo pipefail
t="${1:-}"; [ -d "$t" ] || { echo "usage: run-start.sh <target>" >&2; exit 2; }
cd "$t"
if ! git check-ignore -q .harness-run; then
  echo ".harness-run/" >> .gitignore
  git add .gitignore && git commit -q -m "harness-run: ignore run state" -- .gitignore
fi
d=.harness-run; mkdir -p "$d"
if [ -s "$d/start" ]; then
  p="$d/previous/$(cat "$d/start")"
  for f in cost.log run-cost models.log usage.log budget.log decisions results; do
    [ -e "$d/$f" ] || continue
    mkdir -p "$p"; mv "$d/$f" "$p/"
  done
fi
git rev-parse HEAD > "$d/start"
: > "$d/skip"
rm -f "$d/STOP"
