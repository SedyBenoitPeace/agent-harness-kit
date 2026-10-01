#!/usr/bin/env bash
# Fixture tests for skills/harness-upgrade-structure/scripts/upgrade.sh. Exit 0 = green.
set -euo pipefail
cd "$(dirname "$0")/.."
fail() { echo "UPGRADE TEST FAIL: $*" >&2; exit 1; }

UPGRADE="$PWD/skills/harness-upgrade-structure/scripts/upgrade.sh"
SHIPPED="$PWD/skills/harness-initial-setup/templates/harness-protocol.md"
[ -f "$UPGRADE" ] || fail "upgrade.sh missing"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
g() { git -C "$R" -c user.email=t@t -c user.name=t "$@"; }

# 1. not a harnessed repo: points at harness-initial-setup, exit 3
mkdir "$WORK/bare"
rc=0; out="$(bash "$UPGRADE" "$WORK/bare" 2>&1)" || rc=$?
[ "$rc" -eq 3 ] || fail "bare dir: expected exit 3, got $rc"
echo "$out" | grep -q 'harness-initial-setup' || fail "bare dir: must point at harness-initial-setup"

# an old harnessed repo on its default branch: outdated protocol, no harness-run
# line, an evaluator opt-in without agent files, an unbounded gate
R="$WORK/repo"
mkdir -p "$R/docs/agents" "$R/scripts"
git -C "$R" init -q -b main
cat > "$R/FEATURES.json" <<'JSON'
{
  "milestones": { "1": "Core" },
  "features": [
    { "id": "M1-001", "milestone": 1, "title": "ui", "status": "failing", "verify": "x", "evaluate": "ui", "bar": "looks right" }
  ]
}
JSON
printf '# PROGRESS\n\n## 2026-01-01 -- session 1\n- Setup.\n' > "$R/PROGRESS.md"
printf '# AGENTS.md\n\nSee docs/agents/harness-protocol.md.\n' > "$R/AGENTS.md"
printf 'old protocol\n' > "$R/docs/agents/harness-protocol.md"
printf '#!/usr/bin/env bash\nset -e\ntrue\necho "GATE GREEN"\n' > "$R/scripts/e2e.sh"
g add -A; g commit -qm seed
before="$(g rev-parse HEAD)"

# 2. dirty tree: refuses, changes nothing
echo x > "$R/dirty.txt"
rc=0; out="$(bash "$UPGRADE" "$R" 2>&1)" || rc=$?
[ "$rc" -eq 2 ] || fail "dirty tree: expected exit 2, got $rc"
echo "$out" | grep -qi 'dirty' || fail "dirty tree: must say why"
[ "$(git -C "$R" branch --show-current)" = main ] || fail "dirty tree: branch changed"
rm "$R/dirty.txt"

# 3. upgrade from the default branch: new branch, protocol recopied, AGENTS.md
#    gets the harness-run line, evaluator files generated, gate TODO printed,
#    nothing staged or committed
out="$(bash "$UPGRADE" "$R" 2>&1)" || fail "upgrade: expected exit 0 (got: $out)"
[ "$(git -C "$R" branch --show-current)" = harness-upgrade ] || fail "upgrade: must branch to harness-upgrade off the default branch"
cmp -s "$SHIPPED" "$R/docs/agents/harness-protocol.md" || fail "upgrade: protocol not recopied"
grep -q 'harness-run' "$R/AGENTS.md" || fail "upgrade: AGENTS.md missing the harness-run line"
[ -f "$R/.claude/agents/harness-evaluator.md" ] || fail "upgrade: evaluator agent files not generated"
echo "$out" | grep -q '^CHANGED: docs/agents/harness-protocol.md' || fail "upgrade: protocol change not reported"
echo "$out" | grep -q '^TODO: .*scripts/e2e.sh' || fail "upgrade: unbounded gate must be a TODO"
echo "$out" | grep -q '^TODO: .*harness-audit' || fail "upgrade: depends_on/paths via harness-audit must be a TODO"
[ "$(g rev-parse HEAD)" = "$before" ] || fail "upgrade: must not commit"
[ -z "$(g diff --cached --name-only)" ] || fail "upgrade: must not stage anything"

# 4. idempotent: commit the result, run again on the (non-default) branch
g add -A; g commit -qm "chore: upgrade"
out="$(bash "$UPGRADE" "$R" 2>&1)" || fail "second run: expected exit 0"
if echo "$out" | grep -q '^CHANGED:'; then fail "second run: nothing should change"; fi
echo "$out" | grep -q '^OK: docs/agents/harness-protocol.md' || fail "second run: protocol should be reported current"
[ "$(git -C "$R" branch --show-current)" = harness-upgrade ] || fail "second run: must stay on the current branch"
[ -z "$(git -C "$R" status --short)" ] || fail "second run: must leave the tree clean"

echo "UPGRADE TESTS GREEN"
