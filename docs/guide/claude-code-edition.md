# Claude Code edition

Part of the [agent-harness-kit guide](../../README.md).

## Claude Code edition

A second plugin in the same marketplace, `agent-harness-kit-claude`, adds
features only Claude Code has: an eval suite for the core skills and mods
(function hooks: a decision register, a done-check supervisor and a budget
guard). It depends on the core plugin and never copies
the protocol, so every other CLI keeps working from the core alone.
Installing the edition installs the core plugin with it:

```
/plugin install agent-harness-kit-claude
```

**Mods** (Claude Code function hooks, active only in a repo with
`FEATURES.json`; they write only under `.harness-run/`, which they keep out
of git):

- **Decision register** — a `register_decision` tool the agent calls each
  time it picks one option over another or assumes something; the lines
  land in `.harness-run/decisions/<id>.md` and the session folds them into
  the PROGRESS.md `Decisions:` line.
- **Done-check supervisor** — off by default (`supervisor` in `/config`
  turns it on). When on and a session ends with its `SESSION:` line, one
  cheap check against the feature's `verify` reports done, blocked or
  skipped work (in a status line, and `.harness-run/decisions/<id>.skipped.md`).
  It never judges a parallel-lane builder, whose transcript always ends
  mid-work by design.
- **Status line** — one line under the prompt, beside your own status line
  (never replacing it): `harness M3-005 · 12/20 passing · $1.40/$5.00 ·
  sonnet · 2 waiting on you`, plus the last budget or supervisor notice.
  To merge it into your own status line script instead, call
  `status.sh --line` there (core kit).
- **`/harness`** — milestones, the next feature, what waits on you and the
  session's cost, read from FEATURES.json: no model call, no tokens.
- **Model choice** — each builder a run starts gets the model its feature's
  `effort` asks for: low `haiku`, medium (or none) `sonnet`, high or max
  `opus`, by alias, so new models are picked up with nothing to update. A
  retry or an evaluator rejection steps it up one tier, but only when the
  feature's `notes` are unchanged since the earlier start (an answer from
  you gives a fresh attempt at the planned size); the evaluator and
  features touching auth, payments, migrations or personal data never run
  below `sonnet`. Set `model_floor` in `/config` to raise the minimum, or
  turn `route_models` off. Your own session's model is never changed; the
  choices land in `.harness-run/models.log` and the run report.
- **Budget guard** — budgets in dollars, from Claude Code's own cost
  figure (subagents included; on a subscription it is the list-price
  equivalent, still right for comparing and capping). Over
  `feature_budget_usd` (default $5) or `run_budget_usd` (default $50) during
  an unattended run it writes `.harness-run/STOP`, so the run ends after the
  current feature, and logs why in `.harness-run/budget.log`; 0 turns a
  budget off. Each feature's cost lands in `.harness-run/cost.log` and the
  run report. Features built in parallel share one figure. The cost
  split, budgets and pending usage reset when a new run starts
  (`.harness-run/start` changes), so each run reports alone.
- **Session budget notice** — at 80% of `session_budget_tokens` (default
  150000, 0 turns it off) of a builder's context, the status line shows
  `session budget: Nk of Mk tokens, wrap up`.
- **Orchestration cost** — the run's total is split into time a builder or
  evaluator was running and time the orchestrator ran alone (dispatching,
  verifying, merging lanes, gates), counted once even with parallel lanes,
  in `.harness-run/run-cost`. The run report's Summary shows that split and
  the feature dollars per model, so a heavy `opus` share is easy to spot.
- **Token usage** — where the CLI exposes token usage, the run report shows
  tokens per feature (input, cached, output), the run's tokens split into
  feature agents and orchestration, and tokens by model. Claude Code, Codex
  and Copilot each log their own usage to `.harness-run/usage.log`; a CLI
  with no usage shows no token lines.

Upgrading from 3.2.0: the edition was briefly named `agent-harness-kit-mods`;
run `/plugin uninstall agent-harness-kit-mods`, then install
`agent-harness-kit-claude`.

**Unattended runs on auto mode.** Start Claude Code with
`claude --permission-mode auto` and invoke `harness-continuous`. Auto mode
checks each action against what you actually allowed (writing to a
database, issuing keys, using the computer) instead of asking you, so the
run keeps going without unchecked access. Never use the bypass mode or a
skip-all-permissions flag.

**Evals for the core skills.** `claude/evals/` holds an eval suite for
`harness-brief` and `harness-session`: each case seeds a small repo, runs
the prompt with and without the plugin, and grades the files it leaves
behind. Run it from the repo root (it costs model usage, about $2 for the
suite at 3 runs per case):

```
claude plugin eval . --eval-dir claude/evals --scaffold --allow-tools Write Bash Edit
```

Run it after changing a skill or its description, and after a model
change. A `skill-fired` indicator that fails means the description did not
trigger the skill.
