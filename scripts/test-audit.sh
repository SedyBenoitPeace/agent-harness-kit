#!/usr/bin/env bash
# Fixture tests for skills/harness-audit/scripts/check.sh.
# Builds a harnessed repo from the shipped templates, then breaks it one
# defect at a time and asserts the checker catches each one.
set -euo pipefail
cd "$(dirname "$0")/.."

CHECK="skills/harness-audit/scripts/check.sh"
TMPL="skills/harness-setup/templates"

fail() { echo "AUDIT-TEST FAIL: $*" >&2; exit 1; }

make_fixture() {  # $1 = destination dir
  local d="$1"
  mkdir -p "$d/scripts" "$d/docs/plans/active" "$d/docs/plans/completed" "$d/docs/agents"
  sed 's/{{[A-Za-z0-9_]*}}/X/g'    "$TMPL/AGENTS.md.tmpl"     > "$d/AGENTS.md"
  sed 's/{{[A-Za-z0-9_]*}}/X/g'    "$TMPL/FEATURES.json.tmpl" > "$d/FEATURES.json"
  sed 's/{{[A-Za-z0-9_]*}}/X/g'    "$TMPL/PROGRESS.md.tmpl"   > "$d/PROGRESS.md"
  sed 's/{{[A-Za-z0-9_]*}}/X/g'    "$TMPL/ARCHITECTURE.md.tmpl" > "$d/ARCHITECTURE.md"
  sed 's/{{[A-Za-z0-9_]*}}/true/g' "$TMPL/e2e.sh.tmpl"        > "$d/scripts/e2e.sh"
  chmod +x "$d/scripts/e2e.sh"
  cp "$TMPL/harness-protocol.md" "$d/docs/agents/harness-protocol.md"
  cp "$TMPL/pointer.md.tmpl" "$d/CLAUDE.md"
}

expect_fail() {  # $1 = fixture dir, $2 = expected FAIL pattern, $3 = label
  local out
  if out="$(bash "$CHECK" "$1")"; then
    fail "$3: checker exited 0, expected failure"
  fi
  echo "$out" | grep -q "^FAIL.*$2" || fail "$3: missing expected FAIL line ($2)"
  echo "$out" | grep -q "NOT HARNESS READY" || fail "$3: missing NOT HARNESS READY verdict"
}

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# 1. good fixture: exit 0, READY verdict, zero FAIL lines
make_fixture "$WORK/good"
out="$(bash "$CHECK" "$WORK/good")" || fail "good fixture: checker exited non-zero"
echo "$out" | grep -q "HARNESS READY" || fail "good fixture: no HARNESS READY verdict"
if echo "$out" | grep -q "^FAIL"; then fail "good fixture: unexpected FAIL line"; fi

# 2. drifted protocol doc: WARN, still exit 0
make_fixture "$WORK/drift"
echo "local note" >> "$WORK/drift/docs/agents/harness-protocol.md"
out="$(bash "$CHECK" "$WORK/drift")" || fail "drifted protocol must not fail the audit"
echo "$out" | grep -q "^WARN.*differs" || fail "drifted protocol: expected WARN line"

# 2b. missing ARCHITECTURE.md: WARN (repair flow lives in SKILL.md), still exit 0
make_fixture "$WORK/no-arch"
rm "$WORK/no-arch/ARCHITECTURE.md"
out="$(bash "$CHECK" "$WORK/no-arch")" || fail "missing ARCHITECTURE.md must not fail the audit"
echo "$out" | grep -q "^WARN.*ARCHITECTURE.md" || fail "missing ARCHITECTURE.md: expected WARN line"

# 2c. missing logging/observability strategy: WARN (repair flow lives in
# SKILL.md), still exit 0 — strip the mention while keeping ARCHITECTURE.md
make_fixture "$WORK/no-logging"
grep -vi 'logging' "$WORK/no-logging/ARCHITECTURE.md" > "$WORK/no-logging/ARCH.tmp"
mv "$WORK/no-logging/ARCH.tmp" "$WORK/no-logging/ARCHITECTURE.md"
out="$(bash "$CHECK" "$WORK/no-logging")" || fail "missing logging strategy must not fail the audit"
echo "$out" | grep -q "^WARN.*logging/observability" || fail "missing logging strategy: expected WARN line"

# 3. defect fixtures: each must FAIL with its specific line
make_fixture "$WORK/big-agents"
for _ in $(seq 1 101); do echo "filler line" >> "$WORK/big-agents/AGENTS.md"; done
expect_fail "$WORK/big-agents" "AGENTS.md exceeds" "oversized AGENTS.md"

make_fixture "$WORK/empty-verify"
jq '.features[0].verify = ""' "$WORK/empty-verify/FEATURES.json" > "$WORK/empty-verify/F.tmp"
mv "$WORK/empty-verify/F.tmp" "$WORK/empty-verify/FEATURES.json"
expect_fail "$WORK/empty-verify" "id/milestone/verify" "empty verify"

make_fixture "$WORK/no-gate"
rm "$WORK/no-gate/scripts/e2e.sh"
expect_fail "$WORK/no-gate" "scripts/e2e.sh missing" "missing gate"

make_fixture "$WORK/no-plans"
rmdir "$WORK/no-plans/docs/plans/active"
expect_fail "$WORK/no-plans" "docs/plans" "missing plans dir"

make_fixture "$WORK/no-proto"
rm "$WORK/no-proto/docs/agents/harness-protocol.md"
expect_fail "$WORK/no-proto" "harness-protocol.md missing" "missing protocol doc"

echo "AUDIT TESTS GREEN"
