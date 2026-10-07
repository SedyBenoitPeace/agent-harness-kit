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
for p in planning runs maintenance; do
  cmp -s "$(dirname "$SHIPPED")/harness-protocol-$p.md" "$R/docs/agents/harness-protocol-$p.md" || fail "upgrade: harness-protocol-$p.md not copied (M28-002)"
  echo "$out" | grep -q "^CHANGED: docs/agents/harness-protocol-$p.md (was missing" || fail "upgrade: new protocol part $p not reported"
done
echo "$out" | grep -q '^TODO: .*scripts/e2e.sh' || fail "upgrade: unbounded gate must be a TODO"
echo "$out" | grep -q "^UPGRADE-NOTE: $(jq -r .version .claude-plugin/plugin.json): " || fail "upgrade: no stamp yet, so every release's notes must print"
echo "$out" | grep -q '^TODO: .*harness-audit' || fail "upgrade: depends_on/paths via harness-audit must be a TODO"
[ "$(g rev-parse HEAD)" = "$before" ] || fail "upgrade: must not commit"
[ -z "$(g diff --cached --name-only)" ] || fail "upgrade: must not stage anything"

# 4. idempotent: commit the result, run again on the (non-default) branch
g add -A; g commit -qm "chore: upgrade"
out="$(bash "$UPGRADE" "$R" 2>&1)" || fail "second run: expected exit 0"
if echo "$out" | grep -q '^CHANGED:'; then fail "second run: nothing should change"; fi
echo "$out" | grep -q '^OK: docs/agents/harness-protocol.md' || fail "second run: protocol should be reported current"
echo "$out" | grep -q '^OK: docs/agents/harness-protocol-runs.md' || fail "second run: protocol parts should be reported current"
[ "$(git -C "$R" branch --show-current)" = harness-upgrade ] || fail "second run: must stay on the current branch"
[ -z "$(git -C "$R" status --short)" ] || fail "second run: must leave the tree clean"

# 4b. stale generated agents (M27-001): any harness agent file present →
#     every role is regenerated for each CLI the repo already has, nothing
#     for the others; a second run changes no agent file
S="$WORK/stale"
mkdir -p "$S/docs/agents" "$S/.claude/agents"
git -C "$S" init -q -b main
printf '{ "milestones": {"1":"C"}, "features": [ { "id": "M1-001", "milestone": 1, "title": "t", "status": "passing", "verify": "x", "depends_on": [] } ] }\n' > "$S/FEATURES.json"
printf '# PROGRESS\n' > "$S/PROGRESS.md"
printf '# AGENTS.md\nharness-run\n' > "$S/AGENTS.md"
cp "$SHIPPED" "$S/docs/agents/harness-protocol.md"
printf -- '---\nname: harness-builder\n---\nold builder\n' > "$S/.claude/agents/harness-builder.md"
git -C "$S" -c user.email=t@t -c user.name=t add -A; git -C "$S" -c user.email=t@t -c user.name=t commit -qm seed
out="$(bash "$UPGRADE" "$S" 2>&1)" || fail "stale agents: expected exit 0"
for r in harness-builder harness-evaluator harness-brief-reviewer; do
  grep -q 'Decisions:\|READY\|PASS' "$S/.claude/agents/$r.md" || fail "stale agents: $r not regenerated"
done
echo "$out" | grep -q '^CHANGED: .claude/agents/harness-builder.md' || fail "stale agents: builder change not reported"
if [ -d "$S/.codex" ] || [ -d "$S/.github" ]; then fail "stale agents: must not add CLIs the repo does not use"; fi
git -C "$S" -c user.email=t@t -c user.name=t add -A; git -C "$S" -c user.email=t@t -c user.name=t commit -qm up
out="$(bash "$UPGRADE" "$S" 2>&1)" || fail "stale agents second run: expected exit 0"
if echo "$out" | grep -q '^CHANGED: .claude/agents'; then fail "stale agents second run: nothing should change"; fi

