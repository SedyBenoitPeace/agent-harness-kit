# Other agents

Part of the [agent-harness-kit guide](../../README.md).

## Quickstart — Codex (plugin)

Codex CLI installs the same plugin — the skills work there unchanged:

```
codex plugin marketplace add https://github.com/SedyBenoitPeace/agent-harness-kit
codex plugin add agent-harness-kit@agent-harness-kit
```

Update to the latest release:

```
codex plugin marketplace upgrade agent-harness-kit
```

Start each kit run in a fresh Codex session. The kit spawns every builder,
evaluator and reviewer with `fork_turns: "none"`, so they start clean
instead of inheriting the orchestrator's history.

## Quickstart - Pi Coding Agent

```
pi install git:github.com/SedyBenoitPeace/agent-harness-kit
```

Update to latest

```
pi update --extensions

```

## Quickstart - Copilot CLI (plugin)

```
copilot plugin marketplace add https://github.com/SedyBenoitPeace/agent-harness-kit
```

```
copilot plugin install agent-harness-kit                                                     
```

Update to latest

```
copilot plugin update agent-harness-kit
```

## Quickstart — any other agent

You need the four protocol files in
[`skills/harness-initial-setup/templates/`](../../skills/harness-initial-setup/templates/):
`harness-protocol.md` (the session core every session reads) and the parts
read only when needed, `harness-protocol-planning.md`,
`harness-protocol-runs.md` and `harness-protocol-maintenance.md`.

Copy them into your repo's `docs/agents/` (bring the rest of `templates/`
too if you want the ready-made scaffolds), then tell your agent:

```
Read docs/agents/harness-protocol-planning.md and run the planning
protocol for this repository. Interview me before writing anything.
```

The protocol is plain markdown with zero vendor-specific instructions — it
works as a Codex/Cursor rules file or pasted straight into a chat model.

A harnessed repo declares itself, so agents without the plugin (an ADE
built on Claude Code, Gemini CLI, Cursor) follow it unprompted: `AGENTS.md`
says the harness applies plugin or not, and `CLAUDE.md` / `GEMINI.md` import
it with `@AGENTS.md` (a link in words is not loaded). The plugin only makes
the same steps faster. To skip the harness for one change, say "just build
it": no brief or plan, but FEATURES.json is still updated.

Script and template names in the protocol (`quiet.sh`, `context.sh`,
`FEATURES.json.tmpl`) are kit files, not files in your repo, and each doc
says where they live; without the plugin each rule says what to do instead.
The gate's `scripts/check-doc-refs.sh` fails if an onboarded doc names a
file that is neither installed in the repo nor shipped by the kit.

## Quickstart — template repository

Prefer starting a project from a ready-made scaffold? Instantiate
[agent-harness-template](https://github.com/SedyBenoitPeace/agent-harness-template)
(_Use this template_ on GitHub), open it with any agent, and say _"Read
AGENTS.md and follow its initialization instructions."_ The template mirrors
`skills/harness-initial-setup/templates/` — this repo stays the canonical source.

## Switching agents (e.g. Claude Code ↔ Codex)

The harness keeps all state in the repo, so agents from different vendors
can work the same project in shifts — plan and review with one, grind
features with another when you hit a usage limit. The ritual:

1. End the session with `/agent-harness-kit:harness-handoff` (or _"prepare
   the handoff"_). Blocked = fix first; ready = copy the printed prompt.
2. Feed the prompt to the next agent: paste it into the chat, or from a
   terminal `codex "<prompt>"` (interactive) / `codex exec "<prompt>"`
   (non-interactive). Codex, Cursor, and Gemini CLI read `AGENTS.md`
   natively, so the prompt plus the repo is the entire handoff.
3. When you come back, `/agent-harness-kit:harness-status` shows what the
   other agent did; review its diff before continuing.

One branch, one agent at a time — never point two agents at the same
branch concurrently.
