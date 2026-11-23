#!/usr/bin/env bash
# Proves the harness-continuous SKILL.md contract (M20-002) and that
# harness-run stays interactive. Exit 0 = green.
# shellcheck disable=SC2016 # literal $ amounts in report fixtures
set -euo pipefail
cd "$(dirname "$0")/.."
fail() { echo "RUN TEST FAIL: $*" >&2; exit 1; }
t() { echo "-- $1"; }
export HARNESS_BOARD_OPEN=0 # run-start.sh must never open a fixture's run board (M47-001)

md="skills/harness-continuous/SKILL.md"
run="skills/harness-run/SKILL.md"
[ -f "$md" ] || fail "harness-continuous SKILL.md missing"

# valid, agent-neutral frontmatter; the skill itself is the command (no trigger word)
[ "$(head -1 "$md")" = "---" ] || fail "SKILL.md: missing frontmatter"
grep -q '^name: harness-continuous$' "$md" || fail "SKILL.md: frontmatter name wrong"
grep -q '^description: ' "$md" || fail "SKILL.md: description missing"
grep -q '^description: .*invoked by name' "$md" || fail "SKILL.md: description must say it starts only when invoked by name"
! grep -qi 'claude' "$md" || fail "SKILL.md must be agent-neutral"
! grep -qiE 'overnight|night|unattended mode|--yolo|--dangerously|--allow-all' "$md" \
  || fail "SKILL.md: no trigger words or skip-all-permissions flags"

# never asks; run state lives in a normal, git-ignored folder (agents cannot write under .git/)
grep -qi 'never asks the human' "$md" || fail "SKILL.md: never-asks rule missing"
! grep -q '\.git/harness-run' "$md" || fail "SKILL.md: run state must not live under .git/"
for f in skip STOP start; do
  grep -q "\.harness-run/$f" "$md" || fail "SKILL.md: .harness-run/$f state file missing"
done
grep -q 'git check-ignore' "$md" || fail "SKILL.md: must check the state folder is git-ignored"
grep -q '\.gitignore' "$md" || fail "SKILL.md: .gitignore handling missing"
grep -qi 'cannot run' "$md" || fail "SKILL.md: run-report.sh failure fallback missing"

# skip, don't stop: stash, note with a question, commit FEATURES.json only, loop with --skip
grep -q 'git stash push -u' "$md" || fail "SKILL.md: leftover changes must be stashed, never discarded"
grep -q "Question for the human" "$md" || fail "SKILL.md: skip note must carry one question"
grep -qi 'FEATURES.json only' "$md" || fail "SKILL.md: skip commit must touch FEATURES.json only"
grep -q 'status.sh --skip' "$md" || fail "SKILL.md: loop must select with status.sh --skip"
grep -q 'context.sh --skip' "$md" || fail "SKILL.md: loop must read context with context.sh --skip"
for w in 'blocked' 'gate is red' 'NEEDS_WORK'; do
  grep -q "$w" "$md" || fail "SKILL.md: skip trigger missing: $w"
done
grep -qi 'twice' "$md" || fail "SKILL.md: NEEDS_WORK twice rule missing"

# M32-001: the End step runs the CLI's usage collector before the report
grep -q 'usage-<cli>.sh' "$md" || fail "SKILL.md: End must run the CLI usage collector"

# stop conditions
for w in 'NEXT: none' 'cap' 'default 10' 'baseline problem' 'PREFLIGHT' 'UPGRADE: offer' 'neither a commit nor a'; do
  grep -qi "$w" "$md" || fail "SKILL.md: stop condition missing: $w"
done

# milestone boundary: stop by default, cross only for a named range, stacked branches, no push
grep -q 'through M' "$md" || fail "SKILL.md: milestone range ('through M<n>') missing"
grep -qi 'stacked' "$md" || fail "SKILL.md: stacked milestone branches missing"
grep -qi 'never push' "$md" || fail "SKILL.md: never-push rule missing"

# reuses harness-run by reference, adds only the continuous rules
grep -q 'harness-run' "$md" || fail "SKILL.md: must reference harness-run"
grep -q 'harness-builder' "$md" || fail "SKILL.md: dispatch must name harness-builder"
grep -qi 'own tools only' "$md" || fail "SKILL.md: own-tools-only rule missing"
grep -q 'run-report.sh' "$md" || fail "SKILL.md: final run report step missing"

# harness-run stays interactive and unchanged, and points here
grep -q 'harness-continuous' "$run" || fail "harness-run SKILL.md: must point to harness-continuous"
grep -q 'Stop at the milestone boundary' "$run" || fail "harness-run SKILL.md: interactive milestone stop changed"
grep -q 'relay the subagent' "$run" || fail "harness-run SKILL.md: interactive relay-and-STOP changed"
grep -q 'Do not retry or fix it yourself' "$run" || fail "harness-run SKILL.md: interactive stop-on-blocked changed"

# --- run-report.sh (M20-003) ---------------------------------------------------

REPORT="$PWD/skills/harness-run/scripts/run-report.sh"
[ -f "$REPORT" ] || fail "run-report.sh missing"
! grep -qE 'curl|wget|claude |codex |copilot ' "$REPORT" || fail "run-report.sh: no network or model calls"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
R="$WORK/repo"
mkdir -p "$R"
g() { git -C "$R" -c user.email=t@t -c user.name=t "$@"; }
export GIT_COMMITTER_DATE="2026-03-04T10:00:00+0000" GIT_AUTHOR_DATE="2026-03-04T10:00:00+0000"
git -C "$R" init -q -b main
cat > "$R/FEATURES.json" <<'JSON'
{
  "milestones": { "1": "Core", "2": "Extras" },
  "features": [
    { "id": "M1-001", "milestone": 1, "title": "boot", "status": "failing", "verify": "x" },
    { "id": "M1-002", "milestone": 1, "title": "parser", "status": "failing", "verify": "x", "depends_on": [] },
    { "id": "M1-003", "milestone": 1, "title": "formatter", "status": "failing", "verify": "x", "depends_on": ["M1-002"] },
    { "id": "M2-001", "milestone": 2, "title": "extras", "status": "failing", "verify": "x", "depends_on": ["M1-001"] }
  ]
}
JSON
printf '# PROGRESS\n\n## 2026-03-01 -- session 1\n- Setup.\n' > "$R/PROGRESS.md"
g add -A; g commit -qm "seed"
START="$(git -C "$R" rev-parse HEAD)"

