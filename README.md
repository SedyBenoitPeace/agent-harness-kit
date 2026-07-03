# harness-planning

Plan applications with the long-running-agent harness approach — in-repo
FEATURES.json / PROGRESS.md / execution plans / e2e gate — as a Claude Code
skill plus a portable protocol usable by any AI agent.

## What is the harness approach?

AI coding sessions are short; projects are long. Plans left in chat
scrollback, scope kept in the model's head, and decisions made verbally all
die when the session ends. The harness fixes this by making **the repo the
only interface**: scope lives in `FEATURES.json` (every feature with a
falsifiable `verify` criterion), history in a newest-first `PROGRESS.md`,
plans in `docs/plans/`, and health behind one command — `scripts/e2e.sh`,
exit 0 = green. Any agent, from any vendor, recovers full context from the
repo alone and delivers exactly one proven feature per session.

The approach distills two published practices:
[Anthropic — Effective harnesses for long-running agents](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents)
and [OpenAI — Harness engineering](https://openai.com/index/harness-engineering/).

## Quickstart — Claude Code users

Install the skill by copying (or symlinking) it into your skills directory:

```bash
git clone <this-repo>
cp -r harness-planning-skill/skill/harness-planning ~/.claude/skills/harness-planning
```

Then, in the repo you want to plan: ask Claude to *"plan this project with
the harness-planning skill"*. It will interview you, write PRODUCT.md and
FEATURES.json, and scaffold the whole harness from the templates.

## Quickstart — any other agent

You need exactly one file:
[`skill/harness-planning/templates/harness-protocol.md`](skill/harness-planning/templates/harness-protocol.md).

Copy it into your repo as `docs/agents/harness-protocol.md` (bring the
`templates/` directory too if you want the ready-made scaffolds), then tell
your agent:

```
Read docs/agents/harness-protocol.md section 1 and run the planning
protocol for this repository. Interview me before writing anything.
```

The protocol is plain markdown with zero vendor-specific instructions — it
works as a Codex/Cursor rules file or pasted straight into a chat model.

## Repository layout

```
skill/harness-planning/
├── SKILL.md            Claude Code orchestration (thin — substance is below)
└── templates/
    ├── harness-protocol.md   ★ the agent-neutral operating manual
    ├── AGENTS.md.tmpl        entry point scaffold (≤100-line map)
    ├── FEATURES.json.tmpl    scope/status source of truth
    ├── PROGRESS.md.tmpl      session log
    ├── dev.sh.tmpl           dev-environment boot
    ├── e2e.sh.tmpl           the gate
    └── pointer.md.tmpl       one-line CLAUDE.md/GEMINI.md pointer
```

## Dogfood

This repo is built with its own harness: scope in [`FEATURES.json`](FEATURES.json),
sessions in [`PROGRESS.md`](PROGRESS.md), plans in [`docs/plans/`](docs/plans/),
and a lint gate in [`scripts/e2e.sh`](scripts/e2e.sh) that validates the
templates themselves (JSON-after-substitution, shellcheck, agent-neutrality,
line budgets).

## License

MIT
