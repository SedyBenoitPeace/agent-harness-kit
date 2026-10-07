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
plans in `docs/plans/`, the technical shape in `ARCHITECTURE.md` (module
map, cross-cutting invariants, and the chosen logging/observability
approach), and health behind one command —
`scripts/e2e.sh`, exit 0 = green. Any agent, from any vendor, recovers full context from the
repo alone and delivers exactly one proven feature per session.

The approach distills two published practices:
[Anthropic — Effective harnesses for long-running agents](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents)
and [OpenAI — Harness engineering](https://openai.com/index/harness-engineering/).

## Quickstart — Claude Code (plugin, recommended)

```
/plugin marketplace add SedyBenoitPeace/agent-harness-kit
/plugin install agent-harness-kit
```

These skills come with it — invoke each as a slash command or in plain
English:

- **harness-initial-setup** — interview → PRODUCT.md + FEATURES.json → scaffold the
  whole harness. `/agent-harness-kit:harness-initial-setup` or _"set up the agent
  harness in this repo"_.
- **harness-session** — run one coding session with bounded, non-mutating
  context recovery and a concise gate report. `/agent-harness-kit:harness-session`,
  _"Implement M1-004 following the harness."_, or _"Continue the current
  harness feature."_ Orchestration and gate-log compression (the
  `run-gate.sh` wrapper retains the full log while keeping the terminal
  report short) live in the plugin; project-specific readiness checks are
  optional and live in the target repo's own `scripts/preflight.sh`.
- **harness-run** — work through many features in one conversation
  without its context growing: each feature runs as a harness-session in
  a fresh subagent, verified from the repo before the next starts;
  script-proven independent features run as parallel lanes.
  `/agent-harness-kit:harness-run` or _"Run the rest of milestone 3."_
