> **For agentic workers:** each task below is one harness coding session.
> Run it with the harness-session skill if it is installed; otherwise
> follow docs/agents/harness-protocol.md section 2. Do not load any other
> workflow skill or plugin to execute this plan.

# M30: Model choice, dollar budgets, keeping a run in view

**Goal:** a run spends the cheapest model that can do each feature, is
capped in dollars, and can be followed from the terminal at no token cost.

**Why:** the owner tested 3.7.0 and wants model selection that adapts per
feature (Haiku 5.5 is a tenth of Haiku 4.5's price), budgets in money
rather than tokens, a status line next to his own, and features visible in
FEATURES.json from the moment a plan is approved. Jev-based routing was
discussed and left for later.

Checked live before planning (Claude Code 2.1.296): an `agent.spawn` hook
that sets `model: "haiku"` starts the subagent on `claude-haiku-5-5`, and
`$.session.usage().cost.usd` includes subagents (main on haiku, an opus
subagent: the session cost rose by $0.24 during the subagent's turn).

## M30-001 — Model choice from effort (Claude Code edition)

- An `agent.spawn` hook picks the builder's model from the feature's
  `effort` by alias: low haiku, medium or none sonnet, high/max opus.
- One tier up per earlier builder start for that feature in this clone
  (`.harness-run/models.log`) and per `eval_attempts`; never above opus.
- Never below sonnet for the evaluator, or for features whose `paths` touch
  auth, payments, billing, migrations, secrets, credentials or personal data.
- `model_floor` setting (haiku, sonnet, opus); `route_models` turns it off.
  Forks, teammates, workflow agents and the main session are never touched.

## M30-002 — Budgets in dollars

- `feature_budget_usd` and `run_budget_usd` replace `feature_token_budget`,
  measured from the session's own cost figure: no price table in the kit.
- Over the feature budget during a run, or the run budget: `.harness-run/STOP`
  and a line in `budget.log`. Each feature's cost goes to `cost.log`.
- The run report shows dollars and the model per feature (and a step-up).

## M30-003 — Harness status line and /harness

- One status line (the plugin's own, beside the person's own status line):
  feature, passing/total, dollars against budget, model, waiting on you.
- `/harness`: milestones, next feature, waiting on a human, run cost; no
  model call.

## M30-004 — status.sh --line and --watch (core)

- `--line`: the harness in one short line, for a person's own status line
  script. `--watch [seconds]`: the report redrawn for a second terminal.

## M30-005 — Plan tasks in FEATURES.json once approved; release 3.8.0

- Protocol: an approved plan's tasks enter FEATURES.json as `failing` in the
  plan's commit. harness-audit FAILs when an active plan names an id that is
  not in FEATURES.json.
- CHANGELOG 3.8.0, manifests, mirror, PR, CI.

## Decision log

- 2026-10-12: aliases, never versioned names: a new model is picked up with
  nothing to maintain (M28's reason for dropping models.json).
- 2026-10-12: escalation counts earlier builder starts, not parsed outcomes:
  every retry of a feature is evidence the last model was not enough.
- 2026-10-12: per-feature cost is the session cost between SESSION lines;
  exact only when features run one at a time (parallel lanes share it).
- 2026-10-12: Jev routing deferred: unproven, and it sends feature text to a
  third party.
