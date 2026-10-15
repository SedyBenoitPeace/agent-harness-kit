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

- `scope`: a feature id, `orchestration`, or `<id>/second-opinion`.
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
  Codex threads under `~/.codex/sessions/` (`.jsonl`, and `.jsonl.zst` when
  `zstd` exists) whose `session_meta.runtime_workspace_roots` is this repo
  and whose time falls after the start commit. A thread's tokens are its last
  `token_count.info.total_token_usage`; its model is `turn_context.model`.
- Attribution is exact, not by time: a `harness-builder` thread's
  `task_complete` carries its `SESSION: <id> · …` line, so its tokens go to
  that feature (retries add up, parallel lanes stay separate). Every other
  thread of the run (the orchestrator, `guardian_review`) is
  `orchestration`. Use only the first `session_meta` line of a file.
- second-opinion.sh: run `codex exec --json` and append the reply's
  summed `turn.completed` usage as `<id>/second-opinion codex …`.
- Fixture: `scripts/fixtures/codex/`, synthetic in the confirmed format;
  `scripts/fixtures/README.md` lists the format facts and expected totals.
- Verify: `scripts/test-usage-codex.sh` on the fixture reproduces the
  README's per-feature and orchestration totals; test-second-opinion.sh
  proves the second-opinion line.

## M32-004 — Copilot: tokens from its session data

- `skills/harness-run/scripts/usage-copilot.sh <start-commit>`: reads
  `~/.copilot/session-state/*/events.jsonl` for sessions whose
  `workspace.yaml` `cwd` (or `session.start` context) is this repo, after
  the start commit. Sums `session.usage_record` `data.usage` per scope:
  records with a top-level `agentId` belong to that subagent; the subagent's
  `assistant.message` with a `SESSION: <id> · …` line names the feature;
  records without `agentId` are `orchestration`. Premium requests are the
  sum of `usage.cost` (cross-check: `session.shutdown.totalPremiumRequests`).
- Copilot persists all of this itself; no status-line snapshot is needed.
- Fixture: `scripts/fixtures/copilot/`, synthetic in the confirmed format;
  expected totals in
  `scripts/fixtures/README.md`.
- Verify: `scripts/test-usage-copilot.sh` on the fixture reproduces the
  README's per-feature and orchestration totals and `premium=1`.

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
- 2026-10-15: every CLI-specific format is confirmed on a real session and
  committed as a fixture before code depends on it; nothing is guessed
  from documentation alone.
- 2026-10-15 (formats confirmed on the owner's machine, Codex CLI 0.162.1,
  Copilot CLI 1.0.94): both CLIs save per-call token usage and tag each
  subagent, and harness builders end with their SESSION line, so Codex and
  Copilot tokens attribute to features exactly. The earlier idea of
  splitting by commit time windows (and reporting parallel batches
  together) is dropped, and so is Copilot's status-line snapshot.
- 2026-10-15: both fixtures are synthetic (formats confirmed on real
  sessions, values invented): this is an open-source repo, so no real
  session data is committed, trimmed or not.
- 2026-10-15: on a real Codex run the orchestrator's share was comparable to
  all builders together, mostly cached input: orchestration cost is worth
  showing for every CLI, not only Claude Code.
- 2026-10-15: sizes per task (M33's `model` field, owner-approved): M32-001
  and M32-005 `small`, the rest `medium`; M32-005 also `effort: low`, so it
  already starts on Haiku. The sizes take effect in the Claude edition once
  M33-002 ships; until then routing follows `effort`. None touches
  security-sensitive paths.