- **harness-upgrade-structure** — for repos that already have a harness:
  bring them up to the structure the installed plugin ships, in one
  deterministic step. `/agent-harness-kit:harness-upgrade-structure`. See
  [Upgrading existing repos](#upgrading-existing-repos).
- **harness-continuous** — an unattended run: like harness-run, but a
  feature it cannot finish is skipped (work stashed, question recorded)
  instead of ending the run, and it finishes with a report in
  `docs/runs/`. Invoked by name: `/agent-harness-kit:harness-continuous`.
  See [Unattended runs](#unattended-runs).
- **Independent evaluator** — features that opt in (`evaluate: "ui"` and a
  `bar` in FEATURES.json) end their session in `review`; harness-run then
  dispatches a separate, read-only `harness-evaluator` agent that returns
  `PASS` or `NEEDS_WORK` with evidence before the feature can become
  `passing`, and records `docs/verification/<id>.md`. The builder and
  evaluator agents are generated for Claude Code, Copilot CLI and Codex CLI
  by `scripts/gen-agents.sh` from one source in `agents/`.
- **harness-status** — where the project stands: progress per milestone,
  last session, exact next feature. `/agent-harness-kit:harness-status` or
  _"what's the harness status?"_.
- **harness-audit** — check any repo's harness-readiness.
  `/agent-harness-kit:harness-audit` or _"audit this repo's harness"_.
- **harness-handoff** — verify the session-end ritual (clean tree, green
  gate, logged session) and get a paste-ready prompt for the next agent,
  any vendor. `/agent-harness-kit:harness-handoff` or _"prepare the
  handoff for the next agent"_.

Update to the latest release:

```
claude plugin update agent-harness-kit
```

After an update, the next harness-session context report checks the
target repo against the shipped templates: an unbounded gate
(`GATE_OUTPUT: unbounded`) or an older protocol copy (`PROTOCOL: outdated`)
ends the report with `UPGRADE: offer`, and the agent proposes the
five-minute upgrade as its own commit before starting the feature.
Recopying the protocol brings in the orchestrated-run rules (§2.7), and
the same commit adds the harness-run line to AGENTS.md. The new
`depends_on` / `paths` fields in FEATURES.json are optional — absent fields stay sequential,
so existing repos keep working unchanged; harness-audit can propose
values for the remaining failing features, applied only on approval.
The evaluator is opt-in too: `evaluate` / `bar` are optional, and
harness-audit warns when features opt in but no evaluator agent file
exists (run `scripts/gen-agents.sh` to create them).

Manual fallback (no plugin): copy `skills/harness-initial-setup` into
`~/.claude/skills/`.

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

## Lifecycle — how the pieces fit

0. **Brief (optional)** — `/agent-harness-kit:harness-brief` turns a
   rough prompt into `docs/briefs/<date>-<slug>.md`: at most three
   questions, a mechanical check, and an independent read-only reviewer
   (`READY`/`GAPS`). Lifecycle: brief → plan → run. Setup then interviews
   only the gaps.
1. **Set up once** — `/agent-harness-kit:harness-initial-setup`. Expect an
   interview about the product before anything is written; it ends with
   the full scaffold (AGENTS.md, FEATURES.json, PROGRESS.md,
   ARCHITECTURE.md, docs/plans/, docs/agents/harness-protocol.md,
   scripts/e2e.sh). Repos that are already harnessed are detected and
   left alone.
2. **Build one feature per session** — say _"Read AGENTS.md, then
   docs/agents/harness-protocol.md section 2, and perform exactly one
   coding session."_ With the plugin installed, `/agent-harness-kit:harness-session`
   (or _"Implement M1-004 following the harness."_ / _"Continue the
   current harness feature."_) runs the same protocol with bounded
   context recovery and a concise gate report. The session proposes an
   execution mode — inline (default) or delegated to the agent's own
   built-in subagents — and never loads a third-party workflow plugin;
   plans are written with the agent's native plan mode (protocol §1.5).
   Repeat until the milestone is done — or let
   `/agent-harness-kit:harness-run` repeat it for you: one fresh subagent
   per feature, stopping at a blocker, the milestone boundary, or a cap
   of 10, and running independent features (declared `depends_on` /
   `paths`) as parallel lanes. To walk away entirely, invoke
   `/agent-harness-kit:harness-continuous` instead (see
   [Unattended runs](#unattended-runs)).
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

## Decision notes, effort and model-tagged rules

Three small habits from Anthropic's Claude Code team, built into the
protocol so every agent follows them:

- **Decision notes.** Every PROGRESS.md entry has a `Decisions:` line:
  the options the session considered and rejected, and the assumptions it
  made. Most wrong results are a right answer the agent thought of and
  turned down; written down, you (or the evaluator) can ask for the skipped
  option instead of rediscovering it. The evaluator reads the line as
  leads, never as evidence.
- **Per-feature effort.** A feature can carry `"effort": "low" | "medium" |
  "high" | "max"`: how much verification and edge-case testing it deserves.
  UI work rarely gains from high effort; APIs, data and security do.
  `harness-status` prints it under `NEXT:`, sessions scale their checking
  to it, and `harness-run` passes it to the agent it dispatches (as the
  CLI's own effort setting where there is one). The evaluator always runs
  at high or above. Leave it out and nothing changes.
- **Model-tagged rules.** Start lean: add an AGENTS.md rule only for a
  failure you have seen more than once, and end a rule written for one
  model's failure with `(model: <name>)`. When you change models,
  re-test those rules and delete the ones the new model no longer needs —
  `harness-audit` reminds you how many there are.

## Claude Code edition

A second plugin in the same marketplace, `agent-harness-kit-mods`, adds
features only Claude Code has: an eval suite for the core skills and mods
(function hooks: a decision register, a done-check supervisor, a budget
guard, a next-steps band). It depends on the core plugin and never copies
the protocol, so every other CLI keeps working from the core alone.

```
/plugin install agent-harness-kit
/plugin install agent-harness-kit-mods
```

## Upgrading existing repos

After updating the plugin, bring each repo that already has a harness up to
date with `harness-upgrade-structure` (new repos use
`harness-initial-setup`). It recopies the protocol, adds the missing
harness-run line to `AGENTS.md`, generates evaluator agent files only if
your features opt in, and lists what still needs you (an unbounded gate,
`depends_on`/`paths`). It refuses a dirty tree, creates `harness-upgrade`
when you are on the default branch, and commits nothing.

With the plugin: `/agent-harness-kit:harness-upgrade-structure`. Or by
hand, no agent needed, from your repo (adjust the plugin folder to your
CLI and version):

```
bash ~/.claude/plugins/cache/agent-harness-kit/agent-harness-kit/<version>/skills/harness-upgrade-structure/scripts/upgrade.sh .
```

(Codex keeps its copy under `~/.codex/plugins/cache/agent-harness-kit/`; or
run the script from a clone of this repository.) Review `git diff`, then
commit it as its own commit.

**Upgrading to 3.0.0:** `harness-setup` was renamed
`harness-initial-setup`; the old slash command no longer exists.

## Unattended runs

`harness-continuous` is its own command: invoke it and walk away. It
builds feature after feature — one fresh subagent each, like harness-run —
but a feature it cannot finish (a blocked session, a red gate, or two
evaluator `NEEDS_WORK` verdicts) is **skipped** instead of ending the run,
and it never asks you anything. It ends with a report.

Invoke it by name, with the options in the same message:

- Claude Code: `/agent-harness-kit:harness-continuous`
- any other agent with the plugin: ask for it by name, e.g. _"Run
  harness-continuous."_
- options: `cap 20` (default cap is 10 features) and/or `through M22`
  (cross milestone boundaries up to M22; without it the run stops at the
  first boundary).

Permissions are yours: it needs nothing beyond what a normal
harness-session already needs (run the gate, edit files, `git commit`), the
plugin never configures your agent's permissions, and it never needs a
skip-all-permissions flag. Anything your agent still refuses becomes a skip
with the reason in the report.

What it does, so nothing surprises you:

- **Skip, don't stop.** Leftover changes are stashed (`git stash push -u`,
  labelled `harness-run skip <id>`), never discarded; the feature's `notes`
  get the reason and one question for you; only FEATURES.json is committed.
  Skipping also excludes features that `depends_on` the skipped one — and,
  for features with no declared `depends_on`, every feature after it.
- **Stops** when nothing eligible is left, at the cap, when you create
  `.harness-run/STOP`, on a baseline problem (dirty tree, `UPGRADE: offer`,
  a red gate), or when a dispatch produced neither a commit nor a skip.
- **Run state** lives in `.harness-run/` (start commit, skip list, stop
  file). The run adds `.harness-run/` to `.gitignore` in its own commit if
  it is not there yet.
- **Never pushes.** With `through M<n>` it creates one stacked branch per
  milestone and leaves them local.
- **The report**, `docs/runs/<date>.md`, is built by `run-report.sh` from
  git and FEATURES.json (no model calls) and committed: done, skipped (with
  each question), not started and why, branches used.

## Upgrading a repo and running continuously

Do the steps in order. The upgrade is once per repo.

**Upgrade**

1. Update the plugin (`claude plugin update agent-harness-kit`,
   `codex plugin marketplace upgrade agent-harness-kit`, or
   `copilot plugin update agent-harness-kit`). In your repo, create a
   branch (`git checkout -b harness-upgrade`) and confirm a green gate:
   `bash scripts/e2e.sh`.
2. Run `/agent-harness-kit:harness-upgrade-structure` (a harness session
   points you to it with an `UPGRADE: offer`; see
   [Upgrading existing repos](#upgrading-existing-repos)). This release
   adds the continuous-run rules to protocol section 2.8, so every existing
   repo's protocol copy is outdated; the upgrade is its own small commit.
3. Run `/agent-harness-kit:harness-audit` and approve its `depends_on` and
   `paths` proposals. This step is essential: without declared `depends_on`,
   a skipped feature stops the run instead of letting it continue.
4. Only if you use the independent evaluator: the upgrade already
   generated the agent files (`scripts/gen-agents.sh <repo>` regenerates
   them); restart Copilot CLI afterwards if you use it.

**Run**

5. Make sure the tree is clean on the branch you want built, then invoke
   `/agent-harness-kit:harness-continuous` (or ask your agent to run
   harness-continuous), adding `cap 20` and/or `through M22` if you want
   them. See [Unattended runs](#unattended-runs) for what it does.
6. To stop early: `mkdir -p .harness-run && touch .harness-run/STOP`. It
   finishes the current feature, writes the report and stops.

**Afterwards**

7. Read `docs/runs/<date>.md`: what was done, skipped and not started.
8. For each skipped feature, answer the question recorded in its `notes`
   in FEATURES.json (fix the cause, or reword the feature). A later run
   starts with an empty skip list and retries them.
9. `git stash list` shows any stashed work, labelled
   `harness-run skip <id>`; `git stash show -p stash@{n}` to inspect,
   `git stash pop` to resume it.
10. Review the branch — or branches, if the run crossed milestones.
    Nothing is pushed; merging is yours.

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

## Using the skills — copy-paste prompts

| You want to…                  | Say                                                                                                         |
| ----------------------------- | ----------------------------------------------------------------------------------------------------------- |
| Plan + scaffold a new project | _"Set up the agent harness in this repo."_                                                                  |
| Retrofit an existing codebase | _"Set up the agent harness in this repo — it's an existing codebase, preserve what's there."_               |
| Start from an existing PRD    | _"Set up the harness using docs/PRD.md as the product requirements."_                                       |
| Check a repo is harness-ready | _"Audit this repo's harness."_                                                                              |
| See progress + what's next    | _"What's the harness status?"_                                                                              |
| Do one unit of work           | _"Read AGENTS.md, then docs/agents/harness-protocol.md section 2, and perform exactly one coding session."_ (manual fallback, any agent) |
| Do one unit of work (plugin installed) | _"Implement M1-004 following the harness."_ or _"Continue the current harness feature."_ |
| Do many units of work (plugin installed) | _"Run the rest of milestone 3 with harness-run."_ |
| End a session / switch agents | _"Prepare the handoff for the next agent."_                                                                 |
| Periodic cleanup              | _"Read AGENTS.md, then docs/agents/harness-protocol.md section 3, and perform one maintenance pass."_       |

## Quickstart — template repository

Prefer starting a project from a ready-made scaffold? Instantiate
[agent-harness-template](https://github.com/SedyBenoitPeace/agent-harness-template)
(_Use this template_ on GitHub), open it with any agent, and say _"Read
AGENTS.md and follow its initialization instructions."_ The template mirrors
`skills/harness-initial-setup/templates/` — this repo stays the canonical source.

## Quickstart — any other agent

You need exactly one file:
[`skills/harness-initial-setup/templates/harness-protocol.md`](skills/harness-initial-setup/templates/harness-protocol.md).

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
├── harness-initial-setup/
│   ├── SKILL.md        planning/scaffolding orchestration (thin)
│   └── templates/
│       ├── harness-protocol.md   ★ the agent-neutral operating manual
│       ├── AGENTS.md.tmpl        entry point scaffold (≤100-line map)
│       ├── FEATURES.json.tmpl    scope/status source of truth
│       ├── PROGRESS.md.tmpl      session log
│       ├── ARCHITECTURE.md.tmpl  system diagram + invariants (living doc)
│       ├── dev.sh.tmpl           dev-environment boot
│       ├── e2e.sh.tmpl           the gate
│       └── pointer.md.tmpl       one-line CLAUDE.md/GEMINI.md pointer
├── harness-audit/
│   ├── SKILL.md        audit orchestration: report + offer fixes
│   └── scripts/check.sh          deterministic readiness checker
├── harness-status/
│   ├── SKILL.md        status orchestration: read-only report
│   └── scripts/status.sh         deterministic progress/next-feature report
├── harness-handoff/
│   ├── SKILL.md        handoff orchestration: ritual check + prompt relay
│   └── scripts/handoff.sh        session-end checks + next-agent prompt
├── harness-session/
│   ├── SKILL.md        session orchestration: bounded recovery + gate
│   └── scripts/
│       ├── context.sh             bounded session context + PARALLEL lanes
│       └── run-gate.sh            concise gate wrapper, full log retained
├── harness-run/
│   ├── SKILL.md        multi-feature orchestrator: one subagent per feature
│   └── scripts/run-report.sh      end-of-run report from git + FEATURES.json
├── harness-continuous/
│   └── SKILL.md        unattended run: skip what it cannot finish, then report
└── harness-upgrade-structure/
    ├── SKILL.md        runs upgrade.sh, explains, commits as its own commit
    └── scripts/upgrade.sh         idempotent upgrade of an existing harness
agents/
├── src/                neutral harness-builder / harness-evaluator roles
└── models.json         tier -> model per CLI, sensitive-path globs
scripts/gen-agents.sh   emits the roles as Claude / Copilot / Codex agent files
```

## Dogfood

This repo is built with its own harness: scope in [`FEATURES.json`](FEATURES.json),
sessions in [`PROGRESS.md`](PROGRESS.md), plans in [`docs/plans/`](docs/plans/),
and a lint gate in [`scripts/e2e.sh`](scripts/e2e.sh) that validates the
templates themselves (JSON-after-substitution, shellcheck, agent-neutrality,
line budgets).

## Credits

- **show-me** — the visual-explanation skill by Dex Horthy / HumanLayer:
  <https://www.humanlayer.com/blog/show-me-skill>. The harness asks agents
  to use it, when installed, for explanations and summaries (status
  reports, close-outs, architecture walkthroughs) instead of prose. It is
  not bundled; install it with `npx skills add humanlayer/skills --skill show-me`.

## License

MIT