# 4c. version stamp + release notes (M27-004): the first upgrade records the
#     kit version and prints every release's Upgrade notes; a repo stamped
#     with an older version gets only the newer ones; a current one none
KIT_V="$(jq -r .version .claude-plugin/plugin.json)"
[ "$(cat "$S/docs/agents/harness-kit-version")" = "$KIT_V" ] || fail "stamp: harness-kit-version must hold $KIT_V"
oldest="$(sed -n 's/^## \([0-9][0-9.]*\) .*/\1/p' CHANGELOG.md | tail -1)"
second="$(sed -n 's/^## \([0-9][0-9.]*\) .*/\1/p' CHANGELOG.md | grep -A1 -xF "$KIT_V" | sed -n 2p)"
printf '%s\n' "$oldest" > "$S/docs/agents/harness-kit-version"
git -C "$S" -c user.email=t@t -c user.name=t commit -qam "old stamp"
out="$(bash "$UPGRADE" "$S" 2>&1)" || fail "stamp: expected exit 0"
echo "$out" | grep -q "^UPGRADE-NOTE: $KIT_V: " || fail "stamp: notes for $KIT_V missing"
echo "$out" | grep -q "^UPGRADE-NOTE: $second: " || fail "stamp: notes for $second missing"
echo "$out" | grep -q "^UPGRADE-NOTE: $oldest: " && fail "stamp: notes for the recorded $oldest must not print"
echo "$out" | grep -q '^CHANGED: docs/agents/harness-kit-version' || fail "stamp: version change not reported"
git -C "$S" -c user.email=t@t -c user.name=t commit -qam "new stamp"
out="$(bash "$UPGRADE" "$S" 2>&1)" || fail "stamp current: expected exit 0"
echo "$out" | grep -q '^UPGRADE-NOTE:' && fail "stamp current: no notes when current"
echo "$out" | grep -q "^OK: docs/agents/harness-kit-version" || fail "stamp current: OK line missing"
grep -q 'UPGRADE-NOTE' skills/harness-upgrade-structure/SKILL.md || fail "SKILL.md: must relay UPGRADE-NOTE lines"

# 5. SKILL.md contract: for repos that already have a harness, runs upgrade.sh,
#    own commit, offers the audit; harness-session points at it
md="skills/harness-upgrade-structure/SKILL.md"
[ -f "$md" ] || fail "harness-upgrade-structure SKILL.md missing"
[ "$(head -1 "$md")" = "---" ] || fail "SKILL.md: missing frontmatter"
grep -q '^name: harness-upgrade-structure$' "$md" || fail "SKILL.md: frontmatter name wrong"
grep -q '^description: Use when' "$md" || fail "SKILL.md: description must start with 'Use when'"
grep -q '^description: .*already has a harness' "$md" || fail "SKILL.md: description must say it is for repos that already have a harness"
grep -q '^description: .*harness-initial-setup' "$md" || fail "SKILL.md: description must point harness-less repos at harness-initial-setup"
! grep -qi 'claude' "$md" || fail "SKILL.md must be agent-neutral"
grep -q 'scripts/upgrade.sh' "$md" || fail "SKILL.md: does not run upgrade.sh"
grep -q 'harness-audit' "$md" || fail "SKILL.md: must offer harness-audit for depends_on/paths"
grep -qi 'own commit' "$md" || fail "SKILL.md: upgrade must be committed as its own commit"
grep -q 'harness-run line' "$md" || fail "SKILL.md: must mention the harness-run line in AGENTS.md"
grep -qi 'never push' "$md" || fail "SKILL.md: never-push rule missing"
sess="skills/harness-session/SKILL.md"
grep -q 'harness-upgrade-structure' "$sess" || fail "harness-session SKILL.md: UPGRADE: offer must point at harness-upgrade-structure"
! grep -q 'recopy the shipped' "$sess" || fail "harness-session SKILL.md: upgrade steps must not be duplicated inline"

echo "UPGRADE TESTS GREEN"
