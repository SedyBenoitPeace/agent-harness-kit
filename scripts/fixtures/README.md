# Test fixtures: CLI session data (M32-003, M32-004)

Session files in each CLI's own on-disk format, for the token collectors
`usage-codex.sh` and `usage-copilot.sh`. Both are synthetic: the formats
were confirmed on real sessions (2026-10-15), but every id, time and token
count here is invented, working directories are `/repo`, and message text is
`<redacted>` except the harness `SESSION:` lines. This is an open-source
repo: never commit a real session file, trimmed or not.

## codex/ — synthetic, in the real format (Codex CLI 0.162.1)

Shaped like a `harness-continuous` run: one orchestrator, four
`harness-builder` subagents (M1-001 blocked, then retried) and one
`guardian_review` subagent. Codex writes one `rollout-<time>-<thread id>.jsonl`
per thread under `~/.codex/sessions/YYYY/MM/DD/` (older days are
`.jsonl.zst`).

Format facts the collector relies on:

- Line 1 is `session_meta`. A subagent's file has `parent_thread_id`,
  `thread_source` (`subagent`, `guardian_review`), `agent_role`
  (`harness-builder`) and `runtime_workspace_roots` (which repo). A builder
  file carries a second, inherited `session_meta`: use the first line only.
- `turn_context.payload.model` is the model (`effort` beside it).
- `event_msg` / `token_count`: `info.total_token_usage` is cumulative for the
  thread, `info.last_token_usage` is the last call. A thread's tokens are its
  last `total_token_usage` (do not sum the events). Fields: `input_tokens`,
  `cached_input_tokens` (part of input), `output_tokens`,
  `reasoning_output_tokens` (part of output), `total_tokens`. Each file here
  has two intermediate `token_count` events before the last one.
- A builder's `event_msg` / `task_complete` carries its `SESSION: <id> · …`
  line, so tokens attribute to the feature exactly, parallel lanes included.
- The orchestrator's `spawn_agent` calls name `agent_type` and `task_name`;
  their `message` is encrypted by Codex (`<redacted>` here).

Expected per thread (last `total_token_usage`):

| File (id ends) | Role | Model | Feature | input | cached | output | total |
|---|---|---|---|---|---|---|---|
| …01 | orchestrator | gpt-6.1-sol | — | 900000 | 840000 | 6000 | 906000 |
| …02 | guardian_review | codex-auto-review | — | 60000 | 45000 | 500 | 60500 |
| …03 | harness-builder | gpt-6.1-sol | M1-001 (blocked) | 150000 | 120000 | 1500 | 151500 |
| …04 | harness-builder | gpt-6.1-sol | M1-001 (passing) | 400000 | 360000 | 4000 | 404000 |
| …05 | harness-builder | gpt-6.1-sol | M1-002 | 300000 | 270000 | 3000 | 303000 |
| …06 | harness-builder | gpt-6.1-sol | M1-003 | 500000 | 450000 | 5000 | 505000 |

So M1-001 totals both of its builder sessions (555500), and orchestration is
the orchestrator plus the guardian (966500).

## copilot/ — synthetic, in the real format (Copilot CLI 1.0.94)

Built to the format confirmed on real sessions: `~/.copilot/session-state/<session id>/events.jsonl` (one JSON event
per line) plus `workspace.yaml` (`cwd`, `git_root`, `branch`).

Format facts the collector relies on:

- `session.usage_record`: one per model call, `data.usage` with `model`,
  `inputTokens` (includes cache reads and writes), `outputTokens`,
  `cacheReadTokens`, `cacheWriteTokens`, `reasoningTokens`, and `cost` (premium
  requests for that call).
- A subagent's events (usage records, messages) carry a top-level `agentId`;
  its usage `initiator` is `sub-agent`. Main-thread events have no `agentId`.
- `subagent.started` / `subagent.completed` name the agent (`agentName`) and
  model; the builder's own `assistant.message` carries its `SESSION:` line.
- `session.shutdown` has the session totals: `totalPremiumRequests`,
  `modelMetrics` and `agentMetrics` (per agent id, `main` for the main thread).

Expected:

| Scope | model | input | cache read | cache write | output | reasoning |
|---|---|---|---|---|---|---|
| orchestration (`main`) | claude-sonnet-5 | 354000 | 263900 | 90000 | 1160 | 270 |
| M1-001 | claude-sonnet-5 | 153000 | 91600 | 60900 | 2700 | 850 |
| M1-002 | claude-sonnet-5 | 153000 | 91600 | 60900 | 2700 | 850 |

Premium requests for the session: 1.
