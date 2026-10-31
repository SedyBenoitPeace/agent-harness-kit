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
grep -qF 'a source file over 200 lines' "$R/AGENTS.md" || fail "upgrade: AGENTS.md without Rules must get the read rule appended (M38-003)"
echo "$out" | grep -q '^CHANGED: AGENTS.md (added the read rule' || fail "upgrade: read rule change not reported"
echo "$out" | grep -q '^TODO: effort is now required.*on: M1-001$' || fail "upgrade: an open feature without effort must be a TODO naming it (M36-001)"
echo "$out" | grep -q '^TODO: model is now required.*on: M1-001$' || fail "upgrade: an open feature without model must be a TODO naming it (M36-002)"
[ "$(g rev-parse HEAD)" = "$before" ] || fail "upgrade: must not commit"
[ -z "$(g diff --cached --name-only)" ] || fail "upgrade: must not stage anything"

# 3b. Needs-a-human line (M29-002): the template's old wording is replaced
#     in place; an edited section gets a TODO; the current one is OK
N="$WORK/needs"; mkdir -p "$N"
# shellcheck disable=SC2016 # the backticks are literal markdown
printf '# A\n\n## Needs a human\n\nStop the session as `blocked` with a question in `PROGRESS.md` — never act — before:\ndeploy.\n' > "$N/AGENTS.md"
printf '# B\n\n## Needs a human\n\nAsk Bob before: deploy.\n' > "$N/edited.md"
for c in AGENTS.md edited.md; do
  M="$WORK/needs-$c"; mkdir -p "$M/docs/agents"; git -C "$M" init -q -b main
  printf '{ "milestones": {"1":"C"}, "features": [] }\n' > "$M/FEATURES.json"; printf '# P\n' > "$M/PROGRESS.md"
  cp "$N/$c" "$M/AGENTS.md"; printf 'harness-run\n' >> "$M/AGENTS.md"
  git -C "$M" -c user.email=t@t -c user.name=t add -A; git -C "$M" -c user.email=t@t -c user.name=t commit -qm seed
  out="$(bash "$UPGRADE" "$M" 2>&1)" || fail "needs-a-human $c: expected exit 0"
  # M39-001: no agent files and no evaluation opt-in still gets the builder for every CLI
  for f in .claude/agents/harness-builder.md .github/agents/harness-builder.agent.md .codex/agents/harness-builder.toml; do
    [ -f "$M/$f" ] || fail "upgrade: a repo without agent files must get $f"
  done
  if [ "$c" = AGENTS.md ]; then
    grep -q '^CHANGED: AGENTS.md (Needs a human' <<< "$out" || fail "needs-a-human: old line not replaced"
    # shellcheck disable=SC2016 # literal markdown
    grep -qF 'set your feature to `deferred` with notes `Needs a human: <question>`, before:' "$M/AGENTS.md" || fail "needs-a-human: new line missing"
    grep -qF 'Stop the session as' "$M/AGENTS.md" && fail "needs-a-human: old line still there"
    grep -qx 'deploy.' "$M/AGENTS.md" || fail "needs-a-human: the rest of the section must stay"
    git -C "$M" -c user.email=t@t -c user.name=t add -A; git -C "$M" -c user.email=t@t -c user.name=t commit -qm up
    out="$(bash "$UPGRADE" "$M" 2>&1)"
    grep -q '^OK: AGENTS.md Needs-a-human line is current' <<< "$out" || fail "needs-a-human: second run should be OK"
  else
    grep -q '^TODO: AGENTS.md "Needs a human" section was edited' <<< "$out" || fail "needs-a-human: edited section needs a TODO"
    grep -qx 'Ask Bob before: deploy.' "$M/AGENTS.md" || fail "needs-a-human: an edited section must not be touched"
  fi
