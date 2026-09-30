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

echo "BRIEF TESTS GREEN"
