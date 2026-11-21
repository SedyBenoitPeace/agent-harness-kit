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

# Automerge (M56-002): the owner grants or refuses the agent merging its own PR
am="$(section 'Automerge' | head -1)"
if ! grep -qx '## Automerge' "$brief"; then
  failc "section missing: Automerge (yes or no: may the agent merge its own PR?)"
elif ! printf '%s\n' "$am" | grep -Eqi '^(yes|no)\b'; then
  failc "Automerge must start with yes or no, got: $am"
else
  pass "Automerge: $(printf '%s' "$am" | awk '{print tolower($1)}')"
fi

# Checks (M53-002): acceptance checks are written now, before any code, in the
# kit's one check format; read-checks.sh validates them, this adds vague words
READER="$(cd "$(dirname "$0")/../../harness-session/scripts" && pwd)/read-checks.sh"
if ! grep -qx '## Checks' "$brief"; then
  failc "section missing: Checks (one ### C<n> check per behaviour, before any code)"
else
  sect="$(mktemp)"
  awk '/^## /{on = ($0 == "## Checks"); next} on' "$brief" > "$sect"
  if ! rows="$(bash "$READER" --md "$sect" 2>"$sect.err")"; then
    while IFS= read -r p; do failc "Checks: $p"; done < "$sect.err"
  elif [ -z "$rows" ]; then
    failc "Checks has no check: add ### C1 — <title> with Critical, Steps, Pass if, Evidence"
  else
    vague="$(printf '%s\n' "$rows" | jq -r '
      (.pass_if | ascii_downcase | [match("\\b(works|working|correctly|properly|as expected|fine|good|nice|looks right|appropriate(ly)?|should)\\b"; "g").string] | unique) as $w
      | select($w | length > 0) | "\(.id): Pass if is vague (\($w | join(", "))): say what a stranger would see"')"
    if [ -n "$vague" ]; then
      while IFS= read -r v; do failc "Checks: $v"; done <<< "$vague"
    else
      pass "Checks: $(printf '%s\n' "$rows" | wc -l | tr -d ' ') checks"
    fi
  fi
  rm -f "$sect" "$sect.err"
fi

[ "$fails" -eq 0 ]