# the run: M1-001 passes, M1-002 is skipped with a recorded question
jq '(.features[] | select(.id=="M1-001") | .status) = "passing"' "$R/FEATURES.json" > "$R/f.tmp" && mv "$R/f.tmp" "$R/FEATURES.json"
printf '# PROGRESS\n\n## 2026-03-04 -- session 2 (M1-001)\n- Done: M1-001 boot.\n- Decisions: rejected a config file (env vars suffice);\n  assumed UTF-8 input.\n- Gate: green.\n\n## 2026-03-01 -- session 1\n- Setup.\n' > "$R/PROGRESS.md"
g add FEATURES.json PROGRESS.md; g commit -qm "feat(M1-001): boot"
echo wip > "$R/wip.txt"; g add wip.txt; g stash push -q -u -m "harness-run skip M1-002"
jq '(.features[] | select(.id=="M1-002") | .notes) = "Unattended 2026-03-04: skipped — gate red on parser tests. Question for the human: which date formats must the parser accept?"' "$R/FEATURES.json" > "$R/f.tmp" && mv "$R/f.tmp" "$R/FEATURES.json"
g add FEATURES.json; g commit -qm "harness-run: skip M1-002"
printf 'M1-002\n' > "$WORK/skip"

out="$(cd "$R" && bash "$REPORT" "$START" --skip "$WORK/skip" --stop-reason "cap reached (3)")" \
  || fail "run-report: expected exit 0"
[ "$out" = "docs/runs/2026-03-04-1000.md" ] || fail "run-report: printed path should be docs/runs/<HEAD date>.md, got '$out'"
rep="$R/$out"
[ -f "$rep" ] || fail "run-report: report file not written"
for sec in Summary Done Skipped 'Not started' Branches; do
  grep -q "^## $sec\$" "$rep" || fail "run-report: section '$sec' missing"
done
grep -q 'cap reached (3)' "$rep" || fail "run-report: stop reason missing"
sed -n '/^## Done/,/^## Skipped/p' "$rep" | grep -Eq '^- M1-001 — boot — [0-9a-f]{7,}' || fail "run-report: Done must list M1-001 with title and commit"
sed -n '/^## Skipped/,/^## Not started/p' "$rep" | grep -q 'M1-002.*gate red on parser tests' || fail "run-report: Skipped must carry the reason"
sed -n '/^## Skipped/,/^## Not started/p' "$rep" | grep -q 'which date formats must the parser accept?' || fail "run-report: Skipped must carry the question"
sed -n '/^## Skipped/,/^## Not started/p' "$rep" | grep -q 'stash@{0}' || fail "run-report: Skipped must point at the stash"
sed -n '/^## Not started/,/^## Branches/p' "$rep" | grep -q 'M1-003.*depends on M1-002' || fail "run-report: Not started must explain the skipped dependency"
sed -n '/^## Not started/,/^## Branches/p' "$rep" | grep -q 'M2-001.*cap reached (3)' || fail "run-report: Not started must carry the stop reason"
sed -n '/^## Branches/,$p' "$rep" | grep -q 'main' || fail "run-report: Branches must name the current branch"
grep -Eq '^- Start: [0-9a-f]{7} \(2026-03-04 10:00\)$' "$rep" || fail "run-report: Start line malformed"
grep -Eq '^- End: [0-9a-f]{7} \(2026-03-04 10:00\)$' "$rep" || fail "run-report: End line malformed"
grep -Eq 'done 1.*skipped 1.*not started 2' "$rep" || fail "run-report: Summary counts wrong"

# deterministic for a fixed repo state
cp "$rep" "$WORK/first.md"
out2="$(cd "$R" && bash "$REPORT" "$START" --skip "$WORK/skip" --stop-reason "cap reached (3)")"
[ "$out2" = "$out" ] || fail "run-report: path not deterministic"
cmp -s "$rep" "$WORK/first.md" || fail "run-report: output not deterministic"

# M27-003: each done feature carries its Decisions: line (continuation lines
# joined); no Supervisor or Budget section without their files
sed -n '/^## Done/,/^## Skipped/p' "$rep" | grep -q '^  - Decisions: rejected a config file (env vars suffice); assumed UTF-8 input.$' \
  || fail "run-report: Done must carry M1-001's Decisions: line"
grep -q '^## Supervisor' "$rep" && fail "run-report: no Supervisor section without skipped-work files"
grep -q '^## Budget' "$rep" && fail "run-report: no Budget section without budget.log"
mkdir -p "$R/.harness-run/decisions"
printf '*\n' > "$R/.harness-run/.gitignore"
printf '# Supervisor: work M1-001 may have skipped\n\n- no test for an empty config\n- unicode names unchecked\n' > "$R/.harness-run/decisions/M1-001.skipped.md"
printf '2026-03-04T10:30:00Z feature M1-001: $5.40 over the $5.00 budget; run asked to stop after this feature\n' > "$R/.harness-run/budget.log"
(cd "$R" && bash "$REPORT" "$START" --skip "$WORK/skip" --stop-reason "budget") >/dev/null || fail "run-report with signals: expected exit 0"
sed -n '/^## Supervisor/,/^## /p' "$rep" | grep -q '^- M1-001 — boot: no test for an empty config; unicode names unchecked$' \
  || fail "run-report: Supervisor must list M1-001's skipped work"
sed -n '/^## Budget/,/^## /p' "$rep" | grep -qF 'feature M1-001: $5.40 over the $5.00 budget' || fail "run-report: Budget must carry budget.log"
rm -rf "$R/.harness-run"

