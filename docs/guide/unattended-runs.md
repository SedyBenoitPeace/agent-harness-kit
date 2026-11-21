# Unattended runs

Part of the [agent-harness-kit guide](../../README.md).

## Unattended runs

`harness-continuous` is its own command: invoke it and walk away. It
builds feature after feature — one fresh subagent each, like harness-run —
but a feature it cannot finish (a blocked session, a red gate, or two
evaluator `NEEDS_WORK` verdicts) is **skipped** instead of ending the run,
and it never asks you anything. It ends with a report.

Invoke it by name, with the options in the same message:

- Claude Code: `/agent-harness-kit:harness-continuous`
- any other agent with the plugin: ask for it by name, e.g. _"Run
  harness-continuous."_
- options: `cap 20` (default cap is 10 features) and/or `through M22`
  (cross milestone boundaries up to M22; without it the run stops at the
  first boundary).

Permissions are yours: it needs nothing beyond what a normal
harness-session already needs (run the gate, edit files, `git commit`), the
plugin never configures your agent's permissions, and it never needs a
skip-all-permissions flag. Anything your agent still refuses becomes a skip
with the reason in the report.

What it does, so nothing surprises you:

- **Skip, don't stop.** Leftover changes are stashed (`git stash push -u`,
  labelled `harness-run skip <id>`), never discarded; the feature's `notes`
  get the reason and one question for you; only FEATURES.json is committed.
  Skipping also excludes features that `depends_on` the skipped one — and,
  for features with no declared `depends_on`, every feature after it.
- **Waiting on a human.** A feature that needs you (an approval,
  credentials, production access) is `deferred` with `notes` starting
  `Needs a human: <question>`: planning asks for it, and a session that
  hits such a blocker defers its own feature that way. Status and the report
  list these questions; features whose `depends_on` reaches one are held,
  so no run spends time rediscovering the blocker. Answer, then set the
  feature back to `failing`.
- **Reused baseline.** A builder whose tree is identical (PROGRESS.md and
  plans aside) to the last green gate run in this clone skips its baseline
  gate: `GATE: green (baseline reused …)`. `HARNESS_GATE_REUSE=0` turns it off.
- **Stops** when nothing eligible is left, at the cap, when you create
  `.harness-run/STOP`, on a baseline problem (dirty tree, `UPGRADE: offer`,
  a red gate), or when a dispatch produced neither a commit nor a skip.
- **Run state** lives in `.harness-run/` (start commit, skip list, stop
  file). `run-start.sh` begins each run: it adds `.harness-run/` to
  `.gitignore` in its own commit if needed, and moves the previous run's
  logs and results into `.harness-run/previous/<old start>/` (kept, never
  deleted), so a report only ever sees its own run.
- **One wait per builder.** Each builder's last act writes
  `.harness-run/results/<id>.txt` (its `SESSION:` line and a short
  summary); the orchestrator blocks once per builder (the CLI's own wait,
  or `wait-result.sh <id>`), never polls or steers a running builder, and
  reads only script output, never whole skills, plans, PROGRESS.md or
  FEATURES.json.
- **Briefed builders.** The orchestrator pastes `feature.sh <id>` (the
  feature entry and its plan section) into each builder's prompt instead of
  the plan's path, and the builder starts from `context.sh --brief`, which
  adds the protocol card (§2.9) and the repo's AGENTS.md Rules and Needs a
  human sections. A briefed builder never reads SKILL.md, AGENTS.md, the
  protocol files, FEATURES.json or the plan.
- **Session budget.** A builder that stops on its session budget is
  retried once in a fresh session at the same size; a second budget stop
  is a skip.
- **Shared resources.** Features that set the same `exclusive` value (e.g.
  `simulator`, `device`, `database`) never run as parallel lanes at the same time;
  others still can.
- **Never pushes.** With `through M<n>` it creates one stacked branch per
  milestone and leaves them local.
- **The report**, `docs/runs/<date>.md`, is built by `run-report.sh` from
  git and FEATURES.json (no model calls) and committed: done (with minutes
  per feature, and dollars and the model with the Claude Code edition, plus
  the run's cost split into feature agents and orchestration, and by model;
  tokens per feature and by model where the CLI exposes them; each
  feature's `Decisions:` comes from its own commit or the PROGRESS entry
  that commit added, never from a planning entry), skipped (with each
  question), waiting on a human, not started and why, branches used.
- **Archive.** After the report, `archive-features.sh` moves every
  milestone whose features are all `passing` or `superseded` from
  FEATURES.json to `docs/features-archive.json` (same schema, appended).
  Status, the session brief, the report and the audit still resolve
  archived ids, so FEATURES.json stays small.
- **Watching it from a terminal.** In a second tab, run
  `bash <kit>/skills/harness-status/scripts/status.sh --watch` in the repo:
  the status report redrawn every 5 seconds (`--watch 30` for every 30),
  no model calls, any agent. For one line in your own status line script,
  add the output of `status.sh --line`, e.g.
  `harness M3-005 · 12/20 passing · 2 waiting on you · $4.10 this run`; it
  prints nothing outside a harnessed repo, so your line stays as it was
  there.
- **Builders start from the feature's `paths`**, when FEATURES.json has
  them, instead of searching the repo for their files.
