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

Four skills come with it — invoke each as a slash command or in plain
English:

- **harness-setup** — interview → PRODUCT.md + FEATURES.json → scaffold the
  whole harness. `/agent-harness-kit:harness-setup` or *"set up the agent
  harness in this repo"*.
- **harness-status** — where the project stands: progress per milestone,
  last session, exact next feature. `/agent-harness-kit:harness-status` or
  *"what's the harness status?"*.
- **harness-audit** — check any repo's harness-readiness.
  `/agent-harness-kit:harness-audit` or *"audit this repo's harness"*.
- **harness-handoff** — verify the session-end ritual (clean tree, green
  gate, logged session) and get a paste-ready prompt for the next agent,
  any vendor. `/agent-harness-kit:harness-handoff` or *"prepare the
  handoff for the next agent"*.

Manual fallback (no plugin): copy `skills/harness-setup` into
`~/.claude/skills/`.

## Lifecycle — how the pieces fit

1. **Set up once** — `/agent-harness-kit:harness-setup`. Expect an
   interview about the product before anything is written; it ends with
   the full scaffold (AGENTS.md, FEATURES.json, PROGRESS.md, docs/plans/,
   docs/agents/harness-protocol.md, scripts/e2e.sh). Repos that are
   already harnessed are detected and left alone.
2. **Build one feature per session** — say *"Read AGENTS.md, then
   docs/agents/harness-protocol.md section 2, and perform exactly one
   coding session."* Repeat until the milestone is done.
3. **Check where you are** — `/agent-harness-kit:harness-status` any
   time: progress per milestone, what the last session did, and exactly
   which feature the next session will pick. If the harness isn't set up
   yet, it says so and points you to setup.
4. **Hand off cleanly** — `/agent-harness-kit:harness-handoff` when a
   session ends or you switch agents. It refuses to hand off a dirty tree
   or a red gate, and prints the exact one-feature prompt the next agent
   should be given.
5. **Keep it honest** — `/agent-harness-kit:harness-audit` when a repo
   drifts or before working in an unfamiliar one, plus a periodic
   maintenance pass (protocol section 3).

## Switching agents (e.g. Claude Code ↔ Codex)

The harness keeps all state in the repo, so agents from different vendors
can work the same project in shifts — plan and review with one, grind
features with another when you hit a usage limit. The ritual:

1. End the session with `/agent-harness-kit:harness-handoff` (or *"prepare
   the handoff"*). Blocked = fix first; ready = copy the printed prompt.
2. Feed the prompt to the next agent: paste it into the chat, or from a
   terminal `codex "<prompt>"` (interactive) / `codex exec "<prompt>"`
   (non-interactive). Codex, Cursor, and Gemini CLI read `AGENTS.md`
   natively, so the prompt plus the repo is the entire handoff.
3. When you come back, `/agent-harness-kit:harness-status` shows what the
   other agent did; review its diff before continuing.

One branch, one agent at a time — never point two agents at the same
branch concurrently.

## Using the skills — copy-paste prompts

| You want to… | Say |
|---|---|
| Plan + scaffold a new project | *"Set up the agent harness in this repo."* |
| Retrofit an existing codebase | *"Set up the agent harness in this repo — it's an existing codebase, preserve what's there."* |
| Start from an existing PRD | *"Set up the harness using docs/PRD.md as the product requirements."* |
| Check a repo is harness-ready | *"Audit this repo's harness."* |
| See progress + what's next | *"What's the harness status?"* |
| Do one unit of work | *"Read AGENTS.md, then docs/agents/harness-protocol.md section 2, and perform exactly one coding session."* |
| End a session / switch agents | *"Prepare the handoff for the next agent."* |
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
├── harness-audit/
│   ├── SKILL.md        audit orchestration: report + offer fixes
│   └── scripts/check.sh          deterministic readiness checker
├── harness-status/
│   ├── SKILL.md        status orchestration: read-only report
│   └── scripts/status.sh         deterministic progress/next-feature report
└── harness-handoff/
    ├── SKILL.md        handoff orchestration: ritual check + prompt relay
    └── scripts/handoff.sh        session-end checks + next-agent prompt
```

## Dogfood

This repo is built with its own harness: scope in [`FEATURES.json`](FEATURES.json),
sessions in [`PROGRESS.md`](PROGRESS.md), plans in [`docs/plans/`](docs/plans/),
and a lint gate in [`scripts/e2e.sh`](scripts/e2e.sh) that validates the
templates themselves (JSON-after-substitution, shellcheck, agent-neutrality,
line budgets).

## License

MIT