# M34-003: Decisions come from the feature's own commit body, else the
# PROGRESS entry whose Done: line names it; a planning entry that only
# mentions the ids never counts
R2="$WORK/repo2"; mkdir -p "$R2"
g2() { git -C "$R2" -c user.email=t@t -c user.name=t "$@"; }
git -C "$R2" init -q -b main
cat > "$R2/FEATURES.json" <<'JSON'
{ "milestones": { "1": "Core" }, "features": [
  { "id": "M1-001", "milestone": 1, "title": "boot", "status": "failing", "verify": "x" },
  { "id": "M1-002", "milestone": 1, "title": "parser", "status": "failing", "verify": "x" } ] }
JSON
printf '# PROGRESS\n\n## 2026-03-01 -- session 1\n- Setup.\n' > "$R2/PROGRESS.md"
g2 add -A; g2 commit -qm "seed"
START2="$(git -C "$R2" rev-parse HEAD)"
printf '# PROGRESS\n\n## 2026-03-02 -- planning (M1-001, M1-002)\n- Done: planned M1-001 and M1-002.\n- Decisions: PLANNING-ONLY text.\n\n## 2026-03-01 -- session 1\n- Setup.\n' > "$R2/PROGRESS.md"
g2 add PROGRESS.md; g2 commit -qm "plan M1-001 M1-002"
jq '(.features[] | select(.id=="M1-001") | .status) = "passing"' "$R2/FEATURES.json" > "$R2/f.tmp" && mv "$R2/f.tmp" "$R2/FEATURES.json"
g2 add FEATURES.json; g2 commit -qm "lane: M1-001 boot" -m "Decisions: rejected a plugin system; assumed LF endings."
jq '(.features[] | select(.id=="M1-002") | .status) = "passing"' "$R2/FEATURES.json" > "$R2/f.tmp" && mv "$R2/f.tmp" "$R2/FEATURES.json"
printf '# PROGRESS\n\n## 2026-03-04 -- session 3 (M1-002)\n- Done: M1-002 parser.\n- Decisions: none.\n\n## 2026-03-02 -- planning (M1-001, M1-002)\n- Done: planned M1-001 and M1-002.\n- Decisions: PLANNING-ONLY text.\n' > "$R2/PROGRESS.md"
g2 add FEATURES.json PROGRESS.md; g2 commit -qm "feat(M1-002): parser"
rep2="$R2/$(cd "$R2" && bash "$REPORT" "$START2" --stop-reason "finished")" || fail "run-report M34-003: expected exit 0"
grep -q 'PLANNING-ONLY' "$rep2" && fail "run-report: a planning entry's Decisions must never be used"
grep -qF -- '  - Decisions: rejected a plugin system; assumed LF endings.' "$rep2" || fail "run-report: M1-001 must take Decisions from its commit body"
grep -qF -- '  - Decisions: none.' "$rep2" || fail "run-report: M1-002 must take Decisions from the entry whose Done: names it"

# M35-001: PROGRESS appended oldest-first, a planning entry whose Done: line
# names the id, and the feature landing as a lane merge: Decisions come from
# the entry the done commit (merge: against its first parent) added
R4="$WORK/repo4"; mkdir -p "$R4"
g4() { git -C "$R4" -c user.email=t@t -c user.name=t "$@"; }
git -C "$R4" init -q -b main
printf '{ "milestones": { "1": "Core" }, "features": [\n  { "id": "M1-001", "milestone": 1, "title": "boot", "status": "failing", "verify": "x" } ] }\n' > "$R4/FEATURES.json"
printf '# PROGRESS\n\n## 2026-03-01 -- session 1\n- Setup.\n' > "$R4/PROGRESS.md"
g4 add -A; g4 commit -qm "seed"
START4="$(git -C "$R4" rev-parse HEAD)"
printf '\n## 2026-03-02 -- planning\n- Done: planned M1-001.\n- Decisions: PLAN-APPEND text.\n' >> "$R4/PROGRESS.md"
g4 add PROGRESS.md; g4 commit -qm "plan"
g4 checkout -q -b lane/M1-001
jq '(.features[] | select(.id=="M1-001") | .status) = "passing"' "$R4/FEATURES.json" > "$R4/f.tmp" && mv "$R4/f.tmp" "$R4/FEATURES.json"
printf '\n## 2026-03-03 -- session 2\n- Done: M1-001 boot.\n- Decisions: LANE-ENTRY text.\n' >> "$R4/PROGRESS.md"
g4 add FEATURES.json PROGRESS.md; g4 commit -qm "boot"
g4 checkout -q main; g4 merge -q --no-ff lane/M1-001 -m "Merge lane/M1-001"
rep4="$R4/$(cd "$R4" && bash "$REPORT" "$START4" --stop-reason "finished")" || fail "run-report M35-001: expected exit 0"
grep -q 'PLAN-APPEND' "$rep4" && fail "run-report: a planning entry (append order) must never give a feature its Decisions"
grep -qF -- '  - Decisions: LANE-ENTRY text.' "$rep4" || fail "run-report: a lane merge must take Decisions from the entry the lane added"

# M34-010: harness-continuous End archives after the report; a report built
# after the archive still titles the archived ids
end="$(sed -n '/^## End/,/^## Red flags/p' "$md")"
rl="$(grep -n 'run-report.sh' <<< "$end" | head -1 | cut -d: -f1 || true)"
al="$(grep -n 'archive-features.sh' <<< "$end" | head -1 | cut -d: -f1 || true)"
[ -n "$al" ] || fail "SKILL.md: End must run archive-features.sh"
[ "$al" -gt "${rl:-0}" ] || fail "SKILL.md: End must archive after the report"
grep -q 'docs/features-archive.json' <<< "$end" || fail "SKILL.md: End must commit docs/features-archive.json"
R3="$WORK/repo3"; cp -R "$R2" "$R3"
(cd "$R3" && bash "$OLDPWD/skills/harness-status/scripts/archive-features.sh" . >/dev/null) || fail "archive in a report fixture failed"
git -C "$R3" -c user.email=t@t -c user.name=t add FEATURES.json docs/features-archive.json
git -C "$R3" -c user.email=t@t -c user.name=t commit -qm "harness-continuous: archive M1"
jq -e '.features | length == 0' "$R3/FEATURES.json" >/dev/null || fail "archive: M1 should have left FEATURES.json"
rep3="$R3/$(cd "$R3" && bash "$REPORT" "$START2" --stop-reason "finished")" || fail "run-report after archive: expected exit 0"
sed -n '/^## Done/,/^## /p' "$rep3" | grep -Eq '^- M1-001 — boot — [0-9a-f]{7,}' || fail "run-report: an archived id must keep its title"
sed -n '/^## Done/,/^## /p' "$rep3" | grep -Eq '^- M1-002 — parser — [0-9a-f]{7,}' || fail "run-report: an archived id must keep its title (M1-002)"

