#!/usr/bin/env bash
# Fixture tests for skills/harness-status/scripts/status.sh.
# Fixtures are plain directories (status.sh reads only FEATURES.json/PROGRESS.md).
set -euo pipefail
cd "$(dirname "$0")/.."

STATUS="skills/harness-status/scripts/status.sh"

fail() { echo "STATUS-TEST FAIL: $*" >&2; exit 1; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# 1. uninitialized dir: exit 3, points at harness-initial-setup
mkdir "$WORK/bare"
rc=0; out="$(bash "$STATUS" "$WORK/bare")" || rc=$?
[ "$rc" -eq 3 ] || fail "bare dir: expected exit 3, got $rc"
echo "$out" | grep -q "HARNESS NOT INITIALIZED" || fail "bare dir: missing NOT INITIALIZED line"
echo "$out" | grep -q "harness-initial-setup" || fail "bare dir: must point at harness-initial-setup"

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

# 2b. effort hint (M23-002): no line when absent; an indented effort line
# under NEXT when set, on both the plain and the --skip path
if echo "$out" | grep -q "effort:"; then fail "effort line printed for a feature without effort"; fi
jq '(.features[] | select(.id == "M1-001") | .effort) = "low" | (.features[] | select(.id == "M1-002") | .effort) = "high"' \
  "$WORK/repo/FEATURES.json" > "$WORK/repo/F.tmp" && mv "$WORK/repo/F.tmp" "$WORK/repo/FEATURES.json"
out="$(bash "$STATUS" "$WORK/repo")" || fail "effort fixture: expected exit 0"
echo "$out" | grep -q "^  effort: low$" || fail "effort: missing '  effort: low' under NEXT"
echo "M1-001" > "$WORK/skip"
out="$(bash "$STATUS" --skip "$WORK/skip" "$WORK/repo")" || fail "effort --skip fixture: expected exit 0"
# M1-002 has no depends_on, so skipping M1-001 also excludes it: NEXT none, no effort line
if echo "$out" | grep -q "effort:"; then fail "effort --skip: effort line printed with nothing eligible"; fi
jq '(.features[] | select(.id == "M1-002") | .depends_on) = []' \
  "$WORK/repo/FEATURES.json" > "$WORK/repo/F.tmp" && mv "$WORK/repo/F.tmp" "$WORK/repo/FEATURES.json"
out="$(bash "$STATUS" --skip "$WORK/skip" "$WORK/repo")" || fail "effort --skip fixture: expected exit 0"
echo "$out" | grep -q "NEXT: M1-002" || fail "effort --skip: want NEXT M1-002"
echo "$out" | grep -q "^  effort: high$" || fail "effort --skip: missing '  effort: high' under NEXT"

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

# 5. waiting on a human (M29-002): deferred + "Needs a human:" notes are
#    listed; failing features whose depends_on reaches one are held,
#    transitively, and never NEXT, with and without --skip
mkdir "$WORK/human"
cat > "$WORK/human/FEATURES.json" <<'JSON'
{ "milestones": { "1": "Core" }, "features": [
  { "id": "M1-001", "milestone": 1, "title": "deploy", "status": "deferred", "verify": "x", "notes": "Needs a human: who approves the production deploy?" },
  { "id": "M1-002", "milestone": 1, "title": "smoke", "status": "failing", "verify": "x", "depends_on": ["M1-001"] },
  { "id": "M1-003", "milestone": 1, "title": "alerts", "status": "failing", "verify": "x", "depends_on": ["M1-002"] },
  { "id": "M1-004", "milestone": 1, "title": "docs", "status": "failing", "verify": "x", "depends_on": [] },
  { "id": "M1-005", "milestone": 1, "title": "later", "status": "deferred", "verify": "x", "notes": "after the beta" } ] }
JSON
printf '# PROGRESS\n' > "$WORK/human/PROGRESS.md"
for mode in plain skip; do
  if [ "$mode" = skip ]; then : > "$WORK/empty-skip"; out="$(bash "$STATUS" --skip "$WORK/empty-skip" "$WORK/human")"; else out="$(bash "$STATUS" "$WORK/human")"; fi
  grep -qx 'WAITING ON HUMAN: M1-001 — who approves the production deploy?' <<< "$out" || fail "human $mode: WAITING ON HUMAN line missing"
  grep -qx 'HELD: M1-002 — depends on M1-001' <<< "$out" || fail "human $mode: direct dependent not held"
  grep -qx 'HELD: M1-003 — depends on M1-002' <<< "$out" || fail "human $mode: transitive dependent not held"
  grep -q 'M1-005' <<< "$(grep 'WAITING' <<< "$out")" && fail "human $mode: an ordinary deferred feature is not waiting on a human"
  grep -q '^NEXT: M1-004' <<< "$out" || fail "human $mode: NEXT must skip held features"
done
mkdir "$WORK/nohuman"; printf '# PROGRESS\n' > "$WORK/nohuman/PROGRESS.md"
jq '.features[0].notes = "after the launch"' "$WORK/human/FEATURES.json" > "$WORK/nohuman/FEATURES.json"
out="$(bash "$STATUS" "$WORK/nohuman")"
grep -q 'Waiting on a human' <<< "$out" && fail "no waiting features: no section expected"
grep -q '^NEXT: M1-002' <<< "$out" || fail "no waiting features: nothing held, NEXT is M1-002"

# 6. paths (M29-003): a paths: line under NEXT when the feature has them
jq '.features[3].paths = ["src/docs/", "tests/docs/**"]' "$WORK/human/FEATURES.json" > "$WORK/human/f.tmp" && mv "$WORK/human/f.tmp" "$WORK/human/FEATURES.json"
out="$(bash "$STATUS" "$WORK/human")"
grep -qx '  paths: src/docs/, tests/docs/\*\*' <<< "$out" || fail "paths: line missing under NEXT"
out="$(bash "$STATUS" "$WORK/nohuman")"
grep -q '^  paths:' <<< "$out" && fail "paths: no line for a feature without paths"

echo "STATUS TESTS GREEN"