done

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
echo "$out" | grep -q '^OK: open features declare effort' || fail "upgrade: a passing feature without effort needs no TODO (M36-001)"
echo "$out" | grep -q '^OK: open features declare model' || fail "upgrade: a passing feature without model needs no TODO (M36-002)"
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
# 4c. read rule (M38-003): inserted right under "## Rules", once
RR="$WORK/readrule"; mkdir -p "$RR"
git -C "$RR" init -q -b main
printf '{ "milestones": {"1":"C"}, "features": [] }\n' > "$RR/FEATURES.json"
printf '# PROGRESS\n' > "$RR/PROGRESS.md"
# shellcheck disable=SC2016 # literal backticks
printf '# A\nharness-run\n\n## Rules\n\n- FIRST rule.\n\n## Needs a human\n\nNever act; stop as `blocked`, set your feature to `deferred` with notes `Needs a human: <question>`, before:\n' > "$RR/AGENTS.md"
git -C "$RR" -c user.email=t@t -c user.name=t add -A; git -C "$RR" -c user.email=t@t -c user.name=t commit -qm seed
bash "$UPGRADE" "$RR" >/dev/null 2>&1 || fail "read rule: expected exit 0"
[ "$(sed -n '/^## Rules$/{n;n;p;}' "$RR/AGENTS.md")" = "$(grep -m1 '^- Read rule:' skills/harness-initial-setup/templates/AGENTS.md.tmpl)" ] \
  || fail "read rule: must be the first bullet under ## Rules"
grep -qx -- '- FIRST rule.' "$RR/AGENTS.md" || fail "read rule: existing rules must stay"
git -C "$RR" -c user.email=t@t -c user.name=t add -A; git -C "$RR" -c user.email=t@t -c user.name=t commit -qm up
out="$(bash "$UPGRADE" "$RR" 2>&1)" || fail "read rule second run: expected exit 0"
echo "$out" | grep -q '^OK: AGENTS.md has the read rule' || fail "read rule: second run should be OK"
[ "$(grep -c 'Read rule:' "$RR/AGENTS.md")" -eq 1 ] || fail "read rule: inserted twice"

# 4d. feature-work scope (M40-001): paragraph right under "## Session loop",
#     the two unedited "every session" lines reworded, once; no heading → TODO
FW="$WORK/featurework"; mkdir -p "$FW"
git -C "$FW" init -q -b main
printf '{ "milestones": {"1":"C"}, "features": [] }\n' > "$FW/FEATURES.json"
printf '# PROGRESS\n' > "$FW/PROGRESS.md"
# shellcheck disable=SC2016 # literal backticks
printf '# A\n\nManual: read it before your\nfirst session. This file is only the map.\n\n## Session loop (summary — full version in the protocol doc)\n\n1. Read `git log -20`.\n\nharness-run\n\n## Rules\n\n- Every session starts and ends green (`scripts/e2e.sh`).\n' > "$FW/AGENTS.md"
git -C "$FW" -c user.email=t@t -c user.name=t add -A; git -C "$FW" -c user.email=t@t -c user.name=t commit -qm seed
out="$(bash "$UPGRADE" "$FW" 2>&1)" || fail "feature work: expected exit 0 (got: $out)"
echo "$out" | grep -q '^CHANGED: AGENTS.md (session loop scoped to feature work' || fail "feature work: change not reported"
[ "$(sed -n '/^## Session loop/{n;n;p;}' "$FW/AGENTS.md")" = "$(grep -m1 '^Feature work only:' skills/harness-initial-setup/templates/AGENTS.md.tmpl)" ] \
  || fail "feature work: paragraph must sit right under the ## Session loop heading"
