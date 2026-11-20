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
st="$(bash "$S/read-checks.sh" --status passing "$FX/features.json" | jq -r .id | tr '\n' ',')"
[ "$st" = "M1-001.1,M1-001.2," ] || fail "--status passing kept: $st"

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
c="$(bash "$S/read-checks.sh" --issue-json "$FX/issue-messy.json")" || fail "messy issue (CRLF, headings outside Checks, a fence, ' - ', wrapped Pass if, unindented steps) rejected"
[ "$c" = "$b" ] || fail "messy issue output differs:
$c
---
$b"

t "M53-001.3 malformed checks are named and rejected"
if bash "$S/read-checks.sh" "$FX/bad.json" >/dev/null 2>"$tmp/err"; then fail "bad checks accepted"; fi
for want in "M9-001.1: id" "M2-001.2: steps" "M2-001.3: evidence" "M2-001.4: critical" "M2-001.4: listed twice"; do
  grep -qF "$want" "$tmp/err" || fail "missing problem '$want' in: $(cat "$tmp/err")"
done
jq '.features[0].checks = {}' "$FX/features.json" > "$tmp/obj.json"
rc=0; bash "$S/read-checks.sh" "$tmp/obj.json" >/dev/null 2>"$tmp/err" || rc=$?
{ [ "$rc" = 1 ] && grep -qF 'M1-001: checks must be a list' "$tmp/err"; } || fail "checks as an object: want exit 1 naming M1-001, got $rc: $(cat "$tmp/err")"
[ "$(bash "$S/read-checks.sh" --status "passing, failing" "$FX/features.json" | wc -l | tr -d ' ')" = 3 ] || fail "--status must trim spaces"

BRIEF="skills/harness-brief/scripts/check-brief.sh"
good_brief() {  # a brief check-brief.sh passes; $1 replaces its ## Checks body
  cat <<'B'
# Brief: demo

## Objective
Ship a CLI that prints the weather.

## Stage
production — people will install it from npm.

## Context
Empty repo, Node 22.

## Deliverables
- `bin/weather`

## Non-goals
- No GUI.

## Done when
- `npm test` exits 0

## Quality bar
Gate is sufficient.

## Needs a human
- Publishing to npm.

## Budget and stop condition
Stop after 5 features.

B
  printf '%s\n\n## Open questions\n' "$1"
}
# shellcheck disable=SC2016 # backticks are literal markdown
CHECK_C1='## Checks
### C1 — Weather for a named city
- **Critical:** yes
- **Steps:**
  1. Run `bin/weather --city Rome`
- **Pass if:** one line containing "Rome" and a temperature in °C; exit 0
- **Evidence:** test'
good_brief "$CHECK_C1" > "$tmp/brief.md"
bash "$BRIEF" "$tmp/brief.md" >/dev/null || fail "a brief with one good check must pass: $(bash "$BRIEF" "$tmp/brief.md" | grep FAIL)"

t "M53-002.1 a brief without checks fails @critical"
good_brief "" | sed '/^## Checks$/d' > "$tmp/nochecks.md"
if out="$(bash "$BRIEF" "$tmp/nochecks.md")"; then fail "brief without a Checks section passed"; fi
grep -q '^FAIL.*Checks' <<< "$out" || fail "no FAIL naming Checks: $out"
good_brief "## Checks" > "$tmp/empty.md"
if out="$(bash "$BRIEF" "$tmp/empty.md")"; then fail "brief with an empty Checks section passed"; fi
grep -q '^FAIL.*Checks' <<< "$out" || fail "no FAIL naming Checks for an empty section: $out"

t "M53-002.2 a vague Pass if fails"
good_brief "${CHECK_C1/one line containing \"Rome\" and a temperature in °C; exit 0/it works correctly}" > "$tmp/vague.md"
if out="$(bash "$BRIEF" "$tmp/vague.md")"; then fail "vague Pass if passed"; fi
grep -q '^FAIL.*C1.*works' <<< "$out" || fail "no FAIL naming C1 and the vague word: $out"
good_brief "${CHECK_C1/Evidence:\*\* test/Evidence:** video}" > "$tmp/badev.md"
if out="$(bash "$BRIEF" "$tmp/badev.md")"; then fail "malformed check passed"; fi
grep -q '^FAIL.*C1: evidence' <<< "$out" || fail "malformed check not named: $out"

t "M53-002.3 the reviewer blocks missing or vague checks"
mkdir -p "$tmp/gen" && bash scripts/gen-agents.sh "$tmp/gen" >/dev/null
gen() { find "$tmp/gen" -type f -name "$1*"; }
for f in agents/src/harness-brief-reviewer.md $(gen harness-brief-reviewer); do
  grep -qi 'no check' "$f" || fail "$f: BLOCKING list must name a deliverable with no check"
  grep -qi 'Pass if' "$f" || fail "$f: BLOCKING list must name a vague Pass if"
done

t "M53-003.1 builder instructions require one test per check"
n=0
for f in agents/src/harness-builder.md $(gen harness-builder); do
  n=$((n + 1))
  grep -qi 'one test per check' "$f" || fail "$f: must say one test per check"
  grep -qi 'before the code' "$f" || fail "$f: tests must come before the code"
  grep -qi 'starting with the check id' "$f" || fail "$f: test title must start with the check id"
  grep -qF '@critical' "$f" || fail "$f: must tag critical checks @critical"
done
[ "$n" -ge 4 ] || fail "expected the source plus generated builders, found $n"

