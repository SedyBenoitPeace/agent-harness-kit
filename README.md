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
  harness feature."_ Only feature work runs the session: moving a file,
  formatting or an ordinary doc edit is a small task the agent does,
  checks once and stops (AGENTS.md says what counts). The session starts from a short brief (`context.sh`:
  the current milestone, the next feature's full entry and plan section,
  the newest PROGRESS entry, under 80 lines); FEATURES.json, PROGRESS.md,
  plans and docs are then read on demand with `grep` or `sed -n`, never
  whole. One read rule for every file: `grep -n` first, then `sed -n` ≤80
  lines; never `cat` a source file over 200 lines. Builds, simulators and tests run through `quiet.sh <name> --
  <command>`, which keeps the full log in `.harness-run/logs/` and prints
  only the exit code, the log path, up to 40 error/fail/warning lines and
  the last 20 lines; `run-gate.sh` prints the same shape. A session that
  passes about 60 tool calls or 150k tokens of context commits what is
  safe, notes where to resume and ends `blocked · session budget`.
  Project-specific readiness checks are optional and live in the target
  repo's own `scripts/preflight.sh`.
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
  by `scripts/gen-agents.sh` from one source in `agents/`, at setup and by
  the upgrade; harness-run dispatches the builder by name, never a stand-in.
- **harness-status** — where the project stands: progress per milestone,
  last session, exact next feature. `/agent-harness-kit:harness-status` or
  _"what's the harness status?"_.
