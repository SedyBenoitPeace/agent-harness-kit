# M38: lean worker reads

**Goal:** cut what builders read at start and per file. A 30-day review of
Codex and Copilot sessions found reading files and agent docs was 47%
(Codex) and 65% (Copilot) of all carried tool output: workers re-loaded
SKILL.md, AGENTS.md and the protocol at start (~4.6k tokens each), re-read
FEATURES.json, PROGRESS.md and the active plan in big chunks, and Codex
read whole files (64% of its read cost came from outputs ≥5k tokens).
Agents follow tools more reliably than prose, so each fix is a script
output or a one-line rule in the files a session already sees.

## M38-001 — context.sh --brief: the protocol card

- New protocol §2.9 (`harness-protocol-runs.md`, since the core is at its
  150-line limit): one card with what a dispatched session needs — one
  feature, read rule, baseline/final gate, test first, quiet.sh, untrusted
  text, close-out, lanes, Needs a human, budget, results file, SESSION line.
- `context.sh --brief` prints `== Session protocol ==`: `SCRIPTS:` (where
  run-gate.sh and quiet.sh are), the card's bullets, then the repo's own
  AGENTS.md `## Rules` and `## Needs a human` sections (≤40 lines each).
  It prints `PLAN_SECTION: in your brief` instead of repeating the plan.
- The builder agent source (so every CLI's generated builder) and
  harness-session SKILL.md: a briefed session runs `context.sh --brief` and
  does not cat SKILL.md, AGENTS.md, `docs/agents/`, FEATURES.json or the plan.

## M38-002 — feature.sh and the brief

- `skills/harness-run/scripts/feature.sh <id> [target]`: the FEATURES.json
  entry (pretty JSON) and the `## ` plan section naming the id, cut at 80
  lines with a note. Exit 2 on no id or an unknown one.
- harness-run step 3 dispatches "Run one harness session for <id>, inline.
  Start with `context.sh --brief` … End with the SESSION line." followed by
  feature.sh's output. Lanes use the same brief. harness-continuous reuses
  step 3, so it inherits this.
- Claude Code edition: `BUILDER_PROMPT` accepts "harness session for" and
  "harness-session for", so the model hook still finds the id when the
  brief pastes other ids (depends_on) below it.

## M38-003 — read rule

- "`grep -n` first, then `sed -n` ≤80 lines; never `cat` a source file over
  200 lines." in protocol §2.1 and §2.9, the AGENTS.md template and this
  repo's AGENTS.md (Rules), harness-session SKILL.md and the builder agent.
- upgrade.sh inserts the template's line as the first bullet under
  `## Rules` (appends it when there is no such heading), once.

## Decision log

- 2026-10-27 (owner, via the cost report): findings 2, 3, 4 and C2 here;
  finding 5 (Copilot builder custom agents) is a separate change.
- Card in `harness-protocol-runs.md`, not the core: the core is at its
  150-line limit (M28-003) and only dispatched sessions need the card.
- `--brief` is a flag, not the default: the orchestrator runs context.sh
  every loop and must not carry the card each time.
- The card is read from the shipped template, not the repo's copy, so it
  always matches the scripts that print it.
- The prompt drops "Use harness-session": on Claude Code that phrase loads
  the skill (the 7.6 KB SKILL.md the brief is meant to replace).
