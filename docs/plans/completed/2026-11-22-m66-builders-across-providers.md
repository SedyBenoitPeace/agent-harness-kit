# M66 — Builders across providers

Owner report (2026-11-22): on a host whose child tasks can run on another
provider (T3 Code's `delegate_task`), a run spread its builders across Claude
and Codex and it worked, but only because the owner's prompt asked for it,
and the first brief was typed by hand and shipped a `FEATURE_PLACEHOLDER`.
The kit should do this itself, with no model names anywhere in it: the host
lists its providers and picks each one's default model.

Order of fallbacks, each unchanged from today when the one above is absent:
host child tasks on other providers → the CLI's own subagent tool → one
inline session (harness-run "No subagent tool").

## M66-001 feature.sh --prompt

`feature.sh <id> [target] --prompt builder [--lane <dir>]` prints the whole
prompt for a child that cannot be started as a named agent: the builder role
(`agents/src/harness-builder.md` body, frontmatter dropped), the Workflow
step 3 brief sentence with the absolute `context.sh` path (and the lane
clause when `--lane` is given), then today's feature entry, plan section and
hint. `--prompt evaluator --range <base>..<head>` prints the evaluator role,
the entry and the range. Without `--prompt` the output is byte-identical to
today's. The orchestrator pastes the output as is; it never types a brief.

## M66-002 harness-run: host child tasks on other providers

New SKILL.md section. When the host can start child tasks on providers other
than its own (T3 Code: `orchestrator_capabilities` lists providers with
cross-provider child tasks; `delegate_task` starts one), each lane's builder
goes to the next provider in the order the host lists them. The orchestrator
names the provider only, never a model (the host uses that provider's
default), and sets effort from the feature's size through the option name the
host reports. The task text is `feature.sh --prompt builder --lane <dir>`
output. A provider that fails to start is dropped for the rest of the run. No
such host → Workflow step 3, unchanged. harness-continuous reuses these steps
by reference, so it needs no edit.

## M66-003 Evaluator on another provider

Evaluator step: with host child tasks on 2+ providers, the evaluator runs on
a provider other than the builder's, prompted by `feature.sh --prompt
evaluator`; the integrity check is unchanged (it is the read-only guarantee,
since such a child cannot be made read-only). One provider or none → today's
evaluator.

## M66-004 dispatch.sh --via

`dispatch.sh … [retries] [--via <provider>[/<model>]]` appends the provider
(and model when known) to the `dispatch` event line, so the run board and
report show who built each feature. Without `--via` every output and log line
is byte-identical to today's.

## Decision log

- 2026-11-22: No routing file and no model names in the kit; the host's
  per-provider default model is the owner's setting (probe: a provider-only
  `delegate_task` to Codex ran its default model).
- 2026-11-22: Provider order is the host's listing order, round-robin per
  lane, not the agent's judgement (judgement is what produced the
  placeholder brief).
- 2026-11-22: The planned M66-005 ("unchanged without host child tasks") is
  folded into M66-001.3 and M66-004.2 rather than a feature of its own.
- 2026-11-22: The live cross-provider run is the owner's check; e2e cannot
  simulate a host with child tasks.
