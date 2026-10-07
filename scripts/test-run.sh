#!/usr/bin/env bash
# Proves the harness-continuous SKILL.md contract (M20-002) and that
# harness-run stays interactive. Exit 0 = green.
set -euo pipefail
cd "$(dirname "$0")/.."
fail() { echo "RUN TEST FAIL: $*" >&2; exit 1; }

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
printf '2026-03-04T10:30:00Z agent-3: 1600000 tokens over the 1500000 budget; run asked to stop after this feature\n' > "$R/.harness-run/budget.log"
(cd "$R" && bash "$REPORT" "$START" --skip "$WORK/skip" --stop-reason "budget") >/dev/null || fail "run-report with signals: expected exit 0"
sed -n '/^## Supervisor/,/^## /p' "$rep" | grep -q '^- M1-001 — boot: no test for an empty config; unicode names unchecked$' \
  || fail "run-report: Supervisor must list M1-001's skipped work"
sed -n '/^## Budget/,/^## /p' "$rep" | grep -q 'agent-3: 1600000 tokens over the 1500000 budget' || fail "run-report: Budget must carry budget.log"
rm -rf "$R/.harness-run"

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
# feature or skip, not since unrelated commits); tokens from tokens.log
jq '(.features[] | select(.id=="M2-001") | .status) = "passing"' "$R/FEATURES.json" > "$R/f.tmp" && mv "$R/f.tmp" "$R/FEATURES.json"
g add FEATURES.json
GIT_COMMITTER_DATE="2026-03-04T10:25:00+0000" GIT_AUTHOR_DATE="2026-03-04T10:25:00+0000" g commit -qm "feat(M2-001): extras"
mkdir -p "$R/.harness-run"; printf '*\n' > "$R/.harness-run/.gitignore"
printf 'M2-001 410000\n' > "$R/.harness-run/tokens.log"
rep="$R/$(cd "$R" && bash "$REPORT" "$START" --skip "$WORK/skip" --stop-reason "cap")" || fail "run-report with timings: expected exit 0"
sed -n '/^## Done/,/^## /p' "$rep" | grep -Eq '^- M2-001 — extras — [0-9a-f]{7,} — 25 min, 410000 tokens$' || fail "run-report: M2-001 must show 25 min and its tokens"
sed -n '/^## Done/,/^## /p' "$rep" | grep -Eq '^- M1-001 — boot — [0-9a-f]{7,} — 0 min$' || fail "run-report: M1-001 must show its minutes and no tokens"
rm -rf "$R/.harness-run"

# bad start commit: usage error, exit 2
rc=0; (cd "$R" && bash "$REPORT" nope >/dev/null 2>&1) || rc=$?
[ "$rc" -eq 2 ] || fail "run-report: unknown start commit should exit 2, got $rc"

echo "RUN TESTS GREEN"
