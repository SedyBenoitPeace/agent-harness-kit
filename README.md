# agent-harness-kit

Make AI coding agents finish long projects. The kit puts the plan, the
scope, the history and a one-command health check **in your repo**, so any
agent (Claude Code, Codex, Copilot CLI, Pi, Cursor, Gemini CLI, a plain chat
model) picks up where the last one stopped and delivers one proven feature
per session, or many unattended. Ships as a plugin plus a plain-markdown
protocol any agent can follow.

## What do I run when

| Situation | Run |
| --- | --- |
| A rough idea, not yet a plan | `/agent-harness-kit:harness-brief` |
| A repo with no harness (new or existing code, or a PRD) | `/agent-harness-kit:harness-initial-setup` |
| Build the next feature, or one named feature | `/agent-harness-kit:harness-session` |
| Build a milestone or many features, stop at the first problem | `/agent-harness-kit:harness-run` |
| Build unattended, skip what cannot finish, report at the end | `/agent-harness-kit:harness-continuous` |
| Where does the project stand, what is next | `/agent-harness-kit:harness-status` (terminal: `status.sh --line`, `status.sh --watch`) |
| Is this repo harness-ready | `/agent-harness-kit:harness-audit` |
| The plugin was updated (`UPGRADE: offer`) | `/agent-harness-kit:harness-upgrade-structure` |
| End a session or switch to another agent | `/agent-harness-kit:harness-handoff` |
| Features or bugs live in GitHub issues | `/agent-harness-kit:harness-issues` |
| A run finished, find what slowed it | `/agent-harness-kit:harness-retro` |
| A bug report | a feature with `"kind": "bug"`, or a GitHub issue labelled `bug` ([Bugs](#bugs-reproduce-before-fixing)) |
| Shared vocabulary and recorded decisions | domain-driven design opt-in ([below](#domain-driven-design-glossary-and-adrs)) |
| Is the repo healthy right now | `bash scripts/e2e.sh` (exit 0 = green) |
| Not on Claude Code | [Install](#install) |

Each skill also answers to plain English; see
[Using the skills](#using-the-skills--copy-paste-prompts).

## What is the harness approach?

AI coding sessions are short; projects are long. Plans left in chat
scrollback, scope kept in the model's head, and decisions made verbally all
die when the session ends. The harness makes **the repo the only
interface**: any agent, from any vendor, recovers full context from the repo
alone. It distills two published practices:
[Anthropic — Effective harnesses for long-running agents](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents)
and [OpenAI — Harness engineering](https://openai.com/index/harness-engineering/).

What setup puts in your repo:

| File | What it holds |
| --- | --- |
| `AGENTS.md` (+ `CLAUDE.md` / `GEMINI.md` importing it with `@AGENTS.md`) | the table of contents agents read first: the session loop, rules, what needs a human |
| `FEATURES.json` | every feature with a falsifiable `verify`, a status, and the fields below; the source of truth for scope |
| `PROGRESS.md` | newest-first session log; every entry has a `Decisions:` line (options rejected, assumptions made) |
| `docs/plans/active/` | one plan per milestone; finished ones move to `docs/plans/completed/` |
| `docs/PRODUCT.md`, `ARCHITECTURE.md` | what you are building and its shape (modules, invariants, the logging/observability approach) |
| `docs/agents/harness-protocol*.md` | the protocol, copied unchanged from the kit (session core capped at 150 lines) |
| `scripts/e2e.sh` | the gate: one command, exit 0 = green, run at the start and end of every session |
| `.claude/agents/`, `.codex/agents/`, `.github/agents/` | builder, evaluator and brief-reviewer agents, generated per CLI |

A session reads `git log`, PROGRESS.md and FEATURES.json, picks the lowest
failing feature, confirms a green gate, writes the failing test for one
check, makes it pass, runs the gate, flips the feature to `passing` in the
same commit and logs the session. Nothing is "done" without proof.

## Install

| Agent | Install | Update |
| --- | --- | --- |
| Claude Code (recommended) | `/plugin marketplace add SedyBenoitPeace/agent-harness-kit` then `/plugin install agent-harness-kit` | `claude plugin update agent-harness-kit` |
| Codex CLI | `codex plugin marketplace add https://github.com/SedyBenoitPeace/agent-harness-kit` then `codex plugin add agent-harness-kit@agent-harness-kit` | `codex plugin marketplace upgrade agent-harness-kit` |
| Copilot CLI | `copilot plugin marketplace add https://github.com/SedyBenoitPeace/agent-harness-kit` then `copilot plugin install agent-harness-kit` | `copilot plugin update agent-harness-kit` |
| Pi Coding Agent | `pi install git:github.com/SedyBenoitPeace/agent-harness-kit` | `pi update --extensions` |
| Any other agent | copy the four `harness-protocol*.md` files from `skills/harness-initial-setup/templates/` into `docs/agents/` | recopy them |
| New project from a scaffold | _Use this template_ on [agent-harness-template](https://github.com/SedyBenoitPeace/agent-harness-template) | — |

Optional, Claude Code only: `/plugin install agent-harness-kit-claude` adds
dollar budgets, a status line, model routing per feature and an eval suite
([Claude Code edition](docs/guide/claude-code-edition.md)). Details for each
agent, and how to switch agents mid-project:
[Other agents](docs/guide/other-agents.md).

After any plugin update, the next session prints `UPGRADE: offer`; run
harness-upgrade-structure and do the `UPGRADE-NOTE:` steps it prints
([Upgrading](docs/guide/upgrading.md)).

## Your first hour

1. **Brief.** _"Brief this: a habit tracker with daily check-ins and
   streaks."_ harness-brief looks up what the repo already answers, asks
   the rest in numbered rounds (each question with a recommended answer;
   "yes" accepts it), and saves `docs/briefs/<date>-<slug>.md` once nothing
   is open. Already have a PRD or an approved plan? Skip this step.
2. **Set up.** _"Set up the agent harness in this repo."_ (or _"…using
   docs/PRD.md as the product requirements."_). It interviews only the gaps,
   asks once whether you want domain-driven design, and writes the scaffold
   above. An existing codebase is preserved; a harnessed repo is left alone.
3. **Audit.** _"Audit this repo's harness."_ Approve its fixes (typically:
   `depends_on`/`paths` so features can run in parallel, features that wait
   on you marked `deferred` with `Needs a human:`). Commit the scaffold.
4. **Build one.** _"Implement M1-001 following the harness."_ Watch one
   session end to end: baseline gate, failing test, code, green gate,
   commit, PROGRESS entry.
5. **Build many.** _"Run the rest of milestone 1 with harness-run."_ or,
   to walk away, `/agent-harness-kit:harness-continuous through M3`.
6. **Check in.** `/agent-harness-kit:harness-status`, the run board, then
   the run report in `docs/runs/`. Review the branch and merge it.

## The skills

### harness-brief

Turns a rough prompt into a brief a stranger could build from. Facts come
from the repo and are never asked; decisions come from you, as
questions in numbered rounds, each with a recommended answer, until none
is open (say "don't ask" and the recommendations become visible
defaults). It also asks the
`## Stage` (prototype or production, which sets planning effort) and
`## Automerge`. A check script and an independent read-only reviewer
(`READY` or `GAPS`, at most 2 rounds) gate it. With a glossary it uses its
terms and offers an ADR for a decision later work must keep.

### harness-initial-setup

Interview → `PRODUCT.md`, `FEATURES.json`, the first plan → the whole
scaffold. Works from scratch, on an existing codebase, or from a PRD
(markdown, PDF or HTML). Asks once: _"Use domain-driven design (glossary +
ADRs)?"_ (default no). Ends with the agents generated for every CLI
([Planning](docs/guide/planning.md)).

### harness-session

One bounded session for one feature. It starts from a short brief
(`context.sh`, under 80 lines: the milestone, the next feature's entry and
plan section, the last PROGRESS entry), reads everything else with
`grep -n` + `sed -n` ≤80 lines, runs builds and tests through `quiet.sh`
(full log on disk, only errors and the tail printed) and ends after about
60 tool calls or 150k tokens with a resume point. Only feature work runs a
session: moving a file or fixing a doc is a small task, done and checked
once. Ends with one `SESSION:` line.

### harness-run

Many features in one conversation, one fresh builder subagent each,
verified from the repo (status script + clean tree) before the next.
Independent features run as **parallel lanes** in their own git worktrees,
up to 5 at once ([Parallel lanes](#parallel-lanes)). Features that opt in
get an independent evaluator. Stops at the first problem, the milestone
boundary (or `through M<n>`), or a cap of 10. A step only you can do comes
back as `scripts/wizard-<id>.sh`, which walks you through it and runs a
check, naming secrets but never holding them. A live run board
(`.harness-run/board.html`) shows every open feature: stage, agent, gate,
time, cost; click a row for all its fields, copy a STOP command, or leave a
hint the next builder reads ([Claude Code plugin in depth](docs/guide/claude-code.md)).

### harness-continuous

harness-run for when you walk away: a blocked feature, a red gate or a
second evaluator rejection becomes a **skip** (work stashed, never
discarded; one question for you in the feature's `notes`) and the run goes
on with everything that does not depend on it. Never asks, never pushes.
Options: `cap 20`, `through M22`. `touch .harness-run/STOP` ends it after
the current feature. Ends with `docs/runs/<date>.md`: done (time, cost,
tokens, decisions per feature), skipped with questions, waiting on you, not
started and why ([Unattended runs](docs/guide/unattended-runs.md)).

### harness-status

Progress per milestone, the last session, what waits on you, and the exact
next feature. No model needed in a terminal: `status.sh --line` (one line
for your status bar) and `status.sh --watch` (redrawn every 5 s).

### harness-audit

Deterministic harness-readiness check for any repo; offers fixes, never
applies them unasked. Flags features without `model`, `depends_on` or
`paths`, checks only a human can do, AGENTS.md rules older than 90 days,
and protocol copies that drifted from the kit.

### harness-upgrade-structure

After a plugin update: recopies the protocol, regenerates the agent files,
adds missing AGENTS.md lines, re-checks open plans against the current
protocol and prints the release notes you still need. Commits nothing.
`upgrade.sh --ddd .` also opts the repo into domain-driven design
([Upgrading](docs/guide/upgrading.md)).

### harness-handoff

Refuses a dirty tree or a red gate, then prints a paste-ready prompt naming
the one feature the next agent (any vendor) should build.

### harness-issues

Keeps features in GitHub issues so you can write and read them from your
phone ([GitHub issues](#github-issues-and-bug-intake)).

### harness-retro

After a run: `retro-facts.sh` prints one page of facts (red gates, retries,
rejections, budget stops, cost, checks whose test never failed first), and
the skill proposes at most 5 ranked fixes, each a gate check or a dated
AGENTS.md rule. Offered, never applied.

## Opt-in features

All off by default; a repo without them works exactly as before.

### Acceptance checks

A feature can carry `checks`: id (`M3-002.1`), title, `critical`, steps, a
"Pass if" a stranger can judge, and evidence (`test`, `screenshot`,
`human`). They are written while the brief is refined, before any code. The
builder writes one test per check, titled starting with the check id
(`"M3-002.1 cancel before the cutoff @critical"`), one red-green cycle at a
time; `check-coverage.sh` in the gate fails a missing, duplicate or
mistagged test ([Acceptance checks](docs/guide/planning.md#acceptance-checks)).

### Independent evaluator and second opinion

`"evaluate": "ui"` plus a `bar` (what to judge against) ends the session in
`review`; a separate read-only evaluator grades each check and
`acceptance-verdict.sh` turns that into PASS or NEEDS_WORK, recorded in
`docs/verification/<id>.md`. Two rejections stop (or, unattended, skip) the
feature. The evaluator also notes standards issues (`CODING_STANDARDS.md`,
`CONTRIBUTING.md`, a fixed code-smell list) as `NOTE:` lines that never
change the verdict. `"second_opinion": "codex"` (or `claude`, `copilot`)
adds a second judge from another vendor; both must pass.

### Parallel lanes

Give every feature `depends_on` (ids it cannot be built or tested without;
order alone is not a dependency) and `paths` (the files it changes, as
narrow as you can). Features that share no path and wait on nothing run at
the same time, each in its own worktree, and merge back as they finish.
Lanes follow dependencies, not milestones: `through M5` builds a later
milestone's independent feature early. README.md and CHANGELOG.md never
keep lanes apart; conflicts there are merged by keeping both sides
(`shared_paths` changes that list, `max_lanes` the cap of 5, `exclusive`
keeps features that share a simulator or database apart). Every feature
that waits prints `not a lane: <id> — <reason>`.

### Domain-driven design: glossary and ADRs

Say yes at setup, or run `upgrade.sh --ddd .` on an existing repo. It adds
`GLOSSARY.md` (term, definition, words to avoid), `docs/adr/0000-template.md`
and one AGENTS.md line. From then on the brief words its questions in
glossary terms and adds each newly settled one, offers an ADR when you
reject an option for a reason later work must keep, builders name tests and
code with glossary terms, and the evaluator notes a term that contradicts
it. Without `GLOSSARY.md` nothing changes.

### GitHub issues and bug intake

Set `"source": "issues"` in FEATURES.json, or let
`/agent-harness-kit:harness-issues migrate` do it (previews with
`--dry-run`, asks before creating; no plugin: `issues.sh migrate`). Each open feature becomes an issue
`[M12-003] title` with its checks in the body and a GitHub milestone. Then
`… sync` (a script; needs `gh` signed in, spends no tokens) pulls titles
and checks back into FEATURES.json and writes status, labels
(`harness:<status>`) and closes passing issues. Agents still read the
committed FEATURES.json, so one without GitHub access keeps working. Only
issues from people with write access count. An open issue labelled `bug`
with no `[id]` becomes a failing `"kind": "bug"` feature with the next id
and is retitled `[M12-004] title` ([Features in GitHub issues](docs/guide/planning.md#features-in-github-issues)).

### Bugs: reproduce before fixing

A feature with `"kind": "bug"` needs no brief: its checks are the reported
symptom. The builder first writes a test that fails on that symptom (not a
nearby failure; a flaky bug is looped until it reproduces), then tests one
hypothesis at a time and makes one root-cause fix. After 3 failed fixes it
stops with `Needs a human:` instead of guessing. The PROGRESS entry ends
with a one-line `Lesson:`. The evaluator returns NEEDS_WORK when the repro
test is missing or never failed before the fix.

### The agent merges its own PR

Answer yes to `## Automerge` in the brief and the feature gets
`"automerge": true`. Once its PR is green, the agent runs
`can-merge.sh <pr> --merge`, which merges only a PR labelled
`harness:agent` whose features are granted on the default branch, with a
green gate (or the CI checks you name), no protected path touched (CI,
auth, migrations, secrets, dependencies, deploy config, the gate) and no
test deleted, shrunk or skipped. Otherwise it leaves the PR to you with the
reasons. A guardrail against mistakes, not a wall: agents hold your token
([The agent merges its own PR](docs/guide/planning.md#the-agent-merges-its-own-pr)).

### Effort and model size

Every open feature needs `"model": "small" | "medium" | "large"` (which
size builds it; a retry steps up one size). Optional `"effort": "low" … "max"`
sets how hard it checks its own work. Sizes map to real models per CLI in
`docs/agents/model-sizes.json`; the kit names no models except Claude Code's
aliases ([Workflow, models and decisions](docs/guide/workflow.md)).

## FEATURES.json fields

| Field | Required | Meaning |
| --- | --- | --- |
| `id`, `milestone`, `title` | yes | `M3-002`; never renumbered or retitled |
| `status` | yes | `failing` (to build), `passing` (proven), `review` (awaiting the evaluator), `deferred` (postponed; `notes` say when), `superseded` (dead, kept) |
| `verify` | yes | the falsifiable "done when": a command or a check a stranger can run |
| `model` | open features | `small`, `medium`, `large` |
| `notes` | no | context; `Needs a human: <question>` marks a feature waiting on you, and `Needs a human: verify` one that is built and green with only your check left |
| `depends_on`, `paths` | for lanes | see [Parallel lanes](#parallel-lanes) |
| `checks` | no | acceptance checks |
| `kind` | no | `"bug"` |
| `effort` | no | `low`, `medium`, `high`, `max` |
| `evaluate`, `bar`, `eval_attempts` | no | evaluator opt-in; `eval_attempts` is written by the run |
| `second_opinion` | no | `claude`, `codex`, `copilot` |
| `exclusive` | no | a shared resource name (`simulator`, `database`) |
| `automerge` | no | `true` per feature; top-level object for `required_checks`, `protected`, `enabled` |
| `source` (top level) | no | `"issues"` |
| `shared_paths`, `max_lanes` (top level) | no | lane tuning |

## Troubleshooting

- **The run is sequential.** Read the `not a lane:` lines; usually a
  feature lacks `depends_on` or `paths`. harness-audit proposes them.
- **`AGENT: missing`.** The repo has no builder agent for this CLI: run
  `scripts/gen-agents.sh <repo>` (the kit's), commit, restart the CLI.
- **`UPGRADE: offer` or `PROTOCOL: outdated`.** Run
  harness-upgrade-structure, commit it on its own, then build.
- **`<id>: no test (title must start with <id>)`.** A test title must be a
  quoted string that starts with the check id; `"-- M3-002.1 …"` does not count.
- **A skipped feature.** Answer the question in its `notes`, set it back to
  `failing`; its work is in `git stash list` as `harness-run skip <id>`.
- **Green locally, red in CI.** Run `scripts/ci-local.sh` if your repo has
  one (a clean clone of the commit, as CI sees it), and merge the default
  branch into yours before opening the PR.
- **A feature waits on you.** `harness-status` lists every `Needs a human:`
  question; a run also writes a wizard script for steps only you can do.

## Using the skills — copy-paste prompts

| You want to… | Say |
| --- | --- |
| Turn an idea into a brief | _"Brief this: …"_ |
| Plan + scaffold a new project | _"Set up the agent harness in this repo."_ |
| Retrofit an existing codebase | _"Set up the agent harness in this repo — it's an existing codebase, preserve what's there."_ |
| Start from an existing PRD | _"Set up the harness using docs/PRD.md as the product requirements."_ |
| Check a repo is harness-ready | _"Audit this repo's harness."_ |
| See progress + what's next | _"What's the harness status?"_ |
| One unit of work (plugin) | _"Implement M1-004 following the harness."_ or _"Continue the current harness feature."_ |
| One unit of work (any agent) | _"Read AGENTS.md, then docs/agents/harness-protocol.md section 2, and perform exactly one coding session."_ |
| Many units of work | _"Run the rest of milestone 3 with harness-run."_ |
| Walk away | `/agent-harness-kit:harness-continuous through M5 cap 20` |
| Skip the harness for one change | _"Just build it."_ (no brief or plan; FEATURES.json still updated) |
| End a session / switch agents | _"Prepare the handoff for the next agent."_ |
| Learn from a run | _"Retro the last run."_ |
| Periodic cleanup | _"Read AGENTS.md, then docs/agents/harness-protocol-maintenance.md, and perform one maintenance pass."_ |

## The guide

- [Claude Code plugin in depth](docs/guide/claude-code.md) — every skill, the run board, the evaluator.
- [Workflow, models and decisions](docs/guide/workflow.md) — lifecycle, decision notes, model sizes, second opinion, untrusted text.
- [Planning and acceptance checks](docs/guide/planning.md) — from scratch, PRDs, checks, domain-driven design, GitHub issues, merging PRs.
- [Unattended runs](docs/guide/unattended-runs.md) — harness-continuous, stopping, run reports, archive.
- [Upgrading](docs/guide/upgrading.md) — existing repos, every release, upgrade then run continuously.
- [Other agents](docs/guide/other-agents.md) — Codex, Pi, Copilot CLI, template repository, any agent, switching agents.
- [Claude Code edition](docs/guide/claude-code-edition.md) — auto mode, budgets, mods, evals.
- [Repository layout](docs/guide/repository-layout.md) — what is where in this repo, dogfood.

## Recommended local skills

These skills from [mattpocock/skills](https://github.com/mattpocock/skills)
work well beside the harness. Install them yourself and call them by hand;
the kit never invokes them, because a harness run must not change with what
happens to be installed (builders follow kit files only).

- **grilling** — before a brief or a big decision, to be questioned until
  every branch is settled. Not in the kit: harness-brief already grills in
  numbered rounds; this is the free-standing version for any plan.
- **improve-codebase-architecture** — between milestones, to find shallow
  modules worth deepening. Not in the kit: it is open-ended review, not one
  bounded feature with a gate.
- **prototype** — when a state model or UI is unclear, to build a throwaway
  answer before planning. Not in the kit: throwaway code has no place in a
  test-first, committed feature.
- **codebase-design** — when designing a module's interface or choosing
  where a seam goes. Not in the kit: it is design vocabulary, and the kit
  keeps only the rules a builder must follow.
- **teach** — when you want to learn a concept or the code itself, not
  change it. Not in the kit: the harness builds features; teaching is for
  the human.

## Credits

- **mattpocock/skills** — Matt Pocock's skills,
  <https://github.com/mattpocock/skills> (MIT), inspired the brief grilling,
  the domain-driven design opt-in, bug intake and reproduction, the
  evaluator's standards pass, one check per red-green cycle, the wizard and
  the recommended local skills above. The kit writes those ideas in its own
  words and depends on none of his skills.
- **show-me** — the visual-explanation skill by Dex Horthy / HumanLayer:
  <https://www.humanlayer.com/blog/show-me-skill>. The harness asks agents
  to use it, when installed, for explanations and summaries (status
  reports, close-outs, architecture walkthroughs) instead of prose. It is
  not bundled; install it with `npx skills add humanlayer/skills --skill show-me`.

## License

MIT