# M29-002: features waiting on a human get their own section with the
# question, and the features they hold are explained under Not started
grep -q '^## Waiting on a human' "$rep" && fail "run-report: no Waiting section when nothing waits"
jq '.features += [
  {"id": "M2-002", "milestone": 2, "title": "deploy", "status": "deferred", "verify": "x", "notes": "Needs a human: who approves the deploy?"},
  {"id": "M2-003", "milestone": 2, "title": "smoke", "status": "failing", "verify": "x", "depends_on": ["M2-002"]}]' \
  "$R/FEATURES.json" > "$R/f.tmp" && mv "$R/f.tmp" "$R/FEATURES.json"
g add FEATURES.json; g commit -qm "plan: deploy waits on a human"
rep="$R/$(cd "$R" && bash "$REPORT" "$START" --skip "$WORK/skip" --stop-reason "cap")" || fail "run-report with a waiting feature: expected exit 0"
sed -n '/^## Waiting on a human/,/^## /p' "$rep" | grep -q '^- M2-002 — who approves the deploy?$' || fail "run-report: Waiting on a human must list M2-002 with its question"
sed -n '/^## Not started/,/^## /p' "$rep" | grep -q 'M2-003.*held — depends on M2-002, which waits on a human' || fail "run-report: a held feature must say why"

# M29-003: minutes per done feature from commit times (since the previous
# feature or skip, not since unrelated commits); dollars summed over each
# builder session in cost.log, the model and any step-up from models.log
jq '(.features[] | select(.id=="M2-001") | .status) = "passing"' "$R/FEATURES.json" > "$R/f.tmp" && mv "$R/f.tmp" "$R/FEATURES.json"
g add FEATURES.json
GIT_COMMITTER_DATE="2026-03-04T10:25:00+0000" GIT_AUTHOR_DATE="2026-03-04T10:25:00+0000" g commit -qm "feat(M2-001): extras"
mkdir -p "$R/.harness-run"; printf '*\n' > "$R/.harness-run/.gitignore"
printf 'M2-001 0.4000\nM2-001 1.0300\n' > "$R/.harness-run/cost.log"
printf 'M2-001 haiku effort low\nM2-001 sonnet effort low, +1\n' > "$R/.harness-run/models.log"
rep="$R/$(cd "$R" && bash "$REPORT" "$START" --skip "$WORK/skip" --stop-reason "cap")" || fail "run-report with timings: expected exit 0"
sed -n '/^## Done/,/^## /p' "$rep" | grep -Eq '^- M2-001 — extras — [0-9a-f]{7,} — 25 min, \$1\.43, sonnet \(stepped up from haiku\)$' || fail "run-report: M2-001 must show 25 min, its dollars and the step-up"
sed -n '/^## Done/,/^## /p' "$rep" | grep -Eq '^- M1-001 — boot — [0-9a-f]{7,} — 0 min$' || fail "run-report: M1-001 must show its minutes and no tokens"
grep -q '^- Cost: ' "$rep" && fail "run-report: no Cost line without run-cost"
sed -n '/^## Summary/,/^## /p' "$rep" | grep -qF -- '- Cost by model: sonnet $1.43 (1 feature)' || fail "run-report: Summary must split feature dollars by model"

# M31-001: the run's total split into feature agents and orchestration
printf 'agents 9.0000\norchestration 1.0000\n' > "$R/.harness-run/run-cost"
rep="$R/$(cd "$R" && bash "$REPORT" "$START" --skip "$WORK/skip" --stop-reason "cap")" || fail "run-report with run-cost: expected exit 0"
sed -n '/^## Summary/,/^## /p' "$rep" | grep -qF -- '- Cost: $10.00 — feature agents $9.00, orchestration $1.00 (10%)' \
  || fail "run-report: Summary must split the run's cost into agents and orchestration"

# M32-001: tokens from usage.log — per done feature, run total split into
# feature agents and orchestration, per model; nothing without the file
printf 'M2-001 claude sonnet 100000 80000 20000\nM2-001 claude sonnet 50000 40000 5000\norchestration claude opus 1000000 900000 50000\n' > "$R/.harness-run/usage.log"
rep="$R/$(cd "$R" && bash "$REPORT" "$START" --skip "$WORK/skip" --stop-reason "cap")" || fail "run-report with usage.log: expected exit 0"
sed -n '/^## Done/,/^## /p' "$rep" | grep -Eq '^- M2-001 — extras — .*, 175k tok \(in 150k, cached 120k, out 25k\)$' || fail "run-report: M2-001 must show its summed tokens"
sed -n '/^## Done/,/^## /p' "$rep" | grep -Eq '^- M1-001 — boot — [0-9a-f]{7,} — 0 min$' || fail "run-report: a feature without usage lines shows no tokens"
sed -n '/^## Summary/,/^## /p' "$rep" | grep -qF -- '- Tokens: 1.2M — feature agents 175k, orchestration 1.1M' || fail "run-report: Summary must split tokens into agents and orchestration"
sed -n '/^## Summary/,/^## /p' "$rep" | grep -qF -- '- Cost by model: sonnet $1.43, 175k tok (1 feature), opus 1.1M tok' || fail "run-report: Cost by model must carry tokens"
cp "$rep" "$WORK/usage-first.md"
rep="$R/$(cd "$R" && bash "$REPORT" "$START" --skip "$WORK/skip" --stop-reason "cap")"
cmp -s "$rep" "$WORK/usage-first.md" || fail "run-report: output with usage.log not deterministic"
rm "$R/.harness-run/cost.log" "$R/.harness-run/models.log" "$R/.harness-run/run-cost"
rep="$R/$(cd "$R" && bash "$REPORT" "$START" --skip "$WORK/skip" --stop-reason "cap")"
sed -n '/^## Summary/,/^## /p' "$rep" | grep -qF -- '- Tokens by model: opus 1.1M tok, sonnet 175k tok' || fail "run-report: Tokens by model without cost.log"
rm "$R/.harness-run/usage.log"
rep="$R/$(cd "$R" && bash "$REPORT" "$START" --skip "$WORK/skip" --stop-reason "cap")"
grep -q 'tok' "$rep" && fail "run-report: no token lines without usage.log"
rm -rf "$R/.harness-run"

