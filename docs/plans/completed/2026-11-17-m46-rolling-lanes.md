# M46: rolling lanes

**Goal:** a parallel run keeps up to 3 lanes busy: a slot is refilled as soon
as any builder or evaluator finishes, instead of waiting for a whole batch.

## Evidence (one private run, numbers only)

- Two lane builders took about 4 minutes each; evaluation, rework and
  re-evaluation held the next batch for 36 minutes. Builders took 3–7 min,
  evaluators 2–13 min: review rounds, not builds, set a batch's pace.
- Late in the run the orchestrator, asked by the owner, started lanes by
  hand in the background beside a running rework (4 agents at once),
  outside the kit's rules.

## M46-001

- `context.sh --busy FILE`: running lanes keep their files, `exclusive`
  value and cap slots; one new lane is enough beside them, and an
  ineligible NEXT no longer blocks a refill while lanes run (it waits for
  them to drain).
- harness-run "Parallel lanes": start, wait for the next finisher, handle
  only that lane (evaluator inside the lane worktree; merge + gate + flip
  per lane; a conflicted id stays busy until it can be redone alone),
  refill. No feature runs outside a lane while any lane is busy.
- harness-continuous reuses it; a lane harness-run would stop for becomes a
  skip (a red merge is undone first) and the other lanes keep rolling.
- `run-start.sh` empties `.harness-run/busy`.
- Tests: test-session.sh (busy files, exclusive and cap; one lane beside a
  busy one; ineligible NEXT), test-run.sh (run-start busy, skill wording).
