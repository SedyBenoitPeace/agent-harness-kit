# The Harness Protocol: planning

Section 1 of the harness protocol, read when planning a project or a major
feature set. `harness-protocol.md` holds the coding-session core (section 2)
and the index of the other parts.

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
    ├── harness-protocol.md    the session core and index (every session)
    ├── harness-protocol-planning.md     section 1 (this document)
    ├── harness-protocol-runs.md         orchestrated and continuous runs
    └── harness-protocol-maintenance.md  section 3
```

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

**Already have a brief?** If `docs/briefs/` holds a brief written by the
harness-brief skill (or the human names one), read it first: its
Objective, Context and Non-goals answer the questions above, its Done-when
lines seed each feature's `verify`, and its Quality bar seeds
`evaluate`/`bar` (§1.4). Its Stage seeds `effort` and the bar: a prototype
gets `low` or `medium` effort and "gate is sufficient" unless the brief says
otherwise; production follows the §1.4 table, never below `medium` for APIs
and data. Interview only the gaps. Its Needs-a-human list
is a stop-and-ask boundary for sessions (a `blocked` outcome with a question), never an action taken.

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
  (postponed; notes say when it becomes actionable), `superseded` (dead,
  kept for history), or `review` (built, awaiting the independent
  evaluator, §2.7; only for features that opted in below).
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

Two optional fields let an orchestrated run (§2.7) build independent
features side by side. Ask for each feature, and record them only when the
answer is clear:

- **Depends on?** → `depends_on`: ids that must be `passing` first, e.g.
  `["M1-002"]`. Use `[]` for "nothing".
- **Paths touched?** → `paths`: the directories or globs the feature
  changes, e.g. `["src/billing/", "tests/billing/**"]`.

A feature with either field missing always runs sequentially — leaving
them out is always safe.

Ask one more question per feature: **Can the gate prove this? If not, what
is the bar?** A green gate proves tests pass, not that they test the right
thing; stubs, display-only controls and API-only features slip through.
When the gate cannot prove it (UI behaviour, look and feel, anything a
human would check by using it), record:

- `evaluate`: `"ui"` — an independent evaluator judges the feature (and
  drives the real UI) before it can become `passing`. `"none"` or absent
  means no evaluation.
- `bar`: a concrete, fetchable reference the evaluator compares against —
  a mockup file, a URL, a screenshot path, a numbered acceptance list.

Leaving both out is always safe: the feature flips on its `verify` alone.

For work where a miss is expensive (security, payments, data, anything the
gate proves only in part), ask: **Should another vendor's agent check it?**
Record `second_opinion`: the name of a command-line agent from another
vendor (the values FEATURES.json `_instructions` lists) that re-judges the
feature after the builder, read-only, as a second evaluator. A different vendor's model has different blind spots. Like
`evaluate`, it ends the building session in `review`. Leave it out unless the
named agent is installed where runs happen.

Last question per feature: **How much verification does this deserve?**
Record the answer as `effort`, one of low, medium, high or max. Effort
is spent mostly on verification and edge cases, so it pays where those
matter:

| Kind of feature | Effort |
|---|---|
| UI, copy, layout, simple wiring | `low` or `medium` |
| APIs, data handling, migrations, anything with many edge cases | `high` |
| Security, auth, payments, reviews of other work | `high` or `max` |

The session reads it as how much checking to do beyond the `verify`
check, and an orchestrator passes it to the agent it dispatches. Leaving
it out is always safe: the agent uses its usual effort.

### 1.5 Write the first execution plan

Write the plan with the agent's own **native plan mode** — whatever the
tool you are running in ships for planning (a plan/architect mode, a
planning subagent, or plain reasoning). Do not load a third-party
planning or workflow plugin to do it, and never put a header in the plan
that mandates one for execution: the next session may run in a different
agent, and such a skill front-loads hundreds of lines of process text
into context before any work starts.

Create `docs/plans/active/<date>-<milestone-name>.md` covering the first
milestone: the ordered task list, per-task verification, and a **decision
log** section at the bottom. Every non-obvious choice made during planning
gets a dated entry there. Plans are first-class artifacts: they are
committed, updated as work proceeds, and moved to `docs/plans/completed/`
by the session that finishes the plan's last feature (§2.5).

Head each task section with its feature id and keep it self-contained, so
a session reads only the section for its selected feature, never the
whole file.

Every plan opens with this header, verbatim, so that whoever picks it up
executes it through the harness and not through some other workflow:

```
> **For agentic workers:** each task below is one harness coding session.
> Run it with the harness-session skill if it is installed; otherwise
> follow docs/agents/harness-protocol.md section 2. Do not load any other
> workflow skill or plugin to execute this plan.
```

### 1.6 Scaffold or adapt the gate

Copy `e2e.sh.tmpl` to `scripts/e2e.sh` and `dev.sh.tmpl` to
`scripts/dev.sh`, then replace the placeholders with the project's real test
and analyzer commands. The gate's contract:

- `bash scripts/e2e.sh` exits 0 **if and only if** the repo is healthy.
- It runs from a clean checkout with documented dependencies.
- It is fast enough to run twice per session without resentment.
- Its terminal output is **bounded**: the template's `step` wrapper writes
  every command's full output to a log file, prints one line per passing
  step, and shows only the log's tail (plus its path as `FULL_LOG`) for
  the first failing step. Test runners and coverage tools are verbose in
  ways that vary by stack; the gate absorbs that so a session never
  spends context on it. `GATE_VERBOSE=1` streams everything when a human
  wants it. **Retrofit:** wrap the existing test commands in the same
  `step` calls rather than pasting them bare.

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

### 1.9 Choose the logging/observability approach

Name where logs land and how a future session inspects them — the same way
§1.7 names the verification tool. This is a **planning decision, not a
build task**: the human picks the technology (or that none is needed yet);
the harness only makes sure the choice is recorded and revisited instead of
silently skipped.

| Stack | Where logs land / how a session inspects them |
|---|---|
| Web UI | Browser console + a server-side request log; note the command that tails both |
| HTTP API / backend | Structured logs to stdout (or a file), one line per request with a correlation id; note the tail command |
| CLI tool | stderr for diagnostics, stdout reserved for real output; a `--verbose`/`--debug` flag |
| Mobile | OS-native log viewer (e.g. Console.app, `adb logcat`) plus any in-app diagnostic screen |
| Library | Caller-injected logger interface; no framework choice imposed on consumers |

Record the answer in `ARCHITECTURE.md`'s Cross-cutting invariants (e.g.
"every request logs a request id"; "errors always go to stderr as JSON").
If the repo has no logging infrastructure yet and building it is real work,
that becomes an ordinary `FEATURES.json` entry with a falsifiable `verify`
(e.g., "hit /health, confirm a JSON log line with request_id appears in
stdout") — built through the normal one-feature-per-session loop, not a
special flow.

**Rule: this step never blocks planning.** "No logging yet, revisit at
milestone N" is a legal, complete answer — the point is a decision on
record, not a silent gap.

Copy-paste planning prompt:

```
Read docs/agents/harness-protocol-planning.md and run the planning
protocol for this repository. Interview me before writing anything.
```
