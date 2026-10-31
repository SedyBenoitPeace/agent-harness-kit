#!/usr/bin/env bash
# Proves harness-brief's check-brief.sh and SKILL.md contract. Exit 0 = green.
set -euo pipefail
cd "$(dirname "$0")/.."
fail() { echo "BRIEF TEST FAIL: $*" >&2; exit 1; }

SKILL="skills/harness-brief"
CHECK="$SKILL/scripts/check-brief.sh"
[ -f "$CHECK" ] || fail "check-brief.sh missing"

t="$(mktemp -d)"; trap 'rm -rf "$t"' EXIT

cat > "$t/good.md" <<'B'
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
- `bin/weather --city Rome` prints a line containing "Rome"

## Quality bar
Gate is sufficient.

## Needs a human
- Publishing to npm.

## Budget and stop condition
Stop after 5 features or the first red gate.

## Open questions
B

"$CHECK" "$t/good.md" >/dev/null || fail "complete fixture must pass"

# expect_fail <name> <sed-expr> <expected FAIL text>
expect_fail() {
  local out
  sed "$2" "$t/good.md" > "$t/$1.md"
  if out="$("$CHECK" "$t/$1.md" 2>&1)"; then fail "$1: must exit non-zero"; fi
  echo "$out" | grep -q "^FAIL.*$3" || fail "$1: no FAIL line matching '$3' (got: $out)"
}
expect_fail missing-section '/^## Non-goals$/,/^$/d' 'Non-goals'
expect_fail open-question 's/^## Open questions$/&\nWho pays for hosting?/' 'Open questions'
# shellcheck disable=SC2016 # backticks are literal in the sed expression
expect_fail vague-done 's/^- `npm test` exits 0$/- it works well/' 'Done when'

# Stage (M26-002): missing, or not prototype|production, fails; both pass
expect_fail no-stage '/^## Stage$/,/^$/d' 'Stage'
expect_fail bad-stage 's/^production — people/beta — people/' 'Stage'
sed 's/^production — people will install it from npm.$/prototype — a demo for one meeting./' "$t/good.md" > "$t/proto.md"
"$CHECK" "$t/proto.md" >/dev/null || fail "prototype stage must pass"
grep -qx '## Stage' "$SKILL/templates/brief.md.tmpl" || fail "brief.md.tmpl: ## Stage missing"
grep -qi 'prototype or production' "$SKILL/SKILL.md" || fail "harness-brief SKILL.md must ask prototype or production"

# the defect fixtures fail only on their own defect
[ "$("$CHECK" "$t/vague-done.md" | grep -c '^FAIL')" -eq 1 ] || fail "vague-done: expected exactly one FAIL line"

# template must itself have every section
for s in Objective Context Deliverables Non-goals "Done when" "Quality bar" "Needs a human" "Budget and stop condition" "Open questions"; do
  grep -q "^## $s\$" "$SKILL/templates/brief.md.tmpl" || fail "brief.md.tmpl: section '$s' missing"
done

# SKILL.md: valid, agent-neutral, bounded questions, stranger test before saving
md="$SKILL/SKILL.md"
[ "$(head -1 "$md")" = "---" ] || fail "SKILL.md: missing frontmatter"
grep -q '^name: harness-brief$' "$md" || fail "SKILL.md: frontmatter name wrong"
grep -q '^description: Use when' "$md" || fail "SKILL.md: description must start with 'Use when'"
! grep -qi 'claude' "$md" || fail "SKILL.md must be agent-neutral"
grep -qi 'at most three questions' "$md" || fail "SKILL.md: three-question cap missing"
grep -qi 'stranger test' "$md" || fail "SKILL.md: stranger test missing"
grep -q 'check-brief.sh' "$md" || fail "SKILL.md: does not run check-brief.sh"
grep -q 'templates/brief.md.tmpl' "$md" || fail "SKILL.md: template not referenced"

