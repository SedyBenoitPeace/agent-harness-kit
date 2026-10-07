# The Harness Protocol: runs

§2.7 and §2.8, read only by an orchestrator. Every session it dispatches is
a normal section 2 session (`harness-protocol.md`).

### 2.7 Orchestrated runs

To work through many features without one conversation's context growing
per feature, an orchestrator conversation (the harness-run plugin skill)
dispatches each coding session to a fresh built-in subagent, then checks
the repo — not the subagent's word — before starting the next. Rules:

- Every dispatched session is a normal §2 session, run inline, ending
  with one line: `SESSION: <id> · <passing|review|blocked> · gate <green|red> · <commit|reason>`.
- The orchestrator never reads diffs or gate logs; a blocked session is
  relayed to the human and the run stops. It also stops at a milestone
  boundary and at a feature cap.
- Parallel lanes run only for features whose `depends_on` / `paths`
  (§1.4) prove them independent, computed by script, never guessed. Each
  lane works in its own worktree and never touches FEATURES.json or
  PROGRESS.md; it puts its `Decisions:` line in its commit message body.
  The orchestrator merges, runs one full gate, flips the statuses, and
  writes one PROGRESS.md entry carrying each lane's `Decisions:` line. A merge conflict means that
  feature is redone sequentially.
- Independent evaluation (opt-in per feature via `evaluate`, §1.4): the
  session that builds such a feature ends it in `review`, never
  `passing`. The orchestrator then dispatches the named agent
  `harness-evaluator` — read-only, given only the feature entry, the
  commit range and its `bar`, never the builder's transcript. It observes
  before judging (runs the app or the named check) and replies with a
  first line of exactly `PASS` or `NEEDS_WORK`, then numbered findings with
  file:line or repro steps. It may read the feature's latest PROGRESS.md
  `Decisions:` line as leads, not evidence: a rejected option that the
  `verify` or `bar` required is `NEEDS_WORK`. When any of the feature's
  `paths` touches auth, payments, personal data or migrations, it also runs a security
  checklist. After it returns, the orchestrator checks the tree is clean
  and HEAD unchanged; anything else rejects the verdict.
  - `PASS` → write `docs/verification/<id>.md` (verdict, findings, date,
    agent CLI) and flip the feature to `passing`.
  - **Second opinion** (`second_opinion` set, §1.4): after the evaluator, or
    in its place when `evaluate` is absent, the orchestrator runs the named
    command-line agent non-interactively and read-only on the same commit
    range, with the same instructions. Both verdicts must be `PASS`. If that
    agent changed the tree or HEAD, its verdict is void and the run stops
    for the human; if it is not installed, the feature cannot leave
    `review` (§2.8: a skip).
  - `NEEDS_WORK` → findings go into the feature's `notes`, the status
    returns to `failing`, `eval_attempts` increases by one, and the next
    session starts from those notes. At two attempts the orchestrator
    stops and relays to the human.
- No subagents available → run one normal session and stop.

### 2.8 Continuous runs

A continuous run is the orchestrated run of §2.7 with one difference:
nothing stops it for a feature it cannot finish. The human invokes the
`harness-continuous` plugin skill by name, optionally with a cap
("cap 20") or a milestone range ("through M22"), and walks away. Rules:

- It never asks the human anything. Run state lives in `.harness-run/`
  at the repo root (never committed, listed in `.gitignore`):
  `start` (the start commit), `skip` (one id per line), and `STOP`.
- A session blocked on a Needs-a-human item has already set its feature to
  `deferred` (`Needs a human: …`): the run only records the skip, and later
  runs leave it alone until the human answers and sets it back to `failing`.
- **Skip, don't stop** when a session is `blocked`, its gate is red, or
  the evaluator returns `NEEDS_WORK` twice: leftover changes go to
  `git stash push -u -m "harness-run skip <id>"` (never discarded); the
  feature's `notes` gain "Unattended <date>: skipped — <reason>.
  Question for the human: <one question>"; FEATURES.json alone is
  committed; the id joins `.harness-run/skip`. The next feature is chosen with
  `status.sh --skip .harness-run/skip`.
- A skip excludes the listed id, every failing feature whose `depends_on`
  names an excluded id (transitively), and every failing feature without
  `depends_on` that follows an excluded one — so a repo with no declared
  `depends_on` stops at its first skip, exactly like §2.7. Declaring
  `depends_on` (§1.4) is what lets a run continue.
- **Stop** (then write the report) on: nothing eligible left, the feature
  cap (default 10), the human creating `.harness-run/STOP` (honoured
  after the current feature), a baseline problem, or a dispatch that left
  neither a commit nor a recorded skip. A milestone boundary also stops
  the run unless the start instruction named a range; then each next
  milestone gets a stacked branch from the current one. Nothing is pushed.
- Every run ends with `run-report.sh`, which builds `docs/runs/<date>.md`
  from git, FEATURES.json, the skip file and the stop reason: what was
  done, what was skipped and the question each skip needs answered, what
  was not started and why, and the branches used; under each done feature
  its `Decisions:` line, and any skipped work or budget stop the run
  recorded. The report is committed.
- The human then reads the report, answers each question in that
  feature's `notes`, recovers any stashed work with `git stash list`, and
  reviews the branch. A later run starts with an empty skip list and
  retries skipped features.
