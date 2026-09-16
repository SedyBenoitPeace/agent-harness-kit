# M16: Native planning and execution modes — Implementation Plan

**Goal:** The protocol and skills tell any agent to plan with its own
native plan mode and to execute a session either inline (default) or
delegated to its own built-in subagents — never by loading a third-party
planning/execution-workflow plugin. Released as plugin 1.7.0.

**Why:** Field evidence — a Copilot CLI session in a harnessed repo
followed a plan header (`REQUIRED SUB-SKILL: superpowers:subagent-driven-development`)
written by an external planning skill. It loaded ~800 lines of process
text up front, ran 16 subagent round-trips for 7 tasks in one session,
and ran the raw gate three times. None of that came from this harness,
but nothing in the harness prevented it. The one-feature-per-session
model and the `run-gate.sh` wrapper were bypassed entirely.

## Tasks

### M16-001 (gate-first): native plan mode + execution-mode choice
- Gate: protocol greps `native plan mode`, `Execution mode`,
  `own built-in`; harness-setup SKILL.md grep `native plan mode`;
  harness-session SKILL.md grep `delegated`; README grep
  `native plan mode`; `skills/` and README must not mention the
  third-party plugin by name.
- Protocol §1.5: write plans with the agent's native plan mode; no plan
  header may mandate an external skill; task sections headed by feature
  id and self-contained so a session reads only its own section.
- Protocol §2.4: "Execution mode" — propose inline (default) or delegated
  (agent's own subagent/task tool, one task section + verify criterion
  each, summaries only in the main context); own tools only.
- harness-setup SKILL.md step 2 + red flag; harness-session SKILL.md
  step 6 + red flag; AGENTS.md.tmpl step 4; README lifecycle step 2.
- Version bump to 1.7.0 (plugin caches are version-keyed).

## Decision log

- 2026-09-16 — Kept the `### 2.4 Implement, test-first` heading and added
  an "Execution mode" paragraph under it, rather than renaming: existing
  cross-references and greps depend on the heading.
- 2026-09-16 — Completed plans keep their historical `REQUIRED SUB-SKILL`
  headers; `docs/plans/active/` is empty, and rewriting history is out of
  scope for the protocol.
- 2026-09-16 — Enforced mechanically (gate greps a plugin name out of
  `skills/` and README) rather than by doc alone, per §3.4.