- **harness-audit** — check any repo's harness-readiness.
  `/agent-harness-kit:harness-audit` or _"audit this repo's harness"_.
  It also warns when a failing feature's `verify` needs something only you
  can give (a live session, your machine, a device, a push, a PR, an
  answer: that belongs in the plan's `## Before the run`), when an active
  plan declares neither `depends_on` nor `paths` (no parallel lanes
  possible), and, for information only, when your global Codex, Claude
  Code or Copilot setup has a memory or workflow server or plugin that may
  add its own instructions to every session. It never edits your setup.
- **harness-handoff** — verify the session-end ritual (clean tree, gate
  status, logged session) and get a paste-ready prompt for the next agent,
  any vendor. It reuses the last green gate run (`GATE: green (last green
  run, unchanged)`), notes when the tree changed since, and runs the full
  gate only with `--run-gate`. `/agent-harness-kit:harness-handoff` or _"prepare the
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
   ARCHITECTURE.md, docs/plans/, the protocol in docs/agents/,
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
- **Per-feature effort.** Every feature still to build carries `"effort":
  "low" | "medium" | "high" | "max"`: how much verification and edge-case
  testing it deserves. It is required: `harness-audit` fails a failing,
  review or deferred feature without it, and `harness-upgrade-structure`
  lists the ones an older repo is missing.
  UI work rarely gains from high effort; APIs, data and security do.
  `harness-status` prints it under `NEXT:`, sessions scale their checking
  to it, and `harness-run` passes it to the agent it dispatches (as the
  CLI's own effort setting where there is one). The evaluator always runs
  at high or above. The kit names no
  models: every agent runs on its CLI's default. Pick your strongest model
  for hard features and reviews, a cheaper one for implementation.
- **Rules that expire.** Start lean: add an AGENTS.md rule only for a
  failure you have seen more than once, and end it with
  `(added <YYYY-MM-DD>)`, plus `; model: <name>` when it fixes one model's
  failure. `harness-audit` flags rules older than 90 days, and model-tagged
  ones to re-test when you change models: drop each, run a session or two,
  delete it if nothing breaks. The kit holds itself to the same standard:
  the gate caps the protocol's session core at 150 lines and the AGENTS.md
  template at 70.

## Choosing a model size

Every feature still to build carries `"model": "small" | "medium" |
"large"`: which size of model builds it. Like `effort` it is required:
`harness-audit` fails a failing, review or deferred feature without it, and
`harness-upgrade-structure` lists the ones an older repo is missing. It is separate from `effort`, which only sets how hard the
model checks its own work. Any size works with any effort.

| Size | Use it for |
|---|---|
| `small` | Narrow, well-specified work that follows a pattern already in the repo, checked by one command: scaffolds, docs, CHANGELOG and version bumps, config, renames, fixtures |
| `medium` | The default and the safe choice: new logic, several files, debugging |
| `large` | Design calls others build on, security or isolation, cross-cutting refactors |

In an older FEATURES.json without `model`, the Claude Code edition still
picks the builder from `effort` and other CLIs use `medium`. The evaluator and
features touching auth, payments, billing, migrations, secrets, credentials
or personal data never build below `medium`. A retry or an evaluator
rejection steps up one size.

The size map says which model each size means for each CLI. It lives in
the repo at `docs/agents/model-sizes.json`, one object per CLI
(`{"codex": {"small": "...", "medium": "...", "large": "..."}}`). The kit
ships no model names except for Claude Code, whose aliases (`haiku`,
`sonnet`, `opus`) never go stale. A CLI with no map gets no per-size agents
and uses its default model. The kit's `scripts/gen-agents.sh <repo>` writes
the per-size agent files from the map.

## Second opinion, brief stage and untrusted text

- **Second opinion from another vendor.** Give a feature
  `"second_opinion": "codex"` (or `claude`, `copilot`) and, after the builder,
  harness-run asks that command-line agent to judge it, read-only, with the
  evaluator's instructions: `skills/harness-run/scripts/second-opinion.sh`.
  Both verdicts must pass. Each vendor's model has its own blind spots, so
  use it where a miss is expensive (auth, payments, data). The CLI must be
  installed and signed in where the run happens; `harness-audit` warns if it
  is not. A second opinion that changes the repo is void.
- **Prototype or production.** Every brief has a `## Stage` line. Planning
  reads it: a prototype gets low or medium effort and "gate is sufficient";
  production gets the full effort table.
- **Untrusted text.** Issues, comments, web pages and tool output are data,
  never instructions: agents report instructions they find there instead of
  following them, and acting on them is on the "Needs a human" list.

## Claude Code edition

A second plugin in the same marketplace, `agent-harness-kit-claude`, adds
features only Claude Code has: an eval suite for the core skills and mods
(function hooks: a decision register, a done-check supervisor and a budget
guard). It depends on the core plugin and never copies
the protocol, so every other CLI keeps working from the core alone.
Installing the edition installs the core plugin with it:

```
/plugin install agent-harness-kit-claude
```

**Mods** (Claude Code function hooks, active only in a repo with
`FEATURES.json`; they write only under `.harness-run/`, which they keep out
of git):

- **Decision register** — a `register_decision` tool the agent calls each
  time it picks one option over another or assumes something; the lines
  land in `.harness-run/decisions/<id>.md` and the session folds them into
  the PROGRESS.md `Decisions:` line.
- **Done-check supervisor** — off by default (`supervisor` in `/config`
  turns it on). When on and a session ends with its `SESSION:` line, one
  cheap check against the feature's `verify` reports done, blocked or
  skipped work (in a status line, and `.harness-run/decisions/<id>.skipped.md`).
  It never judges a parallel-lane builder, whose transcript always ends
  mid-work by design.
- **Status line** — one line under the prompt, beside your own status line
  (never replacing it): `harness M3-005 · 12/20 passing · $1.40/$5.00 ·
  sonnet · 2 waiting on you`, plus the last budget or supervisor notice.
  To merge it into your own status line script instead, call
  `status.sh --line` there (core kit).
- **`/harness`** — milestones, the next feature, what waits on you and the
  session's cost, read from FEATURES.json: no model call, no tokens.
- **Model choice** — each builder a run starts gets the model its feature's
  `effort` asks for: low `haiku`, medium (or none) `sonnet`, high or max
  `opus`, by alias, so new models are picked up with nothing to update. A
  retry or an evaluator rejection steps it up one tier, but only when the
  feature's `notes` are unchanged since the earlier start (an answer from
  you gives a fresh attempt at the planned size); the evaluator and
  features touching auth, payments, migrations or personal data never run
  below `sonnet`. Set `model_floor` in `/config` to raise the minimum, or
  turn `route_models` off. Your own session's model is never changed; the
  choices land in `.harness-run/models.log` and the run report.
- **Budget guard** — budgets in dollars, from Claude Code's own cost
  figure (subagents included; on a subscription it is the list-price
  equivalent, still right for comparing and capping). Over
  `feature_budget_usd` (default $5) or `run_budget_usd` (default $50) during
  an unattended run it writes `.harness-run/STOP`, so the run ends after the
  current feature, and logs why in `.harness-run/budget.log`; 0 turns a
  budget off. Each feature's cost lands in `.harness-run/cost.log` and the
  run report. Features built in parallel share one figure. The cost
  split, budgets and pending usage reset when a new run starts
  (`.harness-run/start` changes), so each run reports alone.
- **Session budget notice** — at 80% of `session_budget_tokens` (default
  150000, 0 turns it off) of a builder's context, the status line shows
  `session budget: Nk of Mk tokens, wrap up`.
- **Orchestration cost** — the run's total is split into time a builder or
  evaluator was running and time the orchestrator ran alone (dispatching,
  verifying, merging lanes, gates), counted once even with parallel lanes,
  in `.harness-run/run-cost`. The run report's Summary shows that split and
  the feature dollars per model, so a heavy `opus` share is easy to spot.
- **Token usage** — where the CLI exposes token usage, the run report shows
  tokens per feature (input, cached, output), the run's tokens split into
  feature agents and orchestration, and tokens by model. Claude Code, Codex
  and Copilot each log their own usage to `.harness-run/usage.log`; a CLI
  with no usage shows no token lines.

Upgrading from 3.2.0: the edition was briefly named `agent-harness-kit-mods`;
run `/plugin uninstall agent-harness-kit-mods`, then install
`agent-harness-kit-claude`.

**Unattended runs on auto mode.** Start Claude Code with
`claude --permission-mode auto` and invoke `harness-continuous`. Auto mode
checks each action against what you actually allowed (writing to a
database, issuing keys, using the computer) instead of asking you, so the
run keeps going without unchecked access. Never use the bypass mode or a
skip-all-permissions flag.

**Evals for the core skills.** `claude/evals/` holds an eval suite for
`harness-brief` and `harness-session`: each case seeds a small repo, runs
the prompt with and without the plugin, and grades the files it leaves
behind. Run it from the repo root (it costs model usage, about $2 for the
suite at 3 runs per case):

```
claude plugin eval . --eval-dir claude/evals --scaffold --allow-tools Write Bash Edit
```

Run it after changing a skill or its description, and after a model
change. A `skill-fired` indicator that fails means the description did not
trigger the skill.

## Upgrading existing repos

After updating the plugin, bring each repo that already has a harness up to
date with `harness-upgrade-structure` (new repos use
`harness-initial-setup`); the full checklist is in "Upgrading after every
release" below. It recopies the protocol, adds the missing harness-run line
to `AGENTS.md`, regenerates your agent files, prints the release notes you
still need, and lists what still needs you (an unbounded gate,
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

## Upgrading after every release

Do this in every harnessed repo each time the kit releases (watch the repo or
read [CHANGELOG.md](CHANGELOG.md)). It takes a few minutes and is the same
every time:

1. **Update the plugins**: `claude plugin update agent-harness-kit` (and
   `agent-harness-kit-claude` if you use it), `codex plugin marketplace
   upgrade agent-harness-kit`, or `copilot plugin update agent-harness-kit`.
2. In the repo, start from a clean default branch; the upgrade makes its own
   branch, `harness-upgrade`.
3. Run **harness-upgrade-structure** (or `upgrade.sh` by hand, above). It
   recopies the protocol, regenerates your agent files, records the kit
   version in `docs/agents/harness-kit-version`, and lists what is left.
4. Read every `UPGRADE-NOTE: <version>: …` line it prints: the Upgrade steps
   from the CHANGELOG for each release since your last upgrade, oldest first.
   Do them.
5. Run **harness-audit** and fix any FAIL.
6. Run the gate: `bash scripts/e2e.sh` must be green.
7. Review `git diff`, then commit the upgrade as its own commit.
8. Open a pull request and merge it before the next feature.

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
- **Waiting on a human.** A feature that needs you (an approval,
  credentials, production access) is `deferred` with `notes` starting
  `Needs a human: <question>`: planning asks for it, and a session that
  hits such a blocker defers its own feature that way. Status and the report
  list these questions; features whose `depends_on` reaches one are held,
  so no run spends time rediscovering the blocker. Answer, then set the
  feature back to `failing`.
- **Reused baseline.** A builder whose tree is identical (PROGRESS.md and
  plans aside) to the last green gate run in this clone skips its baseline
  gate: `GATE: green (baseline reused …)`. `HARNESS_GATE_REUSE=0` turns it off.
- **Stops** when nothing eligible is left, at the cap, when you create
  `.harness-run/STOP`, on a baseline problem (dirty tree, `UPGRADE: offer`,
  a red gate), or when a dispatch produced neither a commit nor a skip.
- **Run state** lives in `.harness-run/` (start commit, skip list, stop
  file). `run-start.sh` begins each run: it adds `.harness-run/` to
  `.gitignore` in its own commit if needed, and moves the previous run's
  logs and results into `.harness-run/previous/<old start>/` (kept, never
  deleted), so a report only ever sees its own run.
- **One wait per builder.** Each builder's last act writes
  `.harness-run/results/<id>.txt` (its `SESSION:` line and a short
  summary); the orchestrator blocks once per builder (the CLI's own wait,
  or `wait-result.sh <id>`), never polls or steers a running builder, and
  reads only script output, never whole skills, plans, PROGRESS.md or
  FEATURES.json.
- **Briefed builders.** The orchestrator pastes `feature.sh <id>` (the
  feature entry and its plan section) into each builder's prompt instead of
  the plan's path, and the builder starts from `context.sh --brief`, which
  adds the protocol card (§2.9) and the repo's AGENTS.md Rules and Needs a
  human sections. A briefed builder never reads SKILL.md, AGENTS.md, the
  protocol files, FEATURES.json or the plan.
- **Session budget.** A builder that stops on its session budget is
  retried once in a fresh session at the same size; a second budget stop
  is a skip.
- **Shared resources.** Features that set the same `exclusive` value (e.g.
  `simulator`, `device`, `database`) never run in the same parallel batch;
  others still can.
- **Never pushes.** With `through M<n>` it creates one stacked branch per
  milestone and leaves them local.
- **The report**, `docs/runs/<date>.md`, is built by `run-report.sh` from
  git and FEATURES.json (no model calls) and committed: done (with minutes
  per feature, and dollars and the model with the Claude Code edition, plus
  the run's cost split into feature agents and orchestration, and by model;
  tokens per feature and by model where the CLI exposes them; each
  feature's `Decisions:` comes from its own commit or the PROGRESS entry
  that commit added, never from a planning entry), skipped (with each
  question), waiting on a human, not started and why, branches used.
- **Archive.** After the report, `archive-features.sh` moves every
  milestone whose features are all `passing` or `superseded` from
  FEATURES.json to `docs/features-archive.json` (same schema, appended).
  Status, the session brief, the report and the audit still resolve
  archived ids, so FEATURES.json stays small.
- **Watching it from a terminal.** In a second tab, run
  `bash <kit>/skills/harness-status/scripts/status.sh --watch` in the repo:
  the status report redrawn every 5 seconds (`--watch 30` for every 30),
  no model calls, any agent. For one line in your own status line script,
  add the output of `status.sh --line`, e.g.
  `harness M3-005 · 12/20 passing · 2 waiting on you · $4.10 this run`; it
  prints nothing outside a harnessed repo, so your line stays as it was
  there.
- **Builders start from the feature's `paths`**, when FEATURES.json has
  them, instead of searching the repo for their files.

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
4. The upgrade already generated the builder and evaluator agent files
   (`scripts/gen-agents.sh <repo>` regenerates them); restart Copilot CLI
   afterwards if you use it, so it loads them.

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
| Periodic cleanup              | _"Read AGENTS.md, then docs/agents/harness-protocol-maintenance.md, and perform one maintenance pass."_       |

## Quickstart — template repository

Prefer starting a project from a ready-made scaffold? Instantiate
[agent-harness-template](https://github.com/SedyBenoitPeace/agent-harness-template)
(_Use this template_ on GitHub), open it with any agent, and say _"Read
AGENTS.md and follow its initialization instructions."_ The template mirrors
`skills/harness-initial-setup/templates/` — this repo stays the canonical source.

## Quickstart — any other agent

You need the four protocol files in
[`skills/harness-initial-setup/templates/`](skills/harness-initial-setup/templates/):
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

## Start a repo from scratch — just chat

You don't need a requirements file to get a clean harness. Describe the
project in the chat and tell the agent to use the plugin; the planning
interview is answered from what you wrote and only the gaps are asked.

1. **Install the plugin** for your agent (see the quickstarts above) and open
   an empty directory in it.
2. **Say what you're building, and name the harness.** Cover the six
   questions from the planning protocol (§1.1) in your own words: the
   product and who it's for, the one end-to-end walkthrough that proves v1,
   the stack and what already exists, what is out of scope, how to run and
   test it locally, and what "done" means for the first milestone. Also say
   which parts need you (signing, permissions, real devices) and that
   nothing may claim to run in the background unless it is scheduled.
3. **Review what comes back.** The agent writes the plan, then scaffolds.

Example:

```
Use the agent-harness-kit plugin to create an execution-ready plan for a
habit-tracker web app, starting with a daily check-in page that stores
streaks, then reminders and a weekly summary. Node and Playwright are
installed on my machine. Inspect the available project context and use the
harness planning workflow; determine what can run unattended locally versus
what needs me (accounts, API keys, deploys, real-device checks). Do not claim
background execution without a scheduled task. Ask only for truly blocking
details.
```

What you get, in one commit-ready scaffold:

| Output | Where it comes from |
| --- | --- |
| `docs/PRODUCT.md`, the first plan in `docs/plans/active/`, `ARCHITECTURE.md`, and any extra docs the project needs | written for your project from the interview |
| `AGENTS.md`, `CLAUDE.md` pointer, `FEATURES.json`, `PROGRESS.md`, `scripts/e2e.sh`, `scripts/dev.sh` | shipped templates, placeholders filled in |
| `docs/agents/harness-protocol*.md` | copied unchanged from the plugin |
| `.claude/agents/`, `.codex/agents/`, `.github/agents/` | generated by `scripts/gen-agents.sh` (builder, evaluator, brief reviewer) |

Then run _"Audit this repo's harness."_ It reports what is missing and offers
fixes without applying them. Typical first findings: the first feature is
`failing` although it waits on your approval (should be `deferred` with
`Needs a human: ...`), nothing is committed yet, and `evaluate`/`bar` or
`paths` are not set. Approve the fixes, commit the scaffold, and start with
_"Implement M1-001 following the harness."_

Why this stays clean: the protocol forbids a feature without a falsifiable
`verify`, forbids marking device or UI acceptance passing on unit tests, and
the audit checks the protocol docs byte-for-byte against the shipped copy.

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
│       ├── harness-protocol.md   ★ the agent-neutral manual: session core + index
│       ├── harness-protocol-{planning,runs,maintenance}.md  read only when needed
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
│   └── scripts/
│       ├── status.sh              deterministic progress/next-feature report
│       └── archive-features.sh    moves fully done milestones to the archive
├── harness-handoff/
│   ├── SKILL.md        handoff orchestration: ritual check + prompt relay
│   └── scripts/handoff.sh        session-end checks + next-agent prompt
├── harness-session/
│   ├── SKILL.md        session orchestration: bounded recovery + gate
│   └── scripts/
│       ├── context.sh             short session brief + PARALLEL lanes (--brief: protocol card)
│       ├── run-gate.sh            concise gate wrapper, full log retained
│       └── quiet.sh               any build/test command: log on disk, capped summary
├── harness-run/
│   ├── SKILL.md        multi-feature orchestrator: one subagent per feature
│   └── scripts/
│       ├── feature.sh             one feature's entry + plan section, pasted into the brief
│       ├── run-report.sh          end-of-run report from git + FEATURES.json
│       ├── run-start.sh           fresh run state, previous run archived
│       └── wait-result.sh         one blocking wait for a builder's result
├── harness-continuous/
│   └── SKILL.md        unattended run: skip what it cannot finish, then report
└── harness-upgrade-structure/
    ├── SKILL.md        runs upgrade.sh, explains, commits as its own commit
    └── scripts/upgrade.sh         idempotent upgrade of an existing harness
agents/
└── src/                neutral harness-builder / harness-evaluator roles
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
