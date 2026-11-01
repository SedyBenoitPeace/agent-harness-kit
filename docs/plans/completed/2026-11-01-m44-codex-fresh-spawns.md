# M44: Codex subagents start fresh, reads stay one per command

**Goal:** on Codex, a builder, evaluator or brief reviewer starts from its
brief, not from the orchestrator's history, and no read output is a chain of
several files.

## Evidence (one private week of Codex runs on kit 3.16, numbers only)

- Reading files plus skills and agent docs carried 79M tokens in a week,
  about 3x the earlier weekly rate; Copilot on 3.15+ fell to 10.3M.
- Every subagent the kit dispatched in one run (8 builders, 4 evaluators,
  1 brief reviewer, 1 worker) was a full-history fork: its log opens with
  the parent's session and ~120 tool calls with their outputs; one
  evaluator's first prompt was 377k tokens, 14 forks 6.0M on first prompts
  alone. Codex 0.164 `spawn_agent` forks the whole history when
  `fork_turns` is omitted; the kit never set it. Full forks also inherit
  the parent's model and effort, so sized builder agents were ignored.
- Forks also carried the parent's 5-day-old user instructions, so 28
  subagents re-read the human's personal context file after it had
  changed.
- In the two largest sessions, 10 of 12 and 12 of 12 top read items were
  one command with 3+ reads (`sed …; sed …; rg …`), 6–10k tokens each:
  every range obeyed "≤80 lines", the output did not.
- The orchestrator opened unrelated skills' SKILL.md (~10k each).

## M44-001

- `dispatch.sh` prints `SPAWN: fork_turns=none` on Codex; harness-run
  passes `fork_turns: "none"` to every spawn (builders, evaluators, lanes);
  harness-brief does the same for the reviewer. Orchestrator opens no other
  skill's SKILL.md.
- Read rule gains "one read per command, never chained" everywhere it
  lives (protocol §2.1 and §2.9, AGENTS.md and template, harness-session,
  builder agents, README). upgrade.sh replaces the unedited 3.15 line;
  an edited line is kept.
- Tests: test-run.sh (SPAWN line codex-only, SKILL wording),
  test-agents.sh, test-upgrade.sh (old line upgraded once, edited line
  kept), e2e.sh (rule wording in every file).
