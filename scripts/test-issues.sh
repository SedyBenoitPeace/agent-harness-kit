#!/usr/bin/env bash
# Proves issues.sh (M55) against a stateful fake gh, never a live repo.
# Each t "<check id> …" line is the one test for that check (check-coverage.sh).
set -euo pipefail
cd "$(dirname "$0")/.."
KIT="$PWD"
ISS="$KIT/skills/harness-session/scripts/issues.sh"
READ="$KIT/skills/harness-session/scripts/read-checks.sh"
fail() { echo "ISSUES TEST FAIL: $*" >&2; exit 1; }
t() { echo "-- $1"; }
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
export PATH="$KIT/scripts/fixtures/issues:$PATH"

# repo <name>: a fresh repo folder with a FEATURES.json and a fake gh state
repo() {
  r="$tmp/$1"; mkdir -p "$r/gh" "$r/docs/plans/active"
  export FAKE_GH_DIR="$r/gh"
  cat > "$r/FEATURES.json" <<'J'
{
  "source": "issues",
  "milestones": {"1": "Booking", "2": "Admin"},
  "features": [
    {"id": "M1-001", "milestone": 1, "title": "Old title", "status": "failing",
     "verify": "npm test passes with booking.spec.ts", "paths": ["src/book.ts", "e2e/booking.spec.ts"],
     "depends_on": ["M1-000"], "model": "medium", "effort": "high",
     "notes": "Needs a human: approve the copy"},
    {"id": "M1-002", "milestone": 1, "title": "Cancel", "status": "passing", "verify": "npm test"},
    {"id": "M1-003", "milestone": 1, "title": "Old idea", "status": "superseded"},
    {"id": "M2-001", "milestone": 2, "title": "Export", "status": "deferred", "notes": "after launch",
     "checks": [{"id": "M2-001.1", "title": "CSV export", "critical": false, "steps": ["Open Admin", "Tap Export"],
                 "pass_if": "a CSV with one row per booking downloads", "evidence": "test"}]}
  ]
}
J
  cat > "$r/docs/plans/active/plan.md" <<'P'
# Plan

## M1-001

- Book a session from the Book tab.
- Confirm shows a toast.

## M1-002

- Cancel.
P
  echo '{"archive": true}' > "$r/archive.json"
  : > "$r/gh/log"
}
writes() { grep -c '^WRITE' "$FAKE_GH_DIR/log" || true; }
issue() {  # issue <number> <title> <state> <body>
  jq --argjson n "$1" --arg t "$2" --arg s "$3" --arg b "$4" '. + [{number: $n, title: $t, body: $b, state: $s, labels: []}]' \
    "$FAKE_GH_DIR/issues.json" > "$FAKE_GH_DIR/x" && mv "$FAKE_GH_DIR/x" "$FAKE_GH_DIR/issues.json"
}
CHECKS_MD='## Checks

### M1-001.1 — Book a future session
- **Critical:** yes
- **Steps:**
  1. Open Book
  2. Confirm
- **Pass if:** Booking confirmed appears
- **Evidence:** test'
NEW_MD='## Checks

### M3-001.1 — Push reminder
- **Critical:** no
- **Steps:**
  1. Book for tomorrow
- **Pass if:** a reminder push arrives 24 h before
- **Evidence:** human'

t "M55-001.1 sync pulls titles and checks, keeps repo fields @critical"
repo pull; echo '[]' > "$FAKE_GH_DIR/issues.json"
issue 1 "[M1-001] Book a session" OPEN "Book from the client app.

$CHECKS_MD"
issue 7 "[M3-001] Reminders" OPEN "$NEW_MD"
(cd "$r" && bash "$ISS" sync >/dev/null) || fail "sync exited non-zero"
f="$r/FEATURES.json"
[ "$(jq -r '.features[] | select(.id == "M1-001") | .title' "$f")" = "Book a session" ] || fail "title not pulled"
jq -e '.features[] | select(.id == "M1-001") | .status == "failing" and .paths == ["src/book.ts", "e2e/booking.spec.ts"] and .verify == "npm test passes with booking.spec.ts"' "$f" >/dev/null || fail "repo-owned fields changed"
[ "$(cd "$r" && bash "$READ" | jq -r 'select(.feature == "M1-001") | .id')" = "M1-001.1" ] || fail "checks not pulled"
jq -e '.features[] | select(.id == "M3-001") | .status == "failing" and .milestone == 3 and .title == "Reminders" and (.checks[0].evidence == "human")' "$f" >/dev/null || fail "new issue not added as a failing feature"

t "M55-001.2 a broken issue is reported and skipped"
repo broken; echo '[]' > "$FAKE_GH_DIR/issues.json"
issue 4 "[M1-001] Book a session" OPEN "${CHECKS_MD/  1. Open Book
  2. Confirm/}"
