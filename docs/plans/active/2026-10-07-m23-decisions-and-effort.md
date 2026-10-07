> **For agentic workers:** each task below is one harness coding session.
> Run it with the harness-session skill if it is installed; otherwise
> follow docs/agents/harness-protocol.md section 2. Do not load any other
> workflow skill or plugin to execute this plan.

# M23–M25: Decision notes, effort, and the Claude edition

**Goal:** sessions leave a record of what they chose *not* to do, spend
effort where it pays, and stop carrying rules written for an older model.
Then a Claude Code edition uses what only Claude Code has (agent effort,
mods) without forking the protocol.

**Why:** three findings from Anthropic's Claude Code team (Latent Space,
2026-09-29) and the owner's practices notebook:

1. Most failures at high effort are the model *considering* the right
   solution and rejecting it. Written-down decisions let a reviewer say
   "do the thing you skipped".
2. Effort scales with task kind: verification-heavy work (security,
   review, APIs) gains from high effort; UI work mostly does not.
3. Rules added to fix one model's failure over-constrain the next model.
   Start lean; tag model-specific rules and re-test them on model change.

**Milestones:**

- **M23 (core, portable):** this repo's protocol, templates and scripts.
  Every CLI benefits. Built in one cloud session.
- **M24 (Claude edition, native features):** a second plugin in this same
  marketplace. Built from Claude Code CLI sessions.
- **M25 (Claude edition, mods):** the same plugin's hooks module. Built and
  tested in Claude Code CLI (mods need the real runtime: hot reload,
  `claude plugin validate`, `claude plugin test`).

## M23-001 — Decision notes in every session entry

- Protocol §2.5 step 6: the PROGRESS.md entry gains a `Decisions:` line —
  options considered and rejected, assumptions made, or `none`.
- `PROGRESS.md.tmpl`: the entry shape shows the line.
- `agents/src/harness-builder.md`: record the line at close-out.
- `agents/src/harness-evaluator.md`: read the feature's latest PROGRESS.md
  `Decisions:` line as leads (never as evidence); a rejected option that
  the `verify` or `bar` required is NEEDS_WORK.
- Gate: greps for each of the above, single-line phrases.

## M23-002 — Per-feature `effort`

- Schema: optional `effort`: `low|medium|high|max` (absent = no hint).
  `FEATURES.json.tmpl` `_instructions` documents it; the gate rejects other
  values in this repo's own FEATURES.json.
- Protocol §1.4: ask "how much verification does this deserve?" with the
  per-kind guidance (UI low/medium; APIs, data and migrations high;
  security and review high/max).
- `status.sh`: print `  effort: <level>` under `NEXT:` when set (both the
  plain and `--skip` paths), nothing when absent. Fixtures in
  `scripts/test-status.sh`.
- `check.sh`: WARN on an effort value outside the four levels (fixture in
  `scripts/test-audit.sh`). WARN, not FAIL: an unknown hint is harmless.
- `harness-run` SKILL.md: pass the level to the builder dispatch — as the
  dispatch tool's own effort setting where it has one, otherwise as a line
  in the prompt. Dispatch the evaluator at `high` or above.
- `harness-session` SKILL.md: read the effort line; it sets how much
  verification and edge-case testing to do beyond the `verify` check.

## M23-003 — Model-tagged rules, start lean; release 3.1.0

- Protocol §3.4: a rule added to fix one model's repeated failure is
  tagged `(model: <name>)`.
- Protocol §3.2: when the model changes, re-test every tagged rule and
  delete the ones the new model no longer needs.
- `AGENTS.md.tmpl`: one Rules line about the tag, within the 80-line budget.
- `check.sh`: WARN with the count when AGENTS.md has tagged rules
  ("re-test on model change"); fixture in `scripts/test-audit.sh`.
- README: decision notes, effort, model-tagged rules.
- Release 3.1.0 (package.json, plugin.json, marketplace.json).

## M24-001 — Claude edition plugin skeleton

- `claude/.claude-plugin/plugin.json` named `agent-harness-kit-claude`,
  second entry in `marketplace.json` with `source: "./claude"`; versions in
  lockstep with the core plugin; it lists the core plugin as a dependency.
- README: install line and what the edition adds.
- Gate: both plugins' versions match; the edition never copies the
  protocol (it is the core's alone).

## M24-002 — Agent effort in the generator

- `agents/src/*.md` gain an optional `effort:` field; `gen-agents.sh`
  emits it as `effort:` for Claude Code and `model_reasoning_effort` for
  Codex; Copilot gets nothing. Evaluator `effort: high`.
- Fixtures in `scripts/test-agents.sh`.

## M24-003 — Unattended runs on auto mode; skill evals

- README "Unattended runs (Claude Code)": run harness-continuous with the
  auto permission mode, never bypass.
- An eval suite for harness-brief and harness-session under `claude/evals/`
  that `claude plugin eval` runs; the gate checks the suite parses.

## M25-001 — Mod: decision register tool

- The edition's hooks module registers a model-callable tool that appends
  one decision (chose X over Y, why) to `.harness-run/decisions/<id>.md`;
  harness-session's close-out folds it into the `Decisions:` line.
- `claude plugin validate` clean; `claude plugin test` proves append and
  fold.

## M25-002 — Mod: done-check supervisor

- On `turn.complete` of a builder subagent, `$.model.fork` (cache-served
  transcript) answers JSON `{done, blocked, skipped_work}` against the
  feature's `verify`; a `skipped_work` answer is written beside the
  decisions file and shown as a status line. Never edits code.

## M25-003 — Mod: budget guard

- Sums `turn.complete` usage per feature; over the `userConfig` threshold,
  writes `.harness-run/STOP` (honoured after the current feature) and
  logs why to `.harness-run/budget.log`.

## M25-004 — Mod: next steps band (supervised sessions only)

- After a passing session, an above-prompt band offers two or three next
  steps (next feature, explain, quiz me on what shipped). Off when
  `.harness-run/start` exists (an unattended run).

## Decision log

- 2026-10-07 — One repo, two plugins, not a fork: a fork would carry the
  protocol twice and drift. The edition depends on the core plugin.
- 2026-10-07 — Effort is a per-feature hint in FEATURES.json, not a global
  setting: the podcast's guidance is per task kind, and the field stays
  portable (Codex has a reasoning-effort setting too).
- 2026-10-07 — No model-router mod: the Claude Code agent tool already
  takes an `effort` per dispatch (checked in the 2.1.292 mods types), so
  harness-run sets it directly. A router would also break the prompt cache.
- 2026-10-07 — Decision notes are leads for the evaluator, not evidence:
  the evaluator still judges by observing the repo (§2.7 unchanged).
- 2026-10-07 — check.sh WARNs (never FAILs) on effort and tagged rules:
  both are advice; a repo is not broken by them.
- 2026-10-07 — Deferred: a cross-vendor second opinion (Codex evaluates
  Claude's commit, or the reverse). Revisit after M25; the generator
  already emits the evaluator for every CLI.