# bad start commit: usage error, exit 2
rc=0; (cd "$R" && bash "$REPORT" nope >/dev/null 2>&1) || rc=$?
[ "$rc" -eq 2 ] || fail "run-report: unknown start commit should exit 2, got $rc"

# --- M33-004: dispatch by size, models.log on every CLI, retry steps up -------
DISPATCH="$PWD/skills/harness-run/scripts/dispatch.sh"
[ -f "$DISPATCH" ] || fail "dispatch.sh missing"
D="$WORK/disp"; mkdir -p "$D/.codex/agents" "$D/.claude/agents"
cat > "$D/FEATURES.json" <<'JSON'
{"features":[{"id":"S-1","model":"small"},{"id":"S-2","model":"large"},{"id":"S-3"},{"id":"S-4","model":"haiku"}]}
JSON
for z in small medium large; do : > "$D/.codex/agents/harness-builder-$z.toml"; : > "$D/.claude/agents/harness-builder-$z.md"; done
disp() { bash "$DISPATCH" "$D" "$@" | tr '\n' ' '; }
# M39-001: no builder agent file for the CLI → AGENT: missing, exit 3, no log line
for c in codex copilot claude; do
  rc=0; out="$(bash "$DISPATCH" "$D" "$c" S-1 2>/dev/null)" || rc=$?
  if [ "$rc" -ne 3 ] || [ "$out" != "AGENT: missing" ]; then
    fail "dispatch: $c without harness-builder must print AGENT: missing and exit 3 (got $rc: $out)"
  fi
done
[ -f "$D/.harness-run/models.log" ] && fail "dispatch: a missing agent must not log a model"
mkdir -p "$D/.github/agents"
: > "$D/.codex/agents/harness-builder.toml"; : > "$D/.claude/agents/harness-builder.md"; : > "$D/.github/agents/harness-builder.agent.md"
[ "$(disp codex S-1)" = "AGENT: harness-builder-small SIZE: small SPAWN: fork_turns=none " ] || fail "dispatch: small -> harness-builder-small"
[ "$(disp codex S-1 1)" = "AGENT: harness-builder-medium SIZE: medium SPAWN: fork_turns=none " ] || fail "dispatch: retry steps small up to medium"
[ "$(disp codex S-2 1)" = "AGENT: harness-builder-large SIZE: large SPAWN: fork_turns=none " ] || fail "dispatch: retry caps at large"
[ "$(disp codex S-3)" = "AGENT: harness-builder-medium SIZE: medium SPAWN: fork_turns=none " ] || fail "dispatch: no model -> medium on codex"
[ "$(disp codex S-4)" = "AGENT: harness-builder-medium SIZE: medium SPAWN: fork_turns=none " ] || fail "dispatch: another CLI's alias -> medium"
[ "$(disp copilot S-1)" = "AGENT: harness-builder SIZE: small " ] || fail "dispatch: no sized file -> harness-builder"
[ "$(disp claude S-3)" = "AGENT: harness-builder SIZE: - " ] || fail "dispatch: claude without a size keeps the hook (harness-builder)"
[ "$(disp claude S-1)" = "AGENT: harness-builder-small SIZE: small " ] || fail "dispatch: claude small -> harness-builder-small"
[ "$(cat "$D/.harness-run/models.log")" = "$(printf 'S-1 small model small\nS-1 medium model small, +1\nS-2 large model large, +1\nS-3 medium model medium\nS-4 medium model medium\nS-1 small model small')" ] \
  || fail "dispatch: models.log lines wrong: $(cat "$D/.harness-run/models.log")"
rc=0; bash "$DISPATCH" "$D" nope S-1 >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 2 ] || fail "dispatch: unknown cli should exit 2, got $rc"
for f in "$run" "$md"; do
  grep -q 'dispatch.sh' "$f" || fail "$f: must dispatch through dispatch.sh"
done
# M44-001: Codex subagents start fresh, not as a fork of the orchestrator
grep -q '^SPAWN: fork_turns=none' <<< "$(bash "$DISPATCH" "$D" codex S-1)" || fail "dispatch: codex must print SPAWN: fork_turns=none"
grep -q 'SPAWN' <<< "$(bash "$DISPATCH" "$D" copilot S-1)$(bash "$DISPATCH" "$D" claude S-1)" && fail "dispatch: SPAWN is a codex-only line"
[ "$(grep -c 'fork_turns: "none"' "$run")" -ge 2 ] || fail "$run: builders and the evaluator must spawn with fork_turns none on Codex (M44-001)"
grep -q 'fork_turns: "none"' skills/harness-brief/SKILL.md || fail "harness-brief: the reviewer must spawn with fork_turns none on Codex (M44-001)"
grep -q "open no" "$run" || fail "$run: the orchestrator must not open other skills' SKILL.md (M44-001)"
grep -q 'models.log' "$run" || fail "harness-run SKILL.md: models.log step missing"
grep -qi 'next size up' "$run" || fail "harness-run SKILL.md: retry step-up missing"

