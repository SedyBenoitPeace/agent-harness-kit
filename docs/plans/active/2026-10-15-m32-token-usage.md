> **For agentic workers:** each task below is one harness coding session.
> Run it with the harness-session skill if it is installed; otherwise
> follow docs/agents/harness-protocol.md section 2. Do not load any other
> workflow skill or plugin to execute this plan.

# M32: Token usage in the run report, for every CLI

**Goal:** every run report shows tokens per feature and for the whole run
(input, cached, output), whichever CLI ran it. The Claude Code edition keeps
its dollars beside the tokens; Codex and Copilot show tokens only.

**Why:** the owner tracks consumption closely. 3.8.0 replaced tokens with
dollars, and 3.9.0 added the orchestration share, but only for Claude Code.
The benchmark compares Claude Code, Codex and Copilot, so their runs need
the same visibility.

**Scope:** tokens for all three CLIs; no price table and no dollars for Codex
or Copilot (owner's decision, 2026-10-15). Copilot's premium requests are
shown when its data has them, since that is what Copilot bills.

## Shared format (used by every task)

`.harness-run/usage.log`, one line per measured slice, appended:

    <scope> <cli> <model> <input> <cached> <output>

- `scope`: a feature id, `orchestration`, `<id>/second-opinion`, or ids
  joined by `+` for a parallel batch measured as one (Codex, Copilot).
- `model`: the model name the CLI reported, or `-`.
- Token counts are integers; `cached` is the cache-read share of input.
- Copilot may add a seventh field `premium=<n>`.

Dollars stay where they are (`cost.log`, `run-cost`, Claude Code only).

## M32-001 — usage.log in the run report

- run-report.sh reads `.harness-run/usage.log` when present:
  - under each done feature, after minutes and dollars:
    `<total> tok (in <n>, cached <n>, out <n>)`, humanised (`1.2M`, `85k`);
  - Summary: `Tokens: <total> — feature agents <n>, orchestration <n>`;
  - `Cost by model` gains each model's tokens; with no cost.log it becomes
    `Tokens by model`.
- harness-continuous End step: before run-report.sh, run
  `scripts/usage-<cli>.sh <start-commit>` (path relative to the harness-run
  skill) for the CLI running the session, when that script exists. No
  script, no tokens; the report is unchanged.
- e2e.sh runs every `scripts/test-usage-*.sh`, so later tasks add tests
  without editing the gate.
- Verify: test-run.sh fixtures (no live CLI) prove each line appears only
  when usage.log exists, totals are right, and the report stays
  deterministic.

## M32-002 — Claude Code edition writes usage.log

- First, on a real Claude Code session (one builder subagent on a tiny
  feature): check whether `turn.complete`'s `usage` covers the builder's
  whole session or only its last model call. Record the answer in the
  decision log. If it is last-call only, sum the subagent's turns instead.
- The hooks append one line per builder at its SESSION line, and one
  `orchestration` line per slice credited to the orchestrator (the
  M31-001 split), with the model from the usage.
- Verify: mod tests prove a builder's tokens land on its feature, the
  orchestrator's on `orchestration`, lanes count once, and nothing is
  written outside a run.

## M32-003 — Codex: tokens from its session files

- `skills/harness-run/scripts/usage-codex.sh <start-commit>`: reads the
  Codex session files written between the start commit's time and now,
  sums each turn's `input_tokens`, `cached_input_tokens` and
  `output_tokens`, and attributes them by time to the feature whose
  commit window they fall in (the windows run-report.sh already uses for
  minutes); time outside any builder window is `orchestration`.
- First, from a real Codex run on the owner's machine: confirm where the
  session files live, the event that carries token counts, whether
  subagents write their own files, and how a file's time range is read.
  Commit a trimmed real file as the test fixture. No real file available
  → set the feature `deferred` with `Needs a human:` asking for one.
- second-opinion.sh: run `codex exec --json` and append the reply's
  summed `turn.completed` usage as `<id>/second-opinion codex …`.
- Verify: `scripts/test-usage-codex.sh` on the committed fixture proves
  the per-feature and orchestration totals; test-second-opinion.sh proves
  the second-opinion line.

## M32-004 — Copilot: tokens from its session data

- `skills/harness-run/scripts/usage-copilot.sh <start-commit>`: same
  contract as M32-003, from Copilot CLI's data: total input, output,
  cache-read and reasoning tokens, and premium requests.
- First, from a real Copilot run on the owner's machine: find where the
  CLI persists per-session totals. If only the status-line payload carries
  them, ship `usage-snapshot.sh`, a status-line command that appends a
  timestamped snapshot to `.harness-run/copilot-usage.jsonl` and can wrap
  the person's own status line; usage-copilot.sh then takes deltas between
  snapshots per feature window. Commit a trimmed real sample as the
  fixture; none available → `deferred` with `Needs a human:`.
- Verify: `scripts/test-usage-copilot.sh` on the fixture proves the totals,
  including premium requests when present.

## M32-005 — Protocol, docs, release 3.10.0

- Protocol §2.8: the report carries each feature's tokens where the CLI
  exposes them (agent-neutral wording). README run-report and edition
  paragraphs; CHANGELOG 3.10.0 with its Upgrade block; manifests;
  `sync-template.sh` against agent-harness-template and a PR there.
- Verify: gate green; `sync-template.sh --check` clean on the mirror PR.

## Decision log

- 2026-10-15: tokens for every CLI, dollars only where the CLI reports
  them (Claude Code). No price table: it would go stale, the reason M28
  dropped models.json.
- 2026-10-15: one shared `usage.log` written by each CLI's own source
  (hooks for Claude Code, a collector script reading session data for
  Codex and Copilot); the report never knows which CLI wrote it.
- 2026-10-15: Codex and Copilot are attributed by time, using the commit
  windows that already give minutes per feature. Parallel lanes overlap in
  time, so for those CLIs a parallel batch's tokens are reported once,
  under the batch's features together, not per lane.
- 2026-10-15: every CLI-specific format is confirmed on a real session and
  committed as a fixture before code depends on it; nothing is guessed
  from documentation alone.
- 2026-10-15: all tasks `effort: medium` (Sonnet builders); none touches
  security-sensitive paths.