# shellcheck disable=SC2016 # literal backticks
# (the M41-001 skip line, 3 lines, now sits between them)
[ "$(grep -A4 'always apply\.$' "$FW/AGENTS.md" | tail -1)" = '1. Read `git log -20`.' ] || fail "feature work: session steps must follow the paragraph"
grep -qxF 'first feature session. This file is only the map.' "$FW/AGENTS.md" || fail "feature work: 'first session' line not reworded"
# shellcheck disable=SC2016 # literal backticks
grep -qxF -- '- Every feature session starts and ends green (`scripts/e2e.sh`).' "$FW/AGENTS.md" || fail "feature work: gate rule not reworded"
git -C "$FW" -c user.email=t@t -c user.name=t add -A; git -C "$FW" -c user.email=t@t -c user.name=t commit -qm up
out="$(bash "$UPGRADE" "$FW" 2>&1)" || fail "feature work second run: expected exit 0"
echo "$out" | grep -q '^OK: AGENTS.md scopes the session loop to feature work' || fail "feature work: second run should be OK"
[ "$(grep -c '^Feature work only:' "$FW/AGENTS.md")" -eq 1 ] || fail "feature work: inserted twice"
NH="$WORK/noloop"; mkdir -p "$NH"
git -C "$NH" init -q -b main
printf '{ "milestones": {"1":"C"}, "features": [] }\n' > "$NH/FEATURES.json"
printf '# PROGRESS\n' > "$NH/PROGRESS.md"
printf '# A\nharness-run\n' > "$NH/AGENTS.md"
git -C "$NH" -c user.email=t@t -c user.name=t add -A; git -C "$NH" -c user.email=t@t -c user.name=t commit -qm seed
out="$(bash "$UPGRADE" "$NH" 2>&1)" || fail "feature work no loop: expected exit 0"
echo "$out" | grep -q '^TODO: AGENTS.md has no "## Session loop" section' || fail "feature work: missing heading needs a TODO"
! grep -q '^Feature work only:' "$NH/AGENTS.md" || fail "feature work: must not guess where to insert without a heading"

# 4e. plugin-less agents (M41-001): the kit's one-line CLAUDE.md pointer becomes
#     the @AGENTS.md import; a custom CLAUDE.md keeps its text under the import;
#     AGENTS.md gets the declaration, the skip line and the plugin rewording, once
TPL="skills/harness-initial-setup/templates"
PL="$WORK/pluginless"; mkdir -p "$PL"
git -C "$PL" init -q -b main
printf '{ "milestones": {"1":"C"}, "features": [] }\n' > "$PL/FEATURES.json"
printf '# PROGRESS\n' > "$PL/PROGRESS.md"
printf 'See [AGENTS.md](AGENTS.md) — the single agent entry point for this repository.\n' > "$PL/CLAUDE.md"
printf '# GEMINI.md\n\nSee AGENTS.md for everything.\n' > "$PL/GEMINI.md"
# a 3.16.0 AGENTS.md: the template with the old declaration and plugin paragraph
cp scripts/fixtures/agents-3.16.0.md "$PL/AGENTS.md"
git -C "$PL" -c user.email=t@t -c user.name=t add -A; git -C "$PL" -c user.email=t@t -c user.name=t commit -qm seed
out="$(bash "$UPGRADE" "$PL" 2>&1)" || fail "plugin-less: expected exit 0 (got: $out)"
cmp -s "$TPL/pointer.md.tmpl" "$PL/CLAUDE.md" || fail "plugin-less: kit pointer CLAUDE.md must become the template import"
[ "$(head -1 "$PL/GEMINI.md")" = '@AGENTS.md' ] || fail "plugin-less: custom GEMINI.md must start with @AGENTS.md"
grep -qxF 'See AGENTS.md for everything.' "$PL/GEMINI.md" || fail "plugin-less: custom GEMINI.md text must be kept"
grep -qF 'long-running-agent harness, plugin or' "$PL/AGENTS.md" || fail "plugin-less: declaration not reworded"
! grep -qxF 'This repository is operated with the long-running-agent harness. The full' "$PL/AGENTS.md" || fail "plugin-less: old declaration left behind"
grep -qF 'just build it' "$PL/AGENTS.md" || fail "plugin-less: skip line missing"
[ "$(grep -A1 'always apply\.$' "$PL/AGENTS.md" | tail -1)" = "$(grep '^If the human says to skip the harness' "$TPL/AGENTS.md.tmpl")" ] || fail "plugin-less: skip line must follow the feature-work paragraph"
grep -qF 'These steps are the protocol, plugin or not.' "$PL/AGENTS.md" || fail "plugin-less: plugin paragraph not reworded"
! grep -qF 'fallback when it is not installed' "$PL/AGENTS.md" || fail "plugin-less: old fallback wording left behind"
# an upgraded template-shaped AGENTS.md matches the new template
sed -e 's/{{[A-Z_]*}}//g' "$TPL/AGENTS.md.tmpl" > "$WORK/want.md"; sed -e 's/{{[A-Z_]*}}//g' "$PL/AGENTS.md" > "$WORK/got.md"
cmp -s "$WORK/want.md" "$WORK/got.md" || fail "plugin-less: upgraded 3.16.0 AGENTS.md must equal the current template ($(diff "$WORK/want.md" "$WORK/got.md" | head -5))"
git -C "$PL" -c user.email=t@t -c user.name=t add -A; git -C "$PL" -c user.email=t@t -c user.name=t commit -qm up
out="$(bash "$UPGRADE" "$PL" 2>&1)" || fail "plugin-less second run: expected exit 0"
for w in 'OK: CLAUDE.md imports AGENTS.md' 'OK: GEMINI.md imports AGENTS.md' 'OK: AGENTS.md declares the harness, plugin or not' 'OK: AGENTS.md says how to skip the harness' 'OK: AGENTS.md treats the plugin as an accelerator'; do
  echo "$out" | grep -qF "$w" || fail "plugin-less second run: '$w' missing"