# --- run-start.sh (M34-002): each run starts with clean run state ----------------
START_SH="$PWD/skills/harness-run/scripts/run-start.sh"
[ -f "$START_SH" ] || fail "run-start.sh missing"
grep -q 'run-start.sh' "$md" || fail "harness-continuous Start must call run-start.sh"
R5="$WORK/repo5"; mkdir -p "$R5"
g5() { git -C "$R5" -c user.email=t@t -c user.name=t "$@"; }
git -C "$R5" init -q -b main
# run-start.sh commits on its own: give the fixture an identity (CI has none)
g5 config user.email t@t; g5 config user.name t
jq '(.features[] | select(.status == "failing")) |= (.depends_on //= [] | .paths //= ["src/\(.id)"])' "$R/FEATURES.json" > "$R5/FEATURES.json" # M65-001: run-start refuses entries without them
printf '# PROGRESS\n' > "$R5/PROGRESS.md"
g5 add -A; g5 commit -qm seed
bash "$START_SH" "$R5" >/dev/null || fail "run-start: first run failed"
first="$(git -C "$R5" rev-parse HEAD)"
[ "$(cat "$R5/.harness-run/start")" = "$first" ] || fail "run-start: start should be HEAD"
git -C "$R5" check-ignore -q .harness-run || fail "run-start: .harness-run not ignored"
[ -z "$(git -C "$R5" status --short)" ] || fail "run-start: tree must be clean after (ignore rule committed)"
cd "$R5/.harness-run"
printf 'M1-001 9.99\n' > cost.log; printf 'a 1\n' > run-cost; printf 'M1-001 small model small\n' > models.log
printf 's c m 1 2 3\n' > usage.log; printf 'budget x\n' > budget.log; mkdir decisions; echo d > decisions/M1-001.md; mkdir results
echo M1-002 > skip; echo M1-003 > busy; touch STOP
mkdir hints; echo "keep me" > hints/M1-002.md
rm run-id # a run from before M47-001: its archive falls back to its start commit
cd "$OLDPWD"
g5 commit -q --allow-empty -m "run 1 work"
second="$(git -C "$R5" rev-parse HEAD)"
bash "$START_SH" "$R5" >/dev/null || fail "run-start: second run failed"
[ "$(cat "$R5/.harness-run/start")" = "$second" ] || fail "run-start: second start should be new HEAD"
[ ! -s "$R5/.harness-run/skip" ] || fail "run-start: skip must be empty"
[ -e "$R5/.harness-run/busy" ] || fail "run-start: busy must exist (M46-001)"
[ ! -s "$R5/.harness-run/busy" ] || fail "run-start: busy must be empty (M46-001)"
[ ! -e "$R5/.harness-run/STOP" ] || fail "run-start: stale STOP must be removed"
[ "$(cat "$R5/.harness-run/hints/M1-002.md" 2>/dev/null)" = "keep me" ] || fail "run-start: hints/ must be kept (M49-001)"
for f in cost.log run-cost models.log usage.log budget.log decisions results; do
  [ ! -e "$R5/.harness-run/$f" ] || fail "run-start: $f not moved out of the live run"
  [ -e "$R5/.harness-run/previous/$first/$f" ] || fail "run-start: $f not archived under previous/<first start>"
done
(cd "$R5" && bash "$REPORT" "$second" --stop-reason x >/dev/null) || fail "run-start: report after second start failed"
! grep -rq '9.99' "$R5/docs/runs" || fail "run-start: report shows the first run's cost"

# M46-001: rolling lanes in harness-run, reused by harness-continuous
RUN_MD="skills/harness-run/SKILL.md"
grep -q 'context.sh --busy .harness-run/busy' "$RUN_MD" || fail "harness-run: refill must call context.sh --busy"
grep -q 'Lanes roll' "$RUN_MD" || fail "harness-run: lanes must roll, not wait for a batch"
grep -q 'inside the lane' "$RUN_MD" || fail "harness-run: lane evaluator must run inside the lane worktree"
grep -q 'one writer' "$RUN_MD" || fail "harness-run: no sequential feature while lanes are busy"
grep -q 'rolling Parallel lanes' "$md" || fail "harness-continuous: must reuse rolling lanes"
grep -q 'ORIG_HEAD' "$md" || fail "harness-continuous: a red lane merge must be undone before skipping"

# M34-007: wait-result.sh blocks in the shell, prints the result file once, silent while waiting
WAIT="skills/harness-run/scripts/wait-result.sh"
[ -f "$WAIT" ] || fail "wait-result.sh missing"
W="$(mktemp -d)"; mkdir -p "$W/.harness-run/results"
( cd "$W"; sleep 2; printf 'SESSION: X-1 · passing · gate green · abc\nsummary\n' > .harness-run/results/X-1.tmp; mv .harness-run/results/X-1.tmp .harness-run/results/X-1.txt ) &
t0=$(date +%s)
out="$(cd "$W" && bash "$OLDPWD/$WAIT" X-1 --timeout 20 2>&1)" || fail "wait-result: should exit 0 once the file appears"
t1=$(date +%s)
[ "$((t1 - t0))" -lt 10 ] || fail "wait-result: did not return soon after the file appeared"
[ "$out" = "$(printf 'SESSION: X-1 · passing · gate green · abc\nsummary')" ] || fail "wait-result: output must be exactly the result file (nothing while waiting)"
wait
if (cd "$W" && bash "$OLDPWD/$WAIT" X-2 --timeout 2 >"$W/o" 2>/dev/null); then fail "wait-result: timeout must exit non-zero"; fi
[ ! -s "$W/o" ] || fail "wait-result: no stdout on timeout"
rm -rf "$W"

