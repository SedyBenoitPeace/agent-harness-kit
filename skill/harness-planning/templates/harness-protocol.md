# The Harness Protocol

An operating manual for building software with AI agents across many short
sessions. It works with any agent — command-line coding agents, IDE
assistants, or a chat model you paste it into — because it has one rule at
its core:

> **The repo is the only interface. If it's not in the repo, it doesn't
> exist.**

Every plan, decision, scope change, and progress note lives in the target
repository. A fresh agent session — any vendor, any tool — must be able to
recover full working context from the repo alone.

This protocol distills two published practices:
[Anthropic — Effective harnesses for long-running agents](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents)
and [OpenAI — Harness engineering](https://openai.com/index/harness-engineering/).

A harnessed repository has this shape:

```
AGENTS.md                      ≤100 lines: table of contents + session loop summary
<vendor entry-files>           one-line pointers to AGENTS.md (never copies)
FEATURES.json                  source of truth for scope and status
PROGRESS.md                    newest-first session log for context recovery
scripts/dev.sh                 boots the dev environment
scripts/e2e.sh                 the gate: tests + analyzers, exit 0 = green
docs/
├── PRODUCT.md                 vision, users, UX concept, roadmap (the "why")
├── plans/
│   ├── active/                execution plans in flight, with decision logs
│   └── completed/             finished plans, kept for history
└── agents/
    └── harness-protocol.md    this document
```

The protocol has three parts: **planning** (section 1, run once per project
or major feature-set), **coding sessions** (section 2, run every working
session), and **maintenance** (section 3, run on a cadence).

## 1. Planning protocol

Run this when starting a new project (greenfield) or bringing the harness to
an existing codebase (retrofit). The output is a repository where any agent
can do useful work one session at a time. Planning is done when the gate is
green and everything below is committed.

### 1.1 Interview the human

Do not skip this, and do not answer these questions yourself. Ask, then
write the answers down in the artifacts that follow. The required questions:

1. What is the product, and who is it for?
2. What does v1 do end-to-end that makes it real — the single walkthrough
   that proves the product exists?
3. What stack are we using, and what already exists (code, designs, infra)?
4. What is explicitly out of scope for now?
5. How will we run and test it locally, from a clean checkout?
6. What does "done" look like for the first milestone?

If an answer is vague, push back once with a concrete alternative ("do you
mean X or Y?"). Ambiguity you accept here becomes an unfalsifiable feature
later.

### 1.2 Write docs/PRODUCT.md

Capture the "why" that outlives any session: the vision, the users, the UX
concept, and the roadmap at milestone granularity. This is the document a
future session reads to understand *intent* — keep it about the product, not
the implementation. A page or two is enough.

### 1.3 Cut milestones

Slice the roadmap into milestones where each one is a coherent, demoable
slice of the product — something a human can see working. Milestone 0 is
always the harness itself: gate running, scaffolding committed. Keep
milestones small enough that one is reachable within a handful of sessions.

### 1.4 Write FEATURES.json entries

Copy `FEATURES.json.tmpl` and fill it in — never improvise the schema. Each
feature gets:

- `id`: `M<milestone>-<3-digit sequence>`, e.g. `M1-004`. Never reused,
  never renumbered.
- `title`: what the feature is, in one line.
- `status`: `failing` (actionable), `passing` (done and proven), `deferred`
  (postponed; notes say when it becomes actionable), or `superseded` (dead,
  kept for history).
- `verify`: **the acceptance test.** How does an agent *prove* this feature
  works? This field is the whole game — it is what permits a status flip,
  and it doubles as the estimation unit when cutting scope.

Worked examples:

```
GOOD  "verify": "POST /login with wrong password returns 401 and no session
       cookie; test tests/auth_test.py::test_bad_password passes"

GOOD  "verify": "bash scripts/e2e.sh exits 0 with the new migration applied;
       'users' table has a 'last_seen' column (checked by the schema test)"

BAD   "verify": "login works correctly"          (unfalsifiable)
BAD   "verify": "code is clean and tested"       (not a criterion)
```

**Rule: refuse to add a feature you cannot state a falsifiable `verify`
for.** If you can't say how to prove it, you don't understand it yet — go
back to the interview.

Size each feature to be completable in one session, including its test. If
it doesn't fit, split it and let the ids reflect the order.

### 1.5 Write the first execution plan

Create `docs/plans/active/<date>-<milestone-name>.md` covering the first
milestone: the ordered task list, per-task verification, and a **decision
log** section at the bottom. Every non-obvious choice made during planning
gets a dated entry there. Plans are first-class artifacts: they are
committed, updated as work proceeds, and moved to `docs/plans/completed/`
when done.

### 1.6 Scaffold or adapt the gate

Copy `e2e.sh.tmpl` to `scripts/e2e.sh` and `dev.sh.tmpl` to
`scripts/dev.sh`, then replace the placeholders with the project's real test
and analyzer commands. The gate's contract:

- `bash scripts/e2e.sh` exits 0 **if and only if** the repo is healthy.
- It runs from a clean checkout with documented dependencies.
- It is fast enough to run twice per session without resentment.

**Retrofit rules** (existing codebase): existing agent entry-files
(AGENTS.md or equivalents) are preserved — extend and link, never clobber.
Existing tests become the initial gate. Existing code maps to `passing`
features only when a `verify` criterion actually proves it; otherwise it
enters as `failing` with honest notes.

Finish by running the gate, committing everything above, and writing the
first PROGRESS.md entry (copy `PROGRESS.md.tmpl`).

Copy-paste planning prompt:

```
Read docs/agents/harness-protocol.md section 1 and run the planning
protocol for this repository. Interview me before writing anything.
```

## 2. Coding-session protocol

Completed in the next revision.

## 3. Maintenance protocol

Completed in the next revision.
