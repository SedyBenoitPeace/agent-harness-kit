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
ARCHITECTURE.md                system diagram, module map, cross-cutting invariants (the technical shape)
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

**Already have requirements?** If the human provides a requirements
document (a PRD, spec, or brief — markdown, PDF, or HTML all work), read
it first and extract answers to the questions above from it. Then
interview only the gaps and ambiguities, quoting the document when
confirming an interpretation. A provided document never waives §1.4:
every feature still needs a falsifiable `verify`, whoever authored the
requirement.

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

### 1.7 Choose the verification tooling

A `verify` criterion is only as strong as the tool that executes it.
During the interview (§1.1, question 5), name the proof tooling for the
stack and wire it into the gate:

| Stack | Feature proof |
|---|---|
| Web UI | Drive the running app with browser automation (e.g. Playwright): assert on rendered DOM or a screenshot, never on unit tests alone |
| HTTP API / backend | Call the real endpoint (e.g. curl or an integration test): assert status code and response body |
| CLI tool | Run the built binary with real arguments; assert stdout/stderr and exit code |
| Mobile | Widget/UI tests, plus a simulator or emulator run for demoable flows |
| Library | Unit tests against the public API; a runnable example doubles as proof |

**Rule: every demoable milestone gets at least one end-to-end proof in the
gate — a check that exercises the product the way its user would. Unit
tests alone cannot flip a user-facing feature to `passing`.**

### 1.8 Write ARCHITECTURE.md

PRODUCT.md captures the why and FEATURES.json the scope; `ARCHITECTURE.md`
(repo root) captures the technical shape, so sessions stop re-deriving it
from code. Copy `ARCHITECTURE.md.tmpl` and fill every section: system
diagram, module map with real paths, key entities & data flow,
**cross-cutting invariants** (the rules no feature may violate — the
section agents need most), and per-milestone subsystem notes.

- **Greenfield:** fill it from the interview and the first plan. It
  describes the *intended* architecture — say so in the opening line, and
  correct it as reality lands.
- **Retrofit:** derive it from reading the codebase, then have the human
  review it before committing. A wrong invariant is worse than a missing
  one.

**Detail rule:** record shape and invariants — the scoping rule every
query honors, a queue's dedup key format, "the daily import updates,
never inserts" — not code listings or API signatures. Depth accumulates
per milestone through §2.5, not up front.

Copy-paste planning prompt:

```
Read docs/agents/harness-protocol.md section 1 and run the planning
protocol for this repository. Interview me before writing anything.
```

## 2. Coding-session protocol

Run this every working session. A session delivers exactly **ONE feature**,
proven and committed. Resist the urge to batch — the one-feature discipline
is what keeps every session recoverable and every commit reviewable.

### 2.1 Recover context

In this order, before anything else:

1. `git log -20` — what actually happened recently.
2. `PROGRESS.md` — what the last session did, and what it said comes next.
3. `FEATURES.json` — read `_instructions`, then the feature list.

Trust the repo over your assumptions. If PROGRESS.md and the git log
disagree, the git log wins; note the discrepancy in your session entry.

### 2.2 Pick the feature

Among features with `status: "failing"`: lowest milestone, then lowest id.
Skip `deferred` and `superseded`. Do not pick by interest or apparent ease —
the ordering is the plan.

### 2.3 Confirm a green baseline

Run `bash scripts/e2e.sh` before touching code. If it is red, **fixing the
gate is the session** — do that instead, and log it as such. Never build on
a red baseline: you can't tell your breakage from inherited breakage.

### 2.4 Implement, test-first

Write the test (or set up the manual check) that proves the feature's
`verify` criterion. Watch it fail. Implement the minimum that makes it pass.
Watch it pass. Then re-run the full gate.

### 2.5 Close out

1. Re-run `bash scripts/e2e.sh` — must be green.
2. Flip your feature's status to `"passing"` — only yours, and only because
   its `verify` criterion is now demonstrably satisfied. Never touch other
   entries; append notes if something surprising happened.
3. If the feature changed the technical shape — a new module, entity,
   cross-cutting invariant, or dependency direction —
   update ARCHITECTURE.md in the same commit, while the knowledge is
   fresh. New subsystems get their note under "Subsystem notes".
4. Commit with a message naming the feature id.
5. Append a PROGRESS.md entry at the top: branch, what was done, gate
   status, and the next feature.

If the feature is not done when you must stop: commit what is safe, leave
the status `"failing"`, and write exactly where things stand in PROGRESS.md
— the next session starts from that note.

### 2.6 Branch discipline

- Branch off the default branch. Never branch off another feature branch.
- One branch per milestone-chunk of work; small, focused commits within it
  (ideally one per feature).
- Integrate via pull request, not local fast-forward. After merge, update
  the local default branch before cutting the next branch. If the repo has
  no remote yet, merge locally with `--no-ff` and note the deviation in
  PROGRESS.md.
- Stage explicit paths; avoid `git add -A` (it picks up stray build output).

Copy-paste session prompt:

```
Read AGENTS.md, then docs/agents/harness-protocol.md section 2, and
perform exactly one coding session.
```

## 3. Maintenance protocol

Agent-built codebases accumulate entropy: generated code replicates existing
patterns, including the bad ones, and docs drift from reality. Run this
protocol on a cadence — every few milestones, or whenever sessions start
feeling harder than they should.

### 3.1 Entropy garbage collection

Scan for drift from the repo's documented conventions (naming, structure,
error handling, test patterns). Fix what you find in **small, focused
cleanup branches** — one concern per branch, integrated like any other work.
Never a big-bang rewrite: it destroys the git history's usefulness as
context and is unreviewable.

### 3.2 Doc gardening

- AGENTS.md stays ≤100 lines and current — it must never claim a state the
  repo isn't in.
- ARCHITECTURE.md is read against the code it describes. A section reality
  contradicts gets corrected — or the code does: a violated invariant is a
  defect to fix, not a doc line to soften.
- Stale docs are updated or deleted; a doc that lies is worse than no doc.
- Plans whose work is done move from `docs/plans/active/` to
  `docs/plans/completed/`.

### 3.3 FEATURES.json gardening

- Features that will never happen become `superseded` (never deleted — the
  history is the point).
- `deferred` entries get their notes re-checked: is the blocking condition
  gone? If so, flip to `failing` so the ordinary session loop picks them up.

### 3.4 When something fails, ask "what's missing?"

When a session goes wrong — wrong feature picked, gate skipped, convention
violated — the fix is usually a missing tool, guardrail, or doc, not "try
harder." Add the missing check to the gate, the missing rule to this
protocol, or the missing pointer to AGENTS.md. Feed every failure back into
the repo.

Copy-paste maintenance prompt:

```
Read AGENTS.md, then docs/agents/harness-protocol.md section 3, and
perform one maintenance pass. Open one cleanup branch per concern found.
```
