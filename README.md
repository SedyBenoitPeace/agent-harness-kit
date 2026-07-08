# agent-harness-kit

Full long-running-agent harness toolkit — scaffold in-repo
FEATURES.json / PROGRESS.md / execution plans / e2e gate into any project,
and audit repos for harness-readiness. Ships as a Claude Code plugin plus a
portable protocol usable by any AI agent.

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

## Quickstart — Claude Code (plugin, recommended)

```
/plugin marketplace add SedyBenoitPeace/agent-harness-kit
/plugin install agent-harness-kit
```

Two skills come with it:

- **harness-setup** — interview → PRODUCT.md + FEATURES.json → scaffold the
  whole harness. Say *"set up the agent harness in this repo"*.
- **harness-audit** — check any repo's harness-readiness. Say *"audit this
  repo's harness"*.

Manual fallback (no plugin): copy `skills/harness-setup` into
`~/.claude/skills/`.

## Using the skills — copy-paste prompts

| You want to… | Say |
|---|---|
| Plan + scaffold a new project | *"Set up the agent harness in this repo."* |
| Retrofit an existing codebase | *"Set up the agent harness in this repo — it's an existing codebase, preserve what's there."* |
| Start from an existing PRD | *"Set up the harness using docs/PRD.md as the product requirements."* |
| Check a repo is harness-ready | *"Audit this repo's harness."* |
| Do one unit of work | *"Read AGENTS.md, then docs/agents/harness-protocol.md section 2, and perform exactly one coding session."* |
| Periodic cleanup | *"Read AGENTS.md, then docs/agents/harness-protocol.md section 3, and perform one maintenance pass."* |

## Quickstart — template repository

Prefer starting a project from a ready-made scaffold? Instantiate
[agent-harness-template](https://github.com/SedyBenoitPeace/agent-harness-template)
(*Use this template* on GitHub), open it with any agent, and say *"Read
AGENTS.md and follow its initialization instructions."* The template mirrors
`skills/harness-setup/templates/` — this repo stays the canonical source.

## Quickstart — any other agent

You need exactly one file:
[`skills/harness-setup/templates/harness-protocol.md`](skills/harness-setup/templates/harness-protocol.md).

Copy it into your repo as `docs/agents/harness-protocol.md` (bring the
`templates/` directory too if you want the ready-made scaffolds), then tell
your agent:

```
Read docs/agents/harness-protocol.md section 1 and run the planning
protocol for this repository. Interview me before writing anything.
```

The protocol is plain markdown with zero vendor-specific instructions — it
works as a Codex/Cursor rules file or pasted straight into a chat model.

## Already have requirements?

You don't have to start the planning interview from zero. Put your
existing requirements in the repo — markdown preferred (`docs/PRD.md` is a
good spot), but PDF or HTML work too, agents read those — and say:

```
Set up the harness using docs/PRD.md as the product requirements.
```

The interview extracts what it can from the document and only asks you
about the gaps.

## Repository layout

```
.claude-plugin/         plugin + marketplace manifests
skills/
├── harness-setup/
│   ├── SKILL.md        planning/scaffolding orchestration (thin)
│   └── templates/
│       ├── harness-protocol.md   ★ the agent-neutral operating manual
│       ├── AGENTS.md.tmpl        entry point scaffold (≤100-line map)
│       ├── FEATURES.json.tmpl    scope/status source of truth
│       ├── PROGRESS.md.tmpl      session log
│       ├── dev.sh.tmpl           dev-environment boot
│       ├── e2e.sh.tmpl           the gate
│       └── pointer.md.tmpl       one-line CLAUDE.md/GEMINI.md pointer
└── harness-audit/
    ├── SKILL.md        audit orchestration: report + offer fixes
    └── scripts/check.sh          deterministic readiness checker
```

## Dogfood

This repo is built with its own harness: scope in [`FEATURES.json`](FEATURES.json),
sessions in [`PROGRESS.md`](PROGRESS.md), plans in [`docs/plans/`](docs/plans/),
and a lint gate in [`scripts/e2e.sh`](scripts/e2e.sh) that validates the
templates themselves (JSON-after-substitution, shellcheck, agent-neutrality,
line budgets).

## License

MIT
