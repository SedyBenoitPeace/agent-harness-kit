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
elif [ -n "$(section 'Open questions')" ]; then
  failc "Open questions must be empty: resolve them with the human first"
else
  pass "Open questions empty"
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
