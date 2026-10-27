# M40: the session loop is for feature work only

**Goal:** an agent asked to move a file, format, or make an ordinary doc
edit does the task, checks that one result and stops, instead of running
context recovery, the gate and the feature workflow.

## Evidence

In a repo scaffolded from the kit, Codex was asked to move an HTML guide to
another folder. It ran the full coding-session protocol, and said it had
classified the file move as a "coding session". AGENTS.md (read natively by
Codex and Copilot CLI, and by Claude Code through the CLAUDE.md pointer) had
an unconditional Session loop and the rule "Every session starts and ends
green"; protocol §2 said "Run this every working session".

## M40-001 — scope the loop, keep the rules universal

- AGENTS.md.tmpl: a paragraph under `## Session loop`. Feature work is a
  FEATURES.json entry or plan task (or work needing one), a change to what
  the product does, or an edit to agent instructions. Anything else is a
  small task: do it, check that one result (grep a moved path; run the gate
  once if code, tests, scripts or CI/build config change), stop; if it proves
  to be feature work, stop and say so. Rules and Needs a human always apply.
- "every session" → "feature session" in AGENTS.md.tmpl (2 lines), protocol
  §2 (2 places) and e2e.sh.tmpl. Caps hold: AGENTS.md.tmpl 70/70, core 150/150.
- upgrade.sh: insert the paragraph under `## Session loop` once; reword the
  two lines only when unedited; TODO when the heading is missing.
- Verify: e2e.sh asserts; test-upgrade.sh case 4d.

## Decision log

- 2026-10-27: classify by what the change touches, not by its label: the
  agent picks the label, and a move can break links, an AGENTS.md edit changes
  agent behaviour, a CI tweak can break the gate.
- Config tweaks run the gate once, not the loop: better evidence, not wider scope.
- No red-gate line for small tasks: they never reach §2.3.
- Owner's phrase "Depth means better evidence, not wider scope" not added
  verbatim: the check step carries it and AGENTS.md.tmpl is at its cap.
