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

# never asks; run state lives in .git/harness-run/
grep -qi 'never asks the human' "$md" || fail "SKILL.md: never-asks rule missing"
for f in skip STOP start; do
  grep -q "\.git/harness-run/$f" "$md" || fail "SKILL.md: .git/harness-run/$f state file missing"
done

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

echo "RUN TESTS GREEN"
