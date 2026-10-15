> **For agentic workers:** each task below is one harness coding session.
> Run it with the harness-session skill if it is installed; otherwise
> follow docs/agents/harness-protocol.md section 2. Do not load any other
> workflow skill or plugin to execute this plan.

# M33: Model size separate from effort, for every CLI

**Goal:** a feature says which size of model builds it (`model`) apart from
how hard that model checks its work (`effort`), and every CLI the kit
supports starts its builder accordingly.

**Why:** today one field does two jobs. `effort` (low/medium/high/max) sets
both the checking depth and, in the Claude Code edition, the model (low
haiku, medium sonnet, high/max opus). The planning guide asks only "how
much verification does this deserve?", so `low` is almost never chosen and
the small model never runs: 0 of 98 features in this repo are `low`. The
owner wants finer control, and the same choice for Codex and other agents.

## The field

`model`: `small`, `medium` or `large`; optional. A CLI's own alias (e.g.
`haiku`) is accepted as an override and applies only on that CLI; every
other CLI treats it as `medium`. Absent → the Claude Code edition keeps
today's mapping from `effort` (back-compatible); other CLIs use `medium`.

Choosing a size (planning guide, §1.4):

| Size | When | Examples |
|---|---|---|
| `small` | Narrow, well specified, follows a pattern already in the repo, verified by one command | boilerplate and scaffolds, docs, CHANGELOG and version bumps, config and manifests, renames, tests that mirror existing ones, fixtures |
| `medium` | The default: new logic, several files, debugging, long shell-heavy sessions | most features |
| `large` | Design calls others build on, security or isolation, cross-cutting refactors, what a benchmark measures | grader, sandbox, auth, data model |

`effort` keeps its meaning: how much checking and edge-case testing beyond
`verify`. Any size goes with any effort (a `small` model on `high` effort
for a fiddly config change).

Unchanged floors: the evaluator and features whose `paths` touch auth,
payments, billing, migrations, secrets, credentials or personal data never
build below `medium`. A retry or an evaluator rejection steps up one size.

## M33-001 — The `model` field in the protocol, status and audit

- Protocol §1.4: the field, the table above, the floors; FEATURES.json.tmpl
  `_instructions` names it. Agent-neutral wording (no vendor names).
- status.sh prints `model: <value>` under `NEXT:` when set, like `effort:`.
- harness-audit WARNs on a value that is not a size or a known alias form.
- Verify: test-status.sh proves the `model:` line; test-audit.sh proves the
  WARN; the protocol neutrality check in e2e.sh stays green.

## M33-002 — Claude Code edition: size first, effort separate

- `chooseModel` reads `model` (size → haiku/sonnet/opus by alias, or a
  Claude alias as given); without it, today's effort mapping. Step-up,
  floors, `model_floor` and `route_models` unchanged. The builder's effort
  comes from `effort` only. models.log reason names the source
  (`model small` or `effort low`).
- Verify: mod tests prove size routing, alias override, effort fallback,
  step-up from a size, both floors, and that effort no longer moves the
  model when `model` is set.

## M33-003 — Size map and per-size builder agents for every CLI

- `docs/agents/model-sizes.json` in the target repo (optional), one map per
  CLI: `{ "codex": { "small": "...", "medium": "...", "large": "..." } }`.
  The kit ships no model names for any CLI but Claude Code, whose aliases
  never go stale; a CLI with no map gets no per-size agents and uses its
  default model, as today.
- gen-agents.sh writes `harness-builder-small`, `-medium`, `-large` for each
  CLI that has a map (Claude Code always), each with that CLI's model line
  and no effort line; `harness-builder` stays as the size-less fallback.
- First, confirm on the owner's machine how each CLI's agent file takes a
  model (Codex agent TOML; Copilot CLI agent files). A CLI whose agent files
  cannot set a model gets no per-size agents; record it in the decision log.
- Verify: test-agents.sh proves the files per CLI from a fixture map, none
  without a map, and the Claude trio from aliases.

## M33-004 — Dispatch by size in harness-run and harness-continuous

