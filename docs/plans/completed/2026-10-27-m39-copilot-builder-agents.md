# M39: dispatch the kit's builder agents, never a stand-in

**Goal:** a harness-run on Copilot CLI (or any CLI) dispatches the
generated `harness-builder` / `harness-evaluator` agents, with the
`Start reading from:` brief, instead of a general-purpose subagent told to
"act as harness-builder".

## Evidence

A Copilot run (2026-10-01) dispatched 15 `general-purpose` subagents with
hand-written briefs ("act as harness-builder, read harness-protocol.md
section 2", "read the plan in full"); the heaviest worker made 287 model
calls. The repo had no agent files then: they were generated only when a
feature opted in to evaluation, and harness-run said "if absent, the
agent's own built-in subagent". The plugin install was not the cause: the
kit ships agents per repo, not in the plugin. Once that repo got
`.github/agents/` (2026-10-20), later Copilot runs dispatched `agent_type:
harness-builder` with `Start reading from:` in every brief.

## M39-001 — builder agents always present, no stand-in

- `dispatch.sh`: no `harness-builder` file for the CLI → `AGENT: missing`,
  exit 3, no models.log line.
- harness-run step 3: exit 3 → `gen-agents.sh`, commit, ask for a CLI
  restart, STOP; dispatch the named agent itself (Copilot: `agent_type`).
  Evaluator step: same on a missing evaluator. harness-continuous: exit 3
  Ends the run (not a skip).
- harness-initial-setup always runs `gen-agents.sh`; upgrade.sh generates
  every role for every CLI when the repo has no agent files.
- Verify: test-run.sh (missing agent on each CLI), test-upgrade.sh (repo
  without agents or evaluation gets the builder for every CLI).

## Decision log

- 2026-10-27: stop instead of generating and continuing, because Copilot
  CLI (and Claude Code) read agent files only at session start.
- Agent prompts unchanged; the `Start reading from:` line was already in
  harness-run step 3 since 3.7.0.
