#!/usr/bin/env bash
# shellcheck disable=SC2015,SC2016 # a && b || fail asserts; literal backticks
# Fixture tests for scripts/check-readme.sh (M50-001). Exit 0 = green.
set -euo pipefail
cd "$(dirname "$0")/.."
CHK="$PWD/scripts/check-readme.sh"
fail() { echo "CHECK-README TEST FAIL: $*" >&2; exit 1; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
printf '# kit\nThe board shows a `Human hint` and Lanes roll.\n' > "$W/README.md"

run() { rc=0; out="$(bash "$CHK" "$W/CHANGELOG.md" "$W/README.md" 2>&1)" || rc=$?; }

printf '## 3.22.0 — x\n\n- thing\n\nREADME: `Human hint`, `Lanes roll`\n\n## 3.16.0 — old\n\n- no line, before the cutoff\n' > "$W/CHANGELOG.md"
run; [ "$rc" -eq 0 ] || fail "covered release: want exit 0, got $rc: $out"

printf '## 3.22.0 — x\n\n- thing\n' > "$W/CHANGELOG.md"
run; [ "$rc" -eq 1 ] && grep -q "3.22.0 has no 'README:' line" <<< "$out" || fail "missing README line not caught: $out"

printf '## 3.22.0 — x\n\nREADME: `Human hint`, `run board`\n' > "$W/CHANGELOG.md"
run; [ "$rc" -eq 1 ] && grep -q "never says 'run board'" <<< "$out" || fail "missing phrase not caught: $out"

printf '## 3.22.0 — x\n\nREADME: board stuff\n' > "$W/CHANGELOG.md"
run; [ "$rc" -eq 1 ] && grep -q 'names no' <<< "$out" || fail "line without phrases not caught: $out"

printf '## 3.22.0 — x\n\nREADME: none (gate-only change)\n' > "$W/CHANGELOG.md"
run; [ "$rc" -eq 0 ] || fail "README: none (reason) must pass: $out"

printf '## 3.22.0 — x\n\nREADME: none\n' > "$W/CHANGELOG.md"
run; [ "$rc" -eq 1 ] || fail "README: none without a reason must fail"

printf '## 3.17.10 — x\n\n- y\n' > "$W/CHANGELOG.md"
run; [ "$rc" -eq 1 ] || fail "3.17.10 is >= 3.17.0 (numeric compare)"

# the real repo
bash "$CHK" >/dev/null || fail "this repo's CHANGELOG/README are not covered: $(bash "$CHK" || true)"
echo "CHECK-README TESTS GREEN"
