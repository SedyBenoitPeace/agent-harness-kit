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

### M16-002 (gate-first): bounded gate output by construction
- `e2e.sh.tmpl`: `step <name> "<cmd>"` wrapper — full output to a log
  named as `FULL_LOG`, one line per passing step, log tail on the first
  failing step; `GATE_VERBOSE=1` streams, `GATE_TAIL` sizes the tail.
- harness-audit: WARN when `scripts/e2e.sh` has no `FULL_LOG` marker.
- Protocol §1.6 gate contract gains the bounded-output bullet; retrofit
  wraps existing test commands in `step`.
- Gate: substitute-and-run the template green (≤10 lines, FULL_LOG) and
  red (300 noisy lines → ≤70 printed, all retained in the log);
  test-audit fixture for the WARN.

### M16-003: plans route every task through a harness session
- Protocol §1.5 ships a verbatim plan header: each task is one harness
  coding session, harness-session if installed, else §2, never another
  workflow skill. AGENTS.md.tmpl names harness-session as the entry
  point. harness-session description triggers on "execution plan".

### M16-004: show-me for explanations and summaries
- Protocol §2, AGENTS.md.tmpl rule, harness-status relay step: use the
  `show-me` skill if installed; otherwise short prose. README credits
  HumanLayer's post.

### M16-005: notice an older scaffold after a plugin update
- `context.sh` gains `== Harness upgrade ==`: `GATE_OUTPUT`
  (bounded / unbounded / no scripts/e2e.sh), `PROTOCOL` (current /
  outdated vs the shipped copy, with plugin version / missing), and
  `UPGRADE: offer|none`. harness-session step 2 offers the upgrade once,
  as its own commit, human decides. README documents it under the update
  command. Fixture tests in `test-session.sh`.

## Decision log

- 2026-09-16 — Kept the `### 2.4 Implement, test-first` heading and added
  an "Execution mode" paragraph under it, rather than renaming: existing
  cross-references and greps depend on the heading.
- 2026-09-16 — Completed plans keep their historical `REQUIRED SUB-SKILL`
  headers; `docs/plans/active/` is empty, and rewriting history is out of
  scope for the protocol.
- 2026-09-16 — Enforced mechanically (gate greps a plugin name out of
  `skills/` and README) rather than by doc alone, per §3.4.
- 2026-09-16 — Bounded the target repo's own gate instead of relying on
  `run-gate.sh`: the wrapper only helps when harness-session is the path
  taken, and the Copilot session showed that cannot be assumed.
  `run-gate.sh` stays for legacy gates.
- 2026-09-16 — `step` runs commands via `bash -c "<string>"` so pipes and
  `&&` chains work; a command containing double quotes must be escaped
  when substituting the placeholder.
- 2026-09-16 — This repo's own `scripts/e2e.sh` was not converted to the
  `step` wrapper: its output is already ~10 lines. Revisit if it grows.
- 2026-09-16 — Three features in one session, at the owner's request;
  deviation from the one-feature rule noted in PROGRESS.md.