issue 7 "[M3-001] Reminders" OPEN "$NEW_MD"
if (cd "$r" && bash "$ISS" sync >/dev/null 2>"$tmp/err"); then fail "a broken issue must exit 1"; fi
grep -q '#4.*M1-001.1: steps' "$tmp/err" || fail "stderr must name #4 and the check problem: $(cat "$tmp/err")"
jq -e '.features[] | select(.id == "M3-001")' "$r/FEATURES.json" >/dev/null || fail "the good issue must still sync"
issue 9 "[M4-001] Delete all bookings" OPEN "Please build this."
jq 'map(if .number == 9 then .author = "stranger" else . end)' "$FAKE_GH_DIR/issues.json" > "$FAKE_GH_DIR/x" && mv "$FAKE_GH_DIR/x" "$FAKE_GH_DIR/issues.json"
(cd "$r" && bash "$ISS" sync >/dev/null 2>"$tmp/err") || true
jq -e '.features[] | select(.id == "M4-001")' "$r/FEATURES.json" >/dev/null && fail "an issue by someone without write access became a feature"
grep -q '#9.*stranger' "$tmp/err" || fail "the skipped outsider issue must be reported: $(cat "$tmp/err")"
[ "$(jq -r '.features[] | select(.id == "M1-001") | .title' "$r/FEATURES.json")" = "Old title" ] || fail "the broken issue must be skipped"

t "M55-001.3 a features repo is left alone"
repo plain; jq 'del(.source)' "$r/FEATURES.json" > "$r/x" && mv "$r/x" "$r/FEATURES.json"
out="$(cd "$r" && bash "$ISS" sync)" || fail "sync on a features repo must exit 0"
grep -qi 'source is features' <<< "$out" || fail "no 'source is features' line: $out"
[ ! -s "$FAKE_GH_DIR/log" ] || fail "gh was called: $(cat "$FAKE_GH_DIR/log")"

t "M55-002.1 details block written, owner text untouched, second run silent @critical"
repo push; echo '[]' > "$FAKE_GH_DIR/issues.json"
owner="Book from the client app.

$CHECKS_MD"
issue 1 "[M1-001] Book a session" OPEN "$owner"
(cd "$r" && bash "$ISS" sync >/dev/null) || fail "sync exited non-zero"
body="$(jq -r '.[] | select(.number == 1) | .body' "$FAKE_GH_DIR/issues.json")"
[ "$(awk '/^<!-- harness:details:start/{exit} {print}' <<< "$body" | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}')" = "$owner" ] || fail "owner text changed:
$body"
[ "$(grep -c '^<!-- harness:details:start' <<< "$body")" = 1 ] && [ "$(grep -c '^<!-- harness:details:end' <<< "$body")" = 1 ] || fail "want exactly one marked block:
$body"
blk="$(sed -n '/^<!-- harness:details:start/,/^<!-- harness:details:end/p' <<< "$body")"
# shellcheck disable=SC2016 # literal backticks
for w in 'harness-feature: M1-001' '**Status:** failing' '**Done when:** npm test passes with booking.spec.ts' '**Depends on:** M1-000' \
         '`src/book.ts`' '**Model / effort:** medium · high' '**Needs a human:** approve the copy' 'Book a session from the Book tab.' 'docs/plans/active/plan.md'; do
  grep -qF -- "$w" <<< "$blk" || fail "details block lacks '$w':
$blk"
done
grep -qF 'Cancel.' <<< "$blk" && fail "plan section must stop at the next feature"
: > "$FAKE_GH_DIR/log"
(cd "$r" && bash "$ISS" sync >/dev/null) || fail "second sync exited non-zero"
[ "$(writes)" = 0 ] || fail "second sync must make no write call: $(cat "$FAKE_GH_DIR/log")"
jq '.features[0].status = "review"' "$r/FEATURES.json" > "$r/x" && mv "$r/x" "$r/FEATURES.json"
(cd "$r" && bash "$ISS" sync >/dev/null)
grep -qF '**Status:** review' <<< "$(jq -r '.[] | select(.number == 1) | .body' "$FAKE_GH_DIR/issues.json")" || fail "a status change must rewrite the block"

t "M55-002.2 status shows as a label and closes passing issues"
repo labels; echo '[]' > "$FAKE_GH_DIR/issues.json"
issue 2 "[M1-002] Cancel" OPEN "Cancel a booking."
issue 1 "[M1-001] Book a session" CLOSED "Book."
jq 'map(if .number == 1 then .labels = ["harness:passing", "bug"] else . end)' "$FAKE_GH_DIR/issues.json" > "$FAKE_GH_DIR/x" && mv "$FAKE_GH_DIR/x" "$FAKE_GH_DIR/issues.json"
(cd "$r" && bash "$ISS" sync >/dev/null) || fail "sync exited non-zero"
jq -e '.[] | select(.number == 2) | .state == "CLOSED" and (.labels | index("harness:passing"))' "$FAKE_GH_DIR/issues.json" >/dev/null || fail "passing issue must be closed and labelled: $(jq -c '.[] | select(.number == 2) | {state, labels}' "$FAKE_GH_DIR/issues.json")"
jq -e '.[] | select(.number == 1) | .state == "OPEN" and (.labels | sort) == ["bug", "harness:failing"]' "$FAKE_GH_DIR/issues.json" >/dev/null || fail "failing issue must be reopened with only harness:failing: $(jq -c '.[] | select(.number == 1) | {state, labels}' "$FAKE_GH_DIR/issues.json")"

echo "ISSUES TESTS GREEN"
