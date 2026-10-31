#!/usr/bin/env bash
# harness-brief: deterministic brief checker.
# Usage: check-brief.sh BRIEF.md
# One PASS/FAIL line per check; exits non-zero iff any FAIL.
set -euo pipefail

brief="${1:?usage: check-brief.sh BRIEF.md}"
[ -f "$brief" ] || { echo "FAIL  $brief not found" >&2; exit 2; }

fails=0
pass() { echo "PASS  $*"; }
failc() { echo "FAIL  $*"; fails=$((fails + 1)); }

# body of a "## <name>" section, blank lines dropped
section() {
  awk -v s="## $1" '/^## /{on = ($0 == s); next} on && NF' "$brief"
}

for s in "Objective" "Context" "Deliverables" "Non-goals" "Done when" \
         "Quality bar" "Needs a human" "Budget and stop condition"; do
  if ! grep -qx "## $s" "$brief"; then
    failc "section missing: $s"
  elif [ -z "$(section "$s")" ]; then
    failc "section empty: $s"
  else
    pass "section: $s"
  fi
done

if ! grep -qx '## Open questions' "$brief"; then
  failc "section missing: Open questions"
elif section 'Open questions' | grep -qv '^- NOTE: '; then
  failc "Open questions must be empty (reviewer '- NOTE: ' lines allowed): resolve them with the human first"
else
  pass "Open questions empty (NOTEs allowed)"
fi

# review round cap (M42-001): this check runs before every review round, so
# it refuses a third one even when the reviewer runs in a separate process
rounds="$(sed -n 's/^<!-- Review rounds: \([0-9][0-9]*\) -->$/\1/p' "$brief" | head -1)"
if [ -n "$rounds" ] && [ "$rounds" -ge 2 ]; then
  failc "STOP: round cap reached, show remaining gaps to the human ($rounds review rounds done)"
else
  pass "review rounds: ${rounds:-0} of 2"
fi

# Stage (M26-002): prototype or production decides effort and the quality bar
stage="$(section 'Stage' | head -1)"
if ! grep -qx '## Stage' "$brief"; then
  failc "section missing: Stage (prototype or production)"
elif ! printf '%s\n' "$stage" | grep -Eqi '^(prototype|production)\b'; then
  failc "Stage must start with prototype or production, got: $stage"
else
  pass "Stage: $(printf '%s' "$stage" | awk '{print tolower($1)}')"
fi

# every Done-when line needs a backticked command
# shellcheck disable=SC2016 # backticks are literal in the grep pattern
bad="$(section 'Done when' | grep -v '`[^`][^`]*`' || true)"
if [ -n "$bad" ]; then
  failc "Done when line has no backticked command: $(echo "$bad" | head -1)"
else
  pass "Done when lines all carry a command"
fi

[ "$fails" -eq 0 ]
