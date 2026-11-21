#!/usr/bin/env bash
# Proves retro-facts.sh (M60-001) against scripts/fixtures/retro/, a finished
# run: report, PROGRESS.md, .harness-run/events.log and quiet.sh logs.
# Each t "<check id> …" line is the one test for that check (check-coverage.sh).
set -euo pipefail
cd "$(dirname "$0")/.."
RF="skills/harness-retro/scripts/retro-facts.sh"
FX="scripts/fixtures/retro"
fail() { echo "RETRO TEST FAIL: $*" >&2; exit 1; }
t() { echo "-- $1"; }
has() { grep -qF -- "$1" <<< "$out" || fail "want '$1' in: $out"; }
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

t "M60-001.1 facts page from a fixture run @critical"
out="$(bash "$RF" "$FX")" || fail "exit non-zero: $out"
has "- M1-002 final red"
has "- M1-002 codex NEEDS_WORK"
has "- M1-002 dispatched 2 times"
has "run budget \$4.00 reached"
has "- M1-003 — Refunds — reason: needs the payment provider's sandbox key"
has "Cost: \$4.10"
has "310k tok"
has "M1-001: rejected a calendar library"
has "M1-002: skipped the refund path (M1-003 owns it); the cutoff test was written after the code."
has "- M1-002.1 NEVER FAILED before it passed"
has "- M1-001.1 failed, then passed"
has "- M1-001.2 failed, then passed"
! grep -q 'M1-001\.[12] NEVER' <<< "$out" || fail "M1-001 checks failed first: $out"
[ "$out" = "$(bash "$RF" "$FX")" ] || fail "output must be deterministic"
[ "$(wc -l <<< "$out")" -le 80 ] || fail "more than 80 lines"
# a long run still fits one page
cp -R "$FX/." "$tmp/"
for i in $(seq 1 120); do echo "17619$i gate M9-$i final red"; done >> "$tmp/.harness-run/events.log"
big="$(bash "$RF" "$tmp")"
[ "$(wc -l <<< "$big")" -le 80 ] || fail "long run: $(wc -l <<< "$big") lines, want at most 80"
grep -q 'more lines cut' <<< "$big" || fail "long run: the cut must be said"
echo "RETRO TESTS GREEN"
