#!/usr/bin/env bash
# harness-run: give a continuous run clean run state. No model calls.
# Ignores .harness-run/ (committing .gitignore alone), archives the previous
# run's logs under .harness-run/previous/<its run-id>/ (<its start commit>/
# for a run without a run-id; kept, never deleted), then writes a fresh
# start, run-id (<epoch>-<pid>), an empty skip and busy, no STOP and no
# board-opened, logs `run-start - <commit>` to events.log and opens the run
# board once (M47-001).
# First (M65-001) it runs check-entries.sh: open features missing
# depends_on/paths or claiming a whole top-level folder, or kit scripts older
# than the repo's recorded kit version, refuse the run (exit 1, its lines
# printed, no run state written).
# --providers a,b,c (M69-004): the host can run builders on these providers
# (T3 Code: orchestrator_capabilities, in the host's order). Written to
# .harness-run/providers; with 2+, dispatch.sh assigns each builder the next
# one (VIA:). Without it, builders are the named agents.
# Usage: run-start.sh <target> [--providers a,b,c]
# Prints `BOARD: <path to board.html>` (from board.sh --open), and
# `PROVIDERS: a b c` when given.
set -euo pipefail
t="${1:-}"; [ -d "$t" ] || { echo "usage: run-start.sh <target> [--providers a,b,c]" >&2; exit 2; }
provs=""
if [ "${2:-}" = --providers ]; then
  case "${3:-}" in '' | *[!A-Za-z0-9._,-]*) echo "run-start: --providers needs a comma list, e.g. codex,claude" >&2; exit 2 ;; esac
  provs="$3"
elif [ -n "${2:-}" ]; then echo "usage: run-start.sh <target> [--providers a,b,c]" >&2; exit 2; fi
here="$(cd "$(dirname "$0")" && pwd)"
cd "$t"
chk="$(bash "$here/check-entries.sh" .)" || { printf '%s\n' "$chk"; exit 1; }
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
rm -f "$d/STOP" "$d/board-opened" "$d/provider-last"
if [ -n "$provs" ]; then tr ',' '\n' <<<"$provs" | grep . > "$d/providers"; else rm -f "$d/providers"; fi
echo "$(date +%s) run-start - $(cat "$d/start")" > "$d/events.log"
{ bash "$here/board.sh" . --open 2>/dev/null || true; } | grep '^BOARD: ' || true
[ ! -s "$d/providers" ] || echo "PROVIDERS: $(tr '\n' ' ' < "$d/providers" | sed 's/ $//')"