# feature.sh (M38-002): one feature entry and its plan section, for the brief
FEAT="skills/harness-run/scripts/feature.sh"
W="$(mktemp -d)"
mkdir -p "$W/docs/plans/active"
printf '{"milestones":{"1":"A"},"features":[{"id":"M1-001","milestone":1,"title":"one","status":"passing","verify":"V1"},{"id":"M1-002","milestone":1,"title":"two","status":"failing","verify":"V2","depends_on":["M1-001"]}]}\n' > "$W/FEATURES.json"
{ printf '# Plan\n\nINTRO\n\n## M1-001 one\n- SECTION1\n\n## M1-002 two\n- SECTION2\n'; } > "$W/docs/plans/active/m1.md"
out="$(bash "$FEAT" M1-002 "$W")" || fail "feature.sh: expected exit 0"
for w in '== Feature M1-002 ==' '"verify": "V2"' '"M1-001"' 'PLAN: docs/plans/active/m1.md' '## M1-002 two' SECTION2; do
  echo "$out" | grep -qF -- "$w" || fail "feature.sh: missing $w"
done
if echo "$out" | grep -qE 'SECTION1|INTRO|V1'; then fail "feature.sh: leaked another feature or plan section"; fi
rc=0; bash "$FEAT" M9-999 "$W" >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 2 ] || fail "feature.sh: unknown id must exit 2"
rc=0; bash "$FEAT" >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 2 ] || fail "feature.sh: no id must exit 2"
# hints (M49-001): printed after the plan section only when the file is non-empty
! echo "$out" | grep -qF '== Human hint ==' || fail "feature.sh: no hint file, no hint section"
mkdir -p "$W/.harness-run/hints"; : > "$W/.harness-run/hints/M1-002.md"
! bash "$FEAT" M1-002 "$W" | grep -qF '== Human hint ==' || fail "feature.sh: empty hint file must print nothing"
printf 'use the v2 parser\nnot the regex\n' > "$W/.harness-run/hints/M1-002.md"
out="$(bash "$FEAT" M1-002 "$W")"
echo "$out" | grep -qxF '== Human hint ==' || fail "feature.sh: non-empty hint must print '== Human hint =='"
echo "$out" | grep -qxF 'not the regex' || fail "feature.sh: hint text missing"
echo "$out" | awk '/^== Human hint ==/{h=NR} /^== Plan section ==/{p=NR} END{exit !(h>p && p>0)}' || fail "feature.sh: hint must come after the plan section"
! bash "$FEAT" M1-001 "$W" | grep -qF '== Human hint ==' || fail "feature.sh: another feature's hint leaked"
t "M66-001.1 builder prompt is complete and has no placeholder @critical"
for lane in inline ../repo-M1-002; do
  lane_args=()
  if [ "$lane" != inline ]; then lane_args=(--lane "$lane"); fi
  prompt="$(bash "$FEAT" M1-002 "$W" --prompt builder ${lane_args[@]+"${lane_args[@]}"})" || fail "feature.sh: builder prompt failed"
  for w in 'You are the harness builder.' 'Run one harness session for M1-002' '== Feature M1-002 ==' '"verify": "V2"' '## M1-002 two' SECTION2 'not the regex'; do
    grep -qF -- "$w" <<< "$prompt" || fail "feature.sh: builder prompt missing $w"
  done
  context="$(sed -n 's/.*bash \(\/[^ ]*\/context\.sh\) --brief.*/\1/p' <<< "$prompt")"
  [ -f "$context" ] || fail "feature.sh: builder prompt must name an absolute existing context.sh"
  if grep -qE '^name: harness-builder$|^---$|<[^>]+>|PLACEHOLDER' <<< "$prompt"; then
    fail "feature.sh: builder prompt contains frontmatter or an unfilled placeholder"
  fi
  if [ "$lane" != inline ]; then
    grep -qF -- "$lane" <<< "$prompt" || fail "feature.sh: builder prompt missing lane directory"
    grep -qF 'lane/M1-002' <<< "$prompt" || fail "feature.sh: builder prompt missing lane branch"
  elif grep -qF 'lane/M1-002' <<< "$prompt"; then
    fail "feature.sh: inline builder prompt contains a lane clause"
  fi
done
t "M66-001.2 evaluator prompt carries role, entry and range @critical"
prompt="$(bash "$FEAT" M1-002 "$W" --prompt evaluator --range a1..b2)" || fail "feature.sh: evaluator prompt failed"
for w in 'You are the harness evaluator.' '== Feature M1-002 ==' '"verify": "V2"' 'Commit range: a1..b2'; do
  grep -qF -- "$w" <<< "$prompt" || fail "feature.sh: evaluator prompt missing $w"
done
if grep -qE '^name: harness-evaluator$|^---$|SECTION2|== Human hint ==' <<< "$prompt"; then
  fail "feature.sh: evaluator prompt contains frontmatter, plan or hint"
fi
for role in evaluator unknown; do
  rc=0; bash "$FEAT" M1-002 "$W" --prompt "$role" >/dev/null 2>&1 || rc=$?
  [ "$rc" -eq 2 ] || fail "feature.sh: expected usage error for --prompt $role without --range"
done
t "M66-001.3 without --prompt the output is unchanged @critical"
bash "$FEAT" M1-002 "$W" > "$W/brief.actual" || fail "feature.sh: default brief failed"
# Pre-M66 stdout, including blank lines and the final newline.
cmp -s "$W/brief.actual" - <<'BRIEF' || fail "feature.sh: default brief changed"
== Feature M1-002 ==
{
  "id": "M1-002",
  "milestone": 1,
  "title": "two",
  "status": "failing",
  "verify": "V2",
  "depends_on": [
    "M1-001"
  ]
}

== Plan section ==
PLAN: docs/plans/active/m1.md
## M1-002 two
- SECTION2

