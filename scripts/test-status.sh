#!/usr/bin/env bash
# Fixture tests for skills/harness-status/scripts/status.sh.
# Fixtures are plain directories (status.sh reads only FEATURES.json/PROGRESS.md).
set -euo pipefail
cd "$(dirname "$0")/.."

STATUS="skills/harness-status/scripts/status.sh"

fail() { echo "STATUS-TEST FAIL: $*" >&2; exit 1; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# 1. uninitialized dir: exit 3, points at harness-setup
mkdir "$WORK/bare"
rc=0; out="$(bash "$STATUS" "$WORK/bare")" || rc=$?
[ "$rc" -eq 3 ] || fail "bare dir: expected exit 3, got $rc"
echo "$out" | grep -q "HARNESS NOT INITIALIZED" || fail "bare dir: missing NOT INITIALIZED line"
echo "$out" | grep -q "harness-setup" || fail "bare dir: must point at harness-setup"

# 2. harnessed fixture: rollup + protocol-2 next-feature selection + last session only
mkdir "$WORK/repo"
cat > "$WORK/repo/FEATURES.json" <<'JSON'
{
  "milestones": { "0": "Skeleton", "1": "Core" },
  "features": [
    { "id": "M0-001", "milestone": 0, "title": "boot", "status": "passing", "verify": "x" },
    { "id": "M1-001", "milestone": 1, "title": "core A", "status": "failing", "verify": "test A passes" },
    { "id": "M1-002", "milestone": 1, "title": "core B", "status": "failing", "verify": "test B passes" }
  ]
}
JSON
printf '## 2026-01-02 -- session 2\n- Done: M0-001.\n\n## 2026-01-01 -- session 1\n- Setup.\n' > "$WORK/repo/PROGRESS.md"
out="$(bash "$STATUS" "$WORK/repo")" || fail "harnessed fixture: expected exit 0"
echo "$out" | grep -q "M0: 1/1 passing" || fail "milestone rollup wrong (M0)"
echo "$out" | grep -q "M1: 0/2 passing" || fail "milestone rollup wrong (M1)"
echo "$out" | grep -q "NEXT: M1-001" || fail "next-feature selection wrong (want M1-001)"
echo "$out" | grep -q "session 2" || fail "last-session extract missing"
if echo "$out" | grep -q "session 1"; then fail "last-session extract leaked older entries"; fi

# 3. nothing failing: explicit NEXT: none message
jq '.features[].status = "passing"' "$WORK/repo/FEATURES.json" > "$WORK/repo/F.tmp"
mv "$WORK/repo/F.tmp" "$WORK/repo/FEATURES.json"
out="$(bash "$STATUS" "$WORK/repo")" || fail "all-passing fixture: expected exit 0"
echo "$out" | grep -q "NEXT: none" || fail "all-passing: missing NEXT: none message"

# 4. broken FEATURES.json: exit 2, points at harness-audit
echo '{ nope' > "$WORK/repo/FEATURES.json"
rc=0; bash "$STATUS" "$WORK/repo" > "$WORK/broken.out" || rc=$?
[ "$rc" -eq 2 ] || fail "broken JSON: expected exit 2, got $rc"
grep -q "harness-audit" "$WORK/broken.out" || fail "broken JSON: must point at harness-audit"

echo "STATUS TESTS GREEN"