- Dispatch `harness-builder-<size>` when it exists for the running CLI,
  else `harness-builder` (Claude Code keeps its hook, which overrides).
  Effort still goes as the agent's setting or "Effort: <level>." in the
  prompt. A retry dispatches the next size up.
- The orchestrator appends `<id> <model or size> <reason>` to
  `.harness-run/models.log` on every CLI, so the run report (and M32's
  tokens) show the model for Codex and Copilot runs too.
- Verify: test-run.sh proves the dispatch choice and the models.log line
  from fixtures, and the step-up on a retry.

## M33-005 — Docs, release 3.11.0, template sync

- README (choosing a size, the size map, upgrade note), CHANGELOG 3.11.0
  with an Upgrade block (optional: add `model` to features; Codex users add
  a size map), manifests, sync-template.sh and the mirror PR.
- Verify: gate green with version 3.11.0; sync-template.sh --check clean.

## Decision log

- 2026-10-15: sizes, not model names, in FEATURES.json: plans stay
  agent-neutral and outlive model releases. Names live in one per-repo map
  the owner keeps, and Claude Code needs none (aliases).
- 2026-10-15: Haiku 5.5 is a real builder, not just a helper. Anthropic
  positions it as a coding subagent and reports 83.7% SWE-bench
  Multilingual and 64.8% SWE-Bench Pro (Sonnet 5.5: 90.3%, 81.3%), at
  $0.10/$0.50 per million tokens against Sonnet's $2/$10. Its weak spot is
  long agentic shell work (Terminal-Bench 4.0: 39.2% vs 70.6%), which is
  why `small` means narrow and pattern-following, not "easy".
- 2026-10-15: at a twentieth of Sonnet's price, a `small` attempt that fails
  and steps up costs roughly 5–10% more than starting on `medium` (tokenizers
  differ), plus time. So
  planners should mark `small` whenever the table fits, not only when sure.
- 2026-10-15: default stays `medium` when `model` is absent: a silent
  downgrade of every existing feature would surprise people mid-run.
- 2026-10-15: Haiku 5.5 counts the same text as about 30% more tokens than
  Haiku 4.5; compare models in dollars, not tokens (M32 reports both).
- 2026-10-15: M32 runs first; its tasks carry `model` sizes now, which take
  effect once M33-002 ships. Until then the Claude edition routes by
  `effort` as before.
- 2026-10-15 (owner, from each CLI's official docs; answers M33-003's open
  question in place of real agent files on the owner machine):
  1. Codex: custom agent TOML files (`.codex/agents/*.toml`,
     `~/.codex/agents/`) take optional `model` and `model_reasoning_effort`
     (also `model_reasoning_summary`, `model_verbosity`). A value in the file
     wins over a spawn-time value, then the `[agents]` default, then the
     parent's. A file that sets only `model` keeps the previously resolved
     effort. `sandbox_mode`, `approval_policy`, `model_provider` and
     `mcp_servers` cannot be set per agent. Source: OpenAI Codex docs,
     Subagents.
  2. Copilot: custom agent files (`.agent.md` or `.md`) take a `model`
     frontmatter property: "Model to use when this custom agent executes. If
     unset, inherits the default model." Applies to GitHub.com, Copilot CLI
     and supported IDEs. Source: GitHub Docs, Custom agents configuration.
  3. Design consequence: because the Codex file value wins over spawn, keep
     per-size files (`harness-builder-small`/`-medium`/`-large`), each with
     its model line and an effort line, and leave `harness-builder` with no
     model line.
- 2026-10-15 (M33-003 session): sized builders and effort. Codex sized
  files carry `model_reasoning_effort = "medium"` for all three sizes: size
  and effort are separate (any size with any effort), and a pinned value
  keeps a Codex builder from inheriting whatever the parent runs at. The
  per-feature effort still reaches it as "Effort: <level>." in the prompt
  (M33-004). Copilot files get only `model`: Copilot agent files have no
  effort property. Claude Code sized files get only `model`: the edition's
  hook picks the model, and a fixed `effort:` there could override the
  per-feature effort that M33-002 keeps in charge. `harness-builder` has
  no model line on any CLI.