COV="$S/check-coverage.sh"
cov() {  # cov <tests file>: run check-coverage.sh against the fixture features
  bash "$COV" --features "$FX/features.json" "$1" 2>&1
}
t "M53-004.1 full coverage passes @critical"
out="$(cov "$FX/cov/booking.spec.ts")" || fail "full coverage failed: $out"
grep -q '2 checks covered' <<< "$out" || fail "no '2 checks covered' line: $out"
out="$(cov "$FX/cov/tagged.spec.ts")" || fail "apostrophe title, tag option, backticks, comment and a version string must pass: $out"

t "M53-004.2 each coverage gap fails with its own message @critical"
gap() {  # gap <name> <sed expr> <expected stderr text>
  sed "$2" "$FX/cov/booking.spec.ts" > "$tmp/$1.spec.ts"
  if out="$(cov "$tmp/$1.spec.ts")"; then fail "$1: coverage passed"; fi
  grep -qF "$3" <<< "$out" || fail "$1: expected '$3' in: $out"
}
gap missing '/M1-001\.2/,/^});/d' 'M1-001.2: no test'
gap twice 's/M1-001\.2/M1-001.1/' 'M1-001.1: 2 tests'
gap unknown 's/M1-001\.2/M1-007.1/' 'M1-007.1: no such check'
gap untagged 's/ @critical//' 'M1-001.1: critical check, test lacks @critical'
gap overtagged 's/looks right/looks right @critical/' 'M1-001.2: test tagged @critical'
grep -q 'M1-002.1' <<< "$(cov "$FX/cov/booking.spec.ts")" && fail "a failing feature's missing test must not be reported"

t "M53-004.3 repos get the coverage step"
grep -qx 'step check-coverage "{{CHECK_COVERAGE_COMMAND}}"' skills/harness-initial-setup/templates/e2e.sh.tmpl || fail "e2e.sh.tmpl must run the check-coverage step"
grep -qF 'bash scripts/check-coverage.sh' skills/harness-initial-setup/templates/e2e.sh.tmpl || fail "e2e.sh.tmpl must show the check-coverage command"
setup="skills/harness-initial-setup/SKILL.md"
for w in check-coverage.sh read-checks.sh; do
  grep -E '^\| `\.\./harness-session/scripts/' "$setup" | grep -qF "$w" || fail "setup SKILL.md scaffold table must copy $w into scripts/"
done

VERDICT="$S/acceptance-verdict.sh"
table() {  # table <file> <row>...: an evaluator table for feature M1-001
  { echo '| check | verdict | evidence |'; echo '|---|---|---|'; printf '%s\n' "${@:2}"; } > "$1"
}
verdict() { bash "$VERDICT" --features "$FX/features.json" M1-001 "$1" 2>&1; }
t "M53-005.1 all covered is PASS @critical"
table "$tmp/ok.md" '| M1-001.1 | covered | booking.spec.ts:3 passes |' '| M1-001.2 | covered | screenshots attached |'
out="$(verdict "$tmp/ok.md")" || fail "all covered must exit 0: $out"
[ "$(head -1 <<< "$out")" = PASS ] || fail "first line must be PASS: $out"
out="$(bash "$VERDICT" --features "$FX/features.json" M1-001 - < "$tmp/ok.md")" || fail "a table on stdin must work: $out"

t "M53-005.2 anything else is NEEDS_WORK @critical"
nw() {  # nw <name> <expected reason> <row>...
  local name="$1" want="$2"; shift 2
  table "$tmp/$name.md" "$@"
  if out="$(verdict "$tmp/$name.md")"; then fail "$name: must exit non-zero: $out"; fi
  [ "$(head -1 <<< "$out")" = NEEDS_WORK ] || fail "$name: first line must be NEEDS_WORK: $out"
  grep -qF "$want" <<< "$out" || fail "$name: expected '$want' in: $out"
}
nw partial 'M1-001.2: partial' '| M1-001.1 | covered | ok |' '| M1-001.2 | partial | no Italian screenshot |'
nw missing 'M1-001.2: missing' '| M1-001.1 | covered | ok |' '| M1-001.2 | missing | none |'
nw unrequested 'extra-export: unrequested' '| M1-001.1 | covered | ok |' '| M1-001.2 | covered | ok |' '| extra-export | unrequested | adds a CSV export |'
nw norow 'M1-001.2: no row' '| M1-001.1 | covered | ok |'
nw tworows 'M1-001.1: 2 rows' '| M1-001.1 | covered | ok |' '| M1-001.1 | partial | flaky |' '| M1-001.2 | covered | ok |'
nw badword 'M1-001.2: unknown verdict' '| M1-001.1 | covered | ok |' '| M1-001.2 | looks fine | ok |'
nw foreign 'M1-002.1: not a check of M1-001' '| M1-001.1 | covered | ok |' '| M1-001.2 | covered | ok |' '| M1-002.1 | covered | ok |'
out="$(bash "$VERDICT" --features "$FX/features.json" M1-001 - < /dev/null 2>&1)" && fail "an empty table must exit non-zero"
{ [ "$(head -1 <<< "$out")" = NEEDS_WORK ] && grep -qF 'M1-001.1: no row' <<< "$out"; } || fail "empty table: want NEEDS_WORK and no-row reasons, got: $out"

t "M53-005.3 the evaluator uses the script"
n=0
for f in agents/src/harness-evaluator.md $(gen harness-evaluator); do
  n=$((n + 1))
  grep -qF 'acceptance-verdict.sh' "$f" || fail "$f: must run acceptance-verdict.sh"
  for w in covered partial missing unrequested; do grep -qw "$w" "$f" || fail "$f: verdict word $w missing"; done
  grep -qi 'one row per check' "$f" || fail "$f: must write one row per check"
done
[ "$n" -ge 4 ] || fail "expected the source plus generated evaluators, found $n"

echo "CHECKS TESTS GREEN"
