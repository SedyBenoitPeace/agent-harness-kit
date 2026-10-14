> **For agentic workers:** each task below is one harness coding session.
> Run it with the harness-session skill if it is installed; otherwise
> follow docs/agents/harness-protocol.md section 2. Do not load any other
> workflow skill or plugin to execute this plan.

# M31: Orchestration cost in the run report

**Goal:** a run report says what the whole run cost, how much of it was the
orchestrator rather than the feature agents, and how the feature dollars
split by model.

**Why:** the owner's first big run (18 builder sessions, parallel lanes)
reported builder figures only; the orchestrator's share and the opus share
were invisible, and he watches consumption closely.

## M31-001 — Cost split and cost by model (Claude Code edition)

- The hooks credit each slice of the session's cost (between spawns and
  turn completions) to `agents` when any subagent is running, else to
  `orchestration`; lanes share a slice, so nothing counts twice. Written to
  `.harness-run/run-cost` during a run.
- run-report.sh Summary: `Cost: $T — feature agents $A, orchestration $O (P%)`
  and `Cost by model: …` from cost.log and models.log, each only when its
  files exist.

## Decision log

- 2026-10-14: dollars, not tokens: tokens are not comparable across models
  and cache reads dominate them; budgets are already in dollars.
- 2026-10-14: released as 3.9.0 together with the unpublished 3.8.1 README change.
