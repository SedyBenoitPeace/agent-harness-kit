#!/usr/bin/env bash
# harness-audit: deterministic harness-readiness checker.
# Usage: check.sh [--run-gate] [TARGET_DIR]     (default: current directory)
# One PASS/FAIL/WARN line per check; exits non-zero iff any FAIL.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHIPPED_PROTOCOL="$SCRIPT_DIR/../../harness-setup/templates/harness-protocol.md"

RUN_GATE=0
TARGET="."
for arg in "$@"; do
  case "$arg" in
    --run-gate) RUN_GATE=1 ;;
    *) TARGET="$arg" ;;
  esac
done
cd "$TARGET"

command -v jq >/dev/null || { echo "FAIL  jq is required to audit FEATURES.json" >&2; exit 2; }

fails=0
pass() { echo "PASS  $*"; }
failc() { echo "FAIL  $*"; fails=$((fails + 1)); }
warn() { echo "WARN  $*"; }

# AGENTS.md: exists and stays a map
if [ -f AGENTS.md ]; then
  pass "AGENTS.md exists"
  if [ "$(wc -l < AGENTS.md)" -le 100 ]; then
    pass "AGENTS.md is <= 100 lines"
  else
    failc "AGENTS.md exceeds 100 lines (it must stay a table of contents)"
  fi
else
  failc "AGENTS.md missing"
fi

# FEATURES.json: parses, entries complete, statuses legal
if [ -f FEATURES.json ] && jq -e . FEATURES.json >/dev/null 2>&1; then
  pass "FEATURES.json parses as JSON"
  if jq -e '[ .features[]?
              | select( ((.id? // "") == "") or ((.milestone? // null) == null)
                        or ((.verify? // "") == "")
                        or ((.status? // "") | IN("failing","passing","deferred","superseded") | not) )
            ] | length == 0' FEATURES.json >/dev/null; then
    pass "every feature has id/milestone/verify and a legal status"
  else
    failc "FEATURES.json: entry missing id/milestone/verify or has illegal status"
  fi
else
  failc "FEATURES.json missing or invalid JSON"
fi

# PROGRESS.md
if [ -f PROGRESS.md ]; then pass "PROGRESS.md exists"; else failc "PROGRESS.md missing"; fi

# The gate
if [ -x scripts/e2e.sh ]; then
  pass "scripts/e2e.sh exists and is executable"
elif [ -f scripts/e2e.sh ]; then
  failc "scripts/e2e.sh is not executable (chmod +x scripts/e2e.sh)"
else
  failc "scripts/e2e.sh missing (the gate)"
fi

# Plans directories
if [ -d docs/plans/active ] && [ -d docs/plans/completed ]; then
  pass "docs/plans/active/ and docs/plans/completed/ exist"
else
  failc "docs/plans/active/ and/or docs/plans/completed/ missing"
fi

# Protocol doc: present, and unmodified vs the shipped copy
if [ -f docs/agents/harness-protocol.md ]; then
  pass "docs/agents/harness-protocol.md exists"
  if [ -f "$SHIPPED_PROTOCOL" ]; then
    if cmp -s docs/agents/harness-protocol.md "$SHIPPED_PROTOCOL"; then
      pass "protocol doc matches the shipped copy"
    else
      warn "protocol doc differs from the shipped copy (drifted or older version)"
    fi
  else
    warn "shipped protocol copy not found next to this script; drift not checked"
  fi
else
  failc "docs/agents/harness-protocol.md missing"
fi

# Architecture doc (WARN only: repos harnessed before 1.4.0 may lack it;
# the skill layer offers the repair flow — derive from code / interview / skip)
if [ -f ARCHITECTURE.md ]; then
  pass "ARCHITECTURE.md exists"
else
  warn "ARCHITECTURE.md missing — offer to derive it from the code or interview the human"
fi

# Pointer file (WARN only: non-vendor repos may use a different entry file)
if [ -f CLAUDE.md ]; then pass "CLAUDE.md pointer exists"; else warn "CLAUDE.md pointer missing"; fi

# Optionally run the gate itself
if [ "$RUN_GATE" -eq 1 ]; then
  if bash scripts/e2e.sh; then failc_gate=0; else failc_gate=1; fi
  if [ "$failc_gate" -eq 0 ]; then pass "gate run: exit 0"; else failc "gate run: non-zero exit"; fi
fi

echo
if [ "$fails" -eq 0 ]; then
  echo "HARNESS READY"
else
  echo "NOT HARNESS READY: $fails failing check(s)"
  exit 1
fi