done
[ -z "$(git -C "$PL" status --short)" ] || fail "plugin-less: second run must change nothing"
# a hand-written AGENTS.md (no declaration, no template lines): declaration under the title
HW="$WORK/handwritten"; mkdir -p "$HW"
git -C "$HW" init -q -b main
printf '{ "milestones": {"1":"C"}, "features": [] }\n' > "$HW/FEATURES.json"
printf '# PROGRESS\n' > "$HW/PROGRESS.md"
printf '# AGENTS.md — App\n\nContext for agents.\n\n## Session loop\nFeature work only: x. Rules and Needs a human always apply.\n**Start:**\n\nharness-run\n' > "$HW/AGENTS.md"
git -C "$HW" -c user.email=t@t -c user.name=t add -A; git -C "$HW" -c user.email=t@t -c user.name=t commit -qm seed
out="$(bash "$UPGRADE" "$HW" 2>&1)" || fail "hand-written: expected exit 0 (got: $out)"
[ "$(sed -n 3p "$HW/AGENTS.md")" = "$(grep -m1 'long-running-agent harness, plugin or' "$TPL/AGENTS.md.tmpl")" ] || fail "hand-written: declaration must sit under the title"
! grep -qF 'only the map' "$HW/AGENTS.md" || fail "hand-written: a custom AGENTS.md is not 'only the map'"
grep -qF 'Context for agents.' "$HW/AGENTS.md" || fail "hand-written: text must be kept"
grep -qF 'just build it' "$HW/AGENTS.md" || fail "hand-written: skip line missing"
[ "$(head -1 "$HW/CLAUDE.md")" = '@AGENTS.md' ] || fail "hand-written: missing CLAUDE.md must be created as the import"
[ ! -e "$HW/GEMINI.md" ] || fail "hand-written: GEMINI.md must not be created"

sess="skills/harness-session/SKILL.md"
grep -q 'harness-upgrade-structure' "$sess" || fail "harness-session SKILL.md: UPGRADE: offer must point at harness-upgrade-structure"
! grep -q 'recopy the shipped' "$sess" || fail "harness-session SKILL.md: upgrade steps must not be duplicated inline"

echo "UPGRADE TESTS GREEN"
