#!/usr/bin/env bash
# Fixture tests for skills/harness-session/scripts/context.sh.
# Fixtures are tiny git repos: context.sh reports git facts status.sh can't.
set -euo pipefail
cd "$(dirname "$0")/.."

CONTEXT="skills/harness-session/scripts/context.sh"

fail() { echo "SESSION-TEST FAIL: $*" >&2; exit 1; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# builds a harnessed git repo fixture at $1 with a failing feature, a
# matching active plan, and six commits (proves the five-commit cap)
make_repo() {
  local dir="$1"
  mkdir -p "$dir/docs/plans/active"
  cat > "$dir/FEATURES.json" <<'JSON'
{
  "milestones": { "0": "Skeleton", "2": "Widgets" },
  "features": [
    { "id": "M0-001", "milestone": 0, "title": "boot", "status": "passing", "verify": "x" },
    { "id": "M2-001", "milestone": 2, "title": "widget core", "status": "failing", "verify": "test widget passes" }
  ]
}
JSON
  printf '## 2026-01-02 -- session 2\n- Done: M0-001.\n\n## 2026-01-01 -- session 1\n- Setup.\n' > "$dir/PROGRESS.md"
  printf '# Plan\nCovers M2-001.\n' > "$dir/docs/plans/active/m2.md"
  git -C "$dir" init -q -b main
  git -C "$dir" -c user.email=t@t -c user.name=t add -A
  git -C "$dir" -c user.email=t@t -c user.name=t commit -qm "seed 1"
  local i
  for i in 2 3 4 5 6; do
    printf 'v%s\n' "$i" >> "$dir/tracked.txt"
    git -C "$dir" -c user.email=t@t -c user.name=t add tracked.txt
    git -C "$dir" -c user.email=t@t -c user.name=t commit -qm "seed $i"
  done
}

# 1. bare directory: delegates to status.sh and exits 3
mkdir "$WORK/bare"
rc=0; out="$(bash "$CONTEXT" "$WORK/bare")" || rc=$?
[ "$rc" -eq 3 ] || fail "bare dir: expected exit 3, got $rc"
echo "$out" | grep -q 'HARNESS NOT INITIALIZED' || fail "bare dir: missing NOT INITIALIZED line"

# 2. broken FEATURES.json: delegates to status.sh and exits 2
mkdir "$WORK/broken"
echo '{ nope' > "$WORK/broken/FEATURES.json"
: > "$WORK/broken/PROGRESS.md"
rc=0; out="$(bash "$CONTEXT" "$WORK/broken")" || rc=$?
[ "$rc" -eq 2 ] || fail "broken JSON: expected exit 2, got $rc"
echo "$out" | grep -q 'harness-audit' || fail "broken JSON: must point at harness-audit"

# 3. clean harnessed repo: selected feature, five commits only, matching
#    plan, no preflight, and only the newest PROGRESS entry
make_repo "$WORK/repo"
out="$(bash "$CONTEXT" "$WORK/repo")" || fail "clean repo: expected exit 0"
echo "$out" | grep -q 'NEXT: M2-001' || fail "clean repo: wrong next feature"
echo "$out" | grep -q 'WORKTREE: clean' || fail "clean repo: worktree should be clean"
echo "$out" | grep -q 'PLAN: docs/plans/active/m2.md' || fail "clean repo: missing plan match"
echo "$out" | grep -q 'PREFLIGHT: absent' || fail "clean repo: preflight should be absent"
echo "$out" | grep -q 'seed 6' || fail "clean repo: newest commit missing"
echo "$out" | grep -q 'seed 2' || fail "clean repo: five commits should reach seed 2"
if echo "$out" | grep -q 'seed 1'; then fail "clean repo: commit log leaked beyond five"; fi
echo "$out" | grep -q 'session 2' || fail "clean repo: last-session extract missing"
if echo "$out" | grep -q 'session 1'; then fail "clean repo: last-session extract leaked older entries"; fi

# 4. dirty worktree: reports facts, not ownership
printf 'change\n' >> "$WORK/repo/tracked.txt"
out="$(bash "$CONTEXT" "$WORK/repo")" || fail "dirty repo: expected exit 0"
echo "$out" | grep -q 'WORKTREE: dirty' || fail "dirty repo: worktree should be dirty"
echo "$out" | grep -q ' M tracked.txt' || fail "dirty repo: missing git status line"

# 5. executable target preflight is discovered, not executed
mkdir -p "$WORK/repo/scripts"
printf '#!/usr/bin/env bash\nexit 0\n' > "$WORK/repo/scripts/preflight.sh"
chmod +x "$WORK/repo/scripts/preflight.sh"
out="$(bash "$CONTEXT" "$WORK/repo")" || fail "preflight repo: expected exit 0"
echo "$out" | grep -q 'PREFLIGHT: scripts/preflight.sh' || fail "preflight repo: not discovered"

echo "SESSION TESTS GREEN"