# reviewer dispatch (M19-002)
grep -q 'harness-brief-reviewer' "$md" || fail "SKILL.md: reviewer dispatch missing"
grep -q 'READY' "$md" || fail "SKILL.md: READY verdict missing"
grep -q 'GAPS' "$md" || fail "SKILL.md: GAPS verdict missing"
grep -qi 'only the brief' "$md" || fail "SKILL.md: reviewer must receive only the brief"
grep -qi '2 review rounds' "$md" || fail "SKILL.md: 2-round stop missing"

# review round cap (M42-001): mechanical, so it holds when the reviewer runs
# as a separate CLI process that forgets the count
ROUND="$SKILL/scripts/review-round.sh"
[ -f "$ROUND" ] || fail "review-round.sh missing"
cp "$t/good.md" "$t/rounds.md"
bash "$ROUND" "$t/rounds.md" >/dev/null || fail "review-round: round 1 must pass"
"$CHECK" "$t/rounds.md" >/dev/null || fail "check-brief: round 1 recorded must still pass"
bash "$ROUND" "$t/rounds.md" >/dev/null || fail "review-round: round 2 must pass"
grep -q 'Review rounds: 2' "$t/rounds.md" || fail "review-round: brief must record Review rounds: 2"
if out="$(bash "$ROUND" "$t/rounds.md" 2>&1)"; then fail "review-round: round 3 must exit non-zero"; fi
grep -qxF 'STOP: round cap reached, show remaining gaps to the human' <<< "$out" || fail "review-round: STOP line missing (got: $out)"
grep -q 'Review rounds: 2' "$t/rounds.md" || fail "review-round: a refused round must not be counted"
# check-brief, which runs before every round, refuses a third one too
if out="$("$CHECK" "$t/rounds.md" 2>&1)"; then fail "check-brief: must FAIL at the round cap"; fi
grep -q '^FAIL.*STOP: round cap reached' <<< "$out" || fail "check-brief: no STOP FAIL line (got: $out)"
[ "$(grep -c '^FAIL' <<< "$out")" -eq 1 ] || fail "check-brief: the cap must be its only FAIL"
# a READY verdict closes the review: the brief checks clean again
bash "$ROUND" --ready "$t/rounds.md" >/dev/null || fail "review-round --ready must pass"
"$CHECK" "$t/rounds.md" >/dev/null || fail "check-brief: a READY brief must pass at the cap"
# the counter sits above the first section, so it never lands in Open questions
[ "$(sed -n 2p "$t/rounds.md")" = '<!-- Review rounds: 2, READY -->' ] || fail "review-round: counter must be line 2 (got: $(sed -n 2p "$t/rounds.md"))"

# NOTEs (non-blocking findings) may sit in Open questions; questions may not
# shellcheck disable=SC2016 # backticks are literal in the sed expression
sed 's/^## Open questions$/&\n- NOTE: `cd app` leaves the shell in app\//' "$t/good.md" > "$t/notes.md"
"$CHECK" "$t/notes.md" >/dev/null || fail "check-brief: NOTE lines in Open questions must pass"
expect_fail note-and-question 's/^## Open questions$/&\n- NOTE: nit\nWho hosts it?/' 'Open questions'

# the nits-only fixture is mechanically clean (its flaws are for the reviewer)
"$CHECK" scripts/fixtures/brief/nits-only.md >/dev/null || fail "fixtures/brief/nits-only.md must pass check-brief"

# step 6 wires the cap, the re-check and where NOTEs go
step6="$(sed -n '/^6\. /,/^7\. /p' "$md")"
grep -qF 'review-round.sh' <<< "$step6" || fail "SKILL.md step 6: must run review-round.sh before every dispatch"
grep -qF 'STOP' <<< "$step6" || fail "SKILL.md step 6: must stop on the STOP line"
grep -qi 'previous gap list' <<< "$step6" || fail "SKILL.md step 6: round 2 must pass the previous gap list"
grep -qF 'NOTE' <<< "$step6" || fail "SKILL.md step 6: NOTEs missing"
grep -qi 'Open questions, not' <<< "$step6" || fail "SKILL.md step 6: NOTEs go into Open questions, not another round"
grep -qF -- '--ready' <<< "$step6" || fail "SKILL.md step 6: READY must be recorded with --ready"

echo "BRIEF TESTS GREEN"
