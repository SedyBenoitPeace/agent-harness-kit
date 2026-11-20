#!/usr/bin/env bash
# Proves the acceptance-check pieces (M53): read-checks.sh, check-coverage.sh,
# acceptance-verdict.sh and the agent/brief contracts. Exit 0 = green.
# Each t "<check id> …" line is the one test for that check (check-coverage.sh).
set -euo pipefail
cd "$(dirname "$0")/.."
S="skills/harness-session/scripts"
FX="scripts/fixtures/checks"
fail() { echo "CHECKS TEST FAIL: $*" >&2; exit 1; }
t() { echo "-- $1"; }
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

t "M53-001.1 FEATURES.json backend prints one line per check @critical"
out="$(bash "$S/read-checks.sh" "$FX/features.json")" || fail "reader exited non-zero on a good file"
[ "$(printf '%s\n' "$out" | wc -l | tr -d ' ')" = 3 ] || fail "expected 3 check lines, got: $out"
want='{"feature":"M1-001","id":"M1-001.1","title":"Book a future session","critical":true,"steps":["Open Book","Pick a future session and confirm"],"pass_if":"Booking confirmed appears and the session is listed under My bookings","evidence":"test"}'
[ "$(printf '%s\n' "$out" | head -1)" = "$want" ] || fail "first line wrong: $(printf '%s\n' "$out" | head -1)"
printf '%s\n' "$out" | tail -1 | grep -q '"feature":"M1-002","id":"M1-002.1"' || fail "feature id missing on last line"
st="$(bash "$S/read-checks.sh" --status passing "$FX/features.json" | jq -r .id | tr '\n' ' ')"
[ "$st" = "M1-001.1 M1-001.2 " ] || fail "--status passing kept: $st"

t "M53-001.2 issue backend matches the FEATURES.json backend @critical"
a="$(bash "$S/read-checks.sh" --issue-json "$FX/issue.json")" || fail "issue backend exited non-zero"
b="$(bash "$S/read-checks.sh" "$FX/features.json" | grep '"feature":"M1-001"')"
[ "$a" = "$b" ] || fail "issue output differs:
$a
---
$b"
jq '.title = "Book a session"' "$FX/issue.json" > "$tmp/noid.json"
if bash "$S/read-checks.sh" --issue-json "$tmp/noid.json" 2>"$tmp/err"; then fail "issue without [ID] title accepted"; fi
grep -q 'title' "$tmp/err" || fail "no-id error does not name the title: $(cat "$tmp/err")"

t "M53-001.3 malformed checks are named and rejected"
if bash "$S/read-checks.sh" "$FX/bad.json" >/dev/null 2>"$tmp/err"; then fail "bad checks accepted"; fi
for want in "M9-001.1: id" "M2-001.2: steps" "M2-001.3: evidence" "M2-001.4: critical" "M2-001.4: listed twice"; do
  grep -qF "$want" "$tmp/err" || fail "missing problem '$want' in: $(cat "$tmp/err")"
done

echo "CHECKS TESTS GREEN"