== Human hint ==
use the v2 parser
not the regex
BRIEF
rm "$W/docs/plans/active/m1.md" "$W/.harness-run/hints/M1-002.md" # (grep -q under pipefail would SIGPIPE on later output)
bash "$FEAT" M1-002 "$W" | grep -q '^PLAN: no section naming M1-002' || fail "feature.sh: missing plan must say so"
{ printf '## M1-002 long\n'; seq 1 120; } > "$W/docs/plans/active/long.md"
out="$(bash "$FEAT" M1-002 "$W")"
echo "$out" | grep -q 'section cut at 80 of 121 lines' || fail "feature.sh: long section must be cut at 80 with a note"
if echo "$out" | grep -qx 100; then fail "feature.sh: printed past the 80-line cap"; fi
rm -rf "$W"
grep -q '\.harness-run/STOP' "$run" || fail "harness-run SKILL.md must name .harness-run/STOP (M49-001)"
# the brief replaces the plan path and the skill/AGENTS.md reads
grep -qF 'bash scripts/feature.sh <id> <target>' "$run" || fail "harness-run SKILL.md: brief must paste feature.sh output"
grep -qF 'context.sh --brief' "$run" || fail "harness-run SKILL.md: brief must start the builder with context.sh --brief"
grep -qF "never the plan's path" "$run" || fail "harness-run SKILL.md: brief must not pass the plan path"
grep -qF 'do not cat SKILL.md, AGENTS.md' "$run" || fail "harness-run SKILL.md: brief must tell the builder not to cat SKILL.md/AGENTS.md"
grep -qF 'harness session for <id>' "$run" || fail "harness-run SKILL.md: brief must keep 'harness session for <id>' (Claude edition hook parses it)"

# M60-003: a Needs-a-human item becomes scripts/wizard-<id>.sh (idea from Matt Pocock's `wizard` skill)
t "M60-003.1 wizard generated for a blocked feature @critical"
WIZ="skills/harness-run/scripts/wizard.sh"
W="$(mktemp -d)"
cat > "$W/FEATURES.json" <<'JSON'
{"features":[{"id":"M1-001","status":"deferred","notes":"Needs a human: add STRIPE_KEY secret"}]}
JSON
STRIPE_KEY=sk_test_FAKEVALUE123456 bash "$WIZ" "$W" M1-001 --check 'test -n "${STRIPE_KEY:-}"' >/dev/null || fail "wizard.sh: generation failed"
wf="$W/scripts/wizard-M1-001.sh"
[ -f "$wf" ] || fail "wizard.sh: scripts/wizard-M1-001.sh not written"
bash -n "$wf" || fail "wizard: does not pass bash -n"
grep -qF 'add STRIPE_KEY secret' "$wf" || fail "wizard: the Needs-a-human note must be a step"
! grep -qE 'sk_test_|FAKEVALUE' "$wf" || fail "wizard: holds a secret value"
out="$(printf '\n' | STRIPE_KEY=x bash "$wf" 2>&1)" || fail "wizard: check failed with STRIPE_KEY set: $out"
echo "$out" | grep -qF 'Step 1 of 1: add STRIPE_KEY secret' || fail "wizard: must prompt the step"
echo "$out" | tail -1 | grep -qF 'WIZARD M1-001: DONE' || fail "wizard: must end with the check passing"
if printf '\n' | env -u STRIPE_KEY bash "$wf" >/dev/null 2>&1; then fail "wizard: check must fail without STRIPE_KEY"; fi
# several steps: one prompt each, in order, then the check (default: the gate)
bash "$WIZ" "$W" M1-001 'open the dashboard' "create the key (it's under API keys & tokens)" >/dev/null
bash -n "$wf" || fail "wizard: a step with a quote or & breaks bash -n"
out="$(printf '\n\n' | bash "$wf" 2>&1 || true)"
echo "$out" | awk '/Step 1 of 2: open the dashboard/{a=NR} /Step 2 of 2: create the key/{b=NR} /Checking: bash scripts\/e2e.sh/{c=NR} END{exit !(a && a<b && b<c)}' \
  || fail "wizard: steps must prompt one by one, then run the check: $out"
echo "$out" | grep -qF "create the key (it's under API keys & tokens)" || fail "wizard: a quoted step must print as written"
if bash "$WIZ" "$W" M1-001 'paste sk_live_abcdef12345678' >/dev/null 2>&1; then fail "wizard.sh: must refuse a step holding a secret value"; fi
if bash "$WIZ" "$W" M9-999 >/dev/null 2>&1; then fail "wizard.sh: unknown id with no steps must fail"; fi
rm -rf "$W"
grep -qF 'scripts/wizard.sh' "$run" || fail "harness-run SKILL.md: must name scripts/wizard.sh (M60-003)"
grep -qF 'Before the run' "$run" || fail "harness-run SKILL.md: wizard must cover a plan's Before the run items"

t "M66-002.1 SKILL.md states the cross-provider rule and its fallback @critical"
sec="$(awk '/^## Children on other providers/{on=1; next} /^## /{on=0} on' "$run")"
[ -n "$sec" ] || fail "harness-run SKILL.md: no 'Children on other providers' section (M66-002)"
for w in 'other than its own' 'never a model' 'VIA: <provider>' '--providers' 'Effort comes from the size' \
  '--prompt builder' 'dropped for the rest of the run' 'Workflow step 3, unchanged'; do
  printf '%s\n' "$sec" | tr '\n' ' ' | tr -s ' ' | grep -qF -- "$w" || fail "harness-run SKILL.md cross-provider section: missing '$w' (M66-002)"
done
t "M66-002.2 no model name in the kit's run docs"
! grep -nE '\b(claude-[a-z]+-[0-9]|gpt-[0-9]|gemini-[0-9])' "$run" skills/harness-continuous/SKILL.md \
  || fail "harness-run/continuous SKILL.md: a model id is named (M66-002: provider only)"
t "M66-003.1 Evaluator step names the other-provider rule and its fallback @critical"
ev="$(awk '/^## Evaluator step/{on=1; next} /^## /{on=0} on' "$run" | tr '\n' ' ' | tr -s ' ')"
for w in 'provider other than the builder' '--prompt evaluator' 'one provider or none' 'Integrity check'; do
  printf '%s\n' "$ev" | grep -qF -- "$w" || fail "harness-run Evaluator step: missing '$w' (M66-003)"
done

echo "RUN TESTS GREEN"
