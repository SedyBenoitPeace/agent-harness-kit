# M45: effort optional again

**Goal:** a feature without `effort` is valid; the builder runs at its CLI's
default effort and the model decides per step how hard to think.

**Why:** M36-001 made effort required on every open feature. In a 31-subagent
run the levels were passed correctly but nothing showed they changed the
outcome, while every plan had to pick a level per feature. The owner chose
the model's own judgment as the default.

## M45-001

- check.sh: drop the missing-effort FAIL; an unknown value still FAILs.
- upgrade.sh + harness-upgrade-structure SKILL.md: drop the effort TODO.
- FEATURES.json.tmpl: first feature carries no effort; `_instructions` says optional.
- Protocol 1.4: absent = the CLI's default effort; set a level only to override.
  1.1: the brief's Stage seeds an override, not a level for every feature.
- harness-session SKILL.md, README, ARCHITECTURE: wording.
- Unchanged: status.sh, harness-run and gen-agents.sh honour an explicit level.
- Verify: test-audit.sh, test-upgrade.sh and e2e.sh (see FEATURES.json).
