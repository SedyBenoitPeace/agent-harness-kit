# agent-harness-kit

Full long-running-agent harness toolkit — scaffold in-repo
FEATURES.json / PROGRESS.md / execution plans / e2e gate into any project,
and audit repos for harness-readiness. Ships as a Claude Code plugin plus a
portable protocol usable by any AI agent.

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
| Is the repo healthy right now | `bash scripts/e2e.sh` (exit 0 = green) |
| Not on Claude Code | [Other agents](docs/guide/other-agents.md) |

Each skill also answers to plain English; see
[Using the skills](#using-the-skills--copy-paste-prompts).

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


## Install

Claude Code (recommended):

```
/plugin marketplace add SedyBenoitPeace/agent-harness-kit
/plugin install agent-harness-kit
```

Update with `claude plugin update agent-harness-kit`; the next session
offers the repo upgrade itself ([Upgrading](docs/guide/upgrading.md)).
Manual fallback (no plugin): copy `skills/harness-initial-setup` into
`~/.claude/skills/`. Codex, Pi, Copilot CLI, the template repository and
any other agent: [Other agents](docs/guide/other-agents.md). The optional
Claude Code edition (`/plugin install agent-harness-kit-claude`, safe
unattended runs on auto mode, budgets):
[Claude Code edition](docs/guide/claude-code-edition.md).

## The skills

One short section each; the full behaviour of every skill is in
[Claude Code plugin in depth](docs/guide/claude-code.md).

### harness-brief

Turns a rough prompt into `docs/briefs/<date>-<slug>.md`. It looks up what
the repo already answers, asks the rest as questions in numbered rounds
(each with a recommended answer) until nothing is open, then an
independent reviewer returns `READY` or `GAPS`. Lifecycle: brief → plan →
run ([Workflow](docs/guide/workflow.md)).

### harness-initial-setup

Interviews you about the product, then scaffolds the whole harness:
AGENTS.md, PRODUCT.md, FEATURES.json, PROGRESS.md, ARCHITECTURE.md,
`docs/plans/`, the protocol in `docs/agents/` and `scripts/e2e.sh`. Works
from scratch, on an existing codebase, or from a PRD
([Planning](docs/guide/planning.md)).

### harness-session

One bounded coding session for one feature: a short brief from
`context.sh`, a green baseline, the failing check first, the code, the
final gate, a commit and a PROGRESS.md entry with a `Decisions:` line.
Builds and tests run through `quiet.sh`; the gate through `run-gate.sh`.

### harness-run

Many features in one conversation: each runs as a harness-session in a
fresh subagent, independent features run as parallel lanes, and an
opt-in independent evaluator judges UI work. It stops at the first
problem. A live run board shows every open feature.

### harness-continuous

An unattended run: a feature it cannot finish is skipped (work stashed,
question recorded) instead of ending the run, and a report lands in
`docs/runs/`. `touch .harness-run/STOP` ends it after the current feature
([Unattended runs](docs/guide/unattended-runs.md)).

### harness-status

Progress per milestone, the last session and the exact next feature. In a
terminal, `status.sh --line` prints one line and `status.sh --watch`
keeps it current.

### harness-audit

Checks any repo's harness-readiness with a deterministic script and
offers fixes without applying them. It warns about features only a human
can verify and features that can never run as a parallel lane.

### harness-upgrade-structure

Brings a repo that already has a harness up to the structure the
installed plugin ships, in one deterministic step
([Upgrading](docs/guide/upgrading.md)).

### harness-handoff

Verifies the session-end ritual (clean tree, gate status, logged session)
and prints a paste-ready prompt naming the one feature the next agent,
of any vendor, should build.

### harness-issues

GitHub issues as the place to write features:
`/agent-harness-kit:harness-issues migrate` moves open features to issues,
`… sync` brings them back into FEATURES.json; a `bug` issue becomes a
failing `kind: bug` feature ([Planning](docs/guide/planning.md)).

### harness-retro

After a run, one page of facts from `retro-facts.sh` and at most 5 ranked
fixes (a gate check or a dated AGENTS.md rule), offered, never applied.

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
| Periodic cleanup              | _"Read AGENTS.md, then docs/agents/harness-protocol-maintenance.md, and perform one maintenance pass."_       |


## The guide

The deep detail lives in `docs/guide/`:

- [Claude Code plugin in depth](docs/guide/claude-code.md) — every skill, the run board, the evaluator.
- [Workflow, models and decisions](docs/guide/workflow.md) — lifecycle, decision notes, model sizes, second opinion.
- [Planning and acceptance checks](docs/guide/planning.md) — start from scratch, PRDs, checks, GitHub issues, merging PRs.
- [Unattended runs](docs/guide/unattended-runs.md) — harness-continuous, stopping, run reports.
- [Upgrading](docs/guide/upgrading.md) — existing repos, every release, upgrade then run continuously.
- [Other agents](docs/guide/other-agents.md) — Codex, Pi, Copilot CLI, template repository, any agent, switching agents.
- [Claude Code edition](docs/guide/claude-code-edition.md) — auto mode, budgets, mods.
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
  the domain-driven design opt-in and the recommended local skills above.
  The kit writes those ideas in its own words and depends on none of his
  skills.
- **show-me** — the visual-explanation skill by Dex Horthy / HumanLayer:
  <https://www.humanlayer.com/blog/show-me-skill>. The harness asks agents
  to use it, when installed, for explanations and summaries (status
  reports, close-outs, architecture walkthroughs) instead of prose. It is
  not bundled; install it with `npx skills add humanlayer/skills --skill show-me`.

## License

MIT
