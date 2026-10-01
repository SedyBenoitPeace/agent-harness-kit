> **For agentic workers:** each task below is one harness coding session.
> Run it with the harness-session skill if it is installed; otherwise
> follow docs/agents/harness-protocol.md section 2. Do not load any other
> workflow skill or plugin to execute this plan.

# M19: harness-brief — turn a rough prompt into an unambiguous brief

**Goal:** Before planning, a skill checks the human's rough prompt and
turns it into a structured brief a stranger could build from without
asking anything. Planning then starts from the brief and only asks
about gaps. Released as plugin 1.10.0.

**Why:** Unattended runs fail on ambiguity nobody is awake to resolve.
Resolving it costs one short conversation up front; discovering it
overnight costs a wasted run.

## M19-001 — harness-brief skill and deterministic brief check

- `skills/harness-brief/SKILL.md`: runs interactively in the main
  session (it must ask questions, so it is a skill, not a subagent).
  Asks at most three questions, only about real ambiguities, then
  writes `docs/briefs/<date>-<slug>.md` from `templates/brief.md.tmpl`.
- Brief sections: Objective (one sentence) · Context (repo, files, what
  exists) · Deliverables · Non-goals · Done when (each line a command
  and its expected result) · Quality bar (fetchable reference, or
  "gate is sufficient") · Needs a human (actions the run must stop
  for) · Budget and stop condition · Open questions (must be empty).
- Before saving, the skill applies the stranger test: could someone
  build this without asking anything? If not, it asks instead of
  saving.
- `skills/harness-brief/scripts/check-brief.sh`: exits non-zero when a
  section is missing, Open questions is non-empty, or a Done-when line
  contains no command (no backticked command).
- Gate (scripts/test-brief.sh): good fixture passes; each defect
  fixture (missing section, open question, vague done-when) fails with
  its own FAIL line; SKILL.md frontmatter valid and agent-neutral.

## M19-002 — Independent brief reviewer agent

- New neutral source `agents/src/harness-brief-reviewer.md`, generated
  for all three CLIs by M18-001's gen-agents.sh. Read-only.
- Input: only the brief file — never the conversation that produced it,
  so it reads the brief the way a stranger (or a builder at 3am) would.
- Output: first line exactly `READY` or `GAPS`, then numbered gaps
  (ambiguous wording, a Done-when that cannot be run, a missing
  non-goal, a Needs-a-human item the plan would hit).
- harness-brief dispatches it after writing the brief. GAPS → the skill
  asks the human about them and revises. After 2 review rounds it stops
  and shows the remaining gaps to the human instead of looping.
- Gate: gen-agents.sh emits the reviewer in all three formats,
  read-only; SKILL.md names the dispatch, the verdict contract and the
  2-round stop.

## M19-003 — Planning consumes the brief; needs-a-human list; release 1.10.0

- Protocol §1.1 gains "Already have a brief?": read it, extract answers,
  interview only the gaps (mirrors the existing PRD rule). Its Done-when
  lines seed `verify`; its Quality bar seeds `evaluate`/`bar`.
- AGENTS.md.tmpl gains a short "Needs a human" section (defaults:
  deploy or publish; push to main or merge; production data or
  migrations; adding dependencies; auth/permission code changes;
  deleting or renumbering features). Hitting one means: mark the
  feature blocked with a question, never act.
- README lifecycle: brief → plan → run. Versions 1.10.0.

## Decision log

- 2026-09-28 — A skill, not an agent: subagents return a result at the
  end and cannot pause to ask the human.
- 2026-09-28 — Owner decision: the skill talks with the human, and a
  separate read-only reviewer agent checks the finished brief
  independently (M19-002). It depends on M18-001's generator.
- 2026-09-28 — The needs-a-human list is taken from the "Project
  constraints" an agent wrote unprompted in a harnessed repo; making it a template
  section gives every repo the same boundary vocabulary.
- 2026-09-28 — Prompt-level guardrails are advisory. Enforcement lives
  in the gate, the evaluator (M18) and each CLI's permission settings.
