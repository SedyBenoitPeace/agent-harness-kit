---
name: harness-continuous
description: Starts a continuous run when invoked by name (harness-continuous), never from a keyword — builds feature after feature with one fresh subagent each, skips what it cannot finish instead of stopping, and ends with a script-built run report. Never asks the human anything mid-run. Optional start instruction: a cap ("cap 20") or a milestone range ("through M21"). For an interactive run that stops at the first problem, use harness-run.
---

# Harness Continuous

The human invokes this command and walks away. It keeps going past
features it cannot finish, then leaves a report: what got done, what was
skipped and the question each skip needs answered, what was not started
and why. It reuses harness-run's dispatch and verify steps **by
reference** and adds only the rules below. It needs the CLI's normal
permissions only — never a skip-all-permissions flag.

**Announce at start:** "Using harness-continuous for an unattended run."

## Rules

- Never asks the human anything during the run. An unclear start
  instruction means the defaults: cap 10, stop at the milestone boundary.
- Never push. Never discard work: leftover changes are stashed, not reset.
- Own tools only — never load an external workflow skill.
- Run state lives in `.git/harness-run/` (never committed, no `.gitignore`
  change needed): `.git/harness-run/start` (the start commit),
  `.git/harness-run/skip` (one id per line), `.git/harness-run/STOP` (the
  human creates it to end the run after the current feature).

## Start

1. Run `bash ../harness-session/scripts/context.sh` (path relative to this
   skill) from the target repo root. Any **baseline problem** → write the
   report (see End) with that reason and STOP: exit 2 or 3, a dirty
   worktree, `UPGRADE: offer`, a `PREFLIGHT:` line, or a red baseline gate
   (`bash ../harness-session/scripts/run-gate.sh baseline <target>`).
2. Create `.git/harness-run/`, write `git rev-parse HEAD` to `start`, and
   empty `skip`. Delete a `STOP` left over from an earlier run; invoking
   the command is the signal to start.

## Loop

1. Run `bash ../harness-session/scripts/context.sh --skip .git/harness-run/skip`.
   Stop (then End) when: `NEXT: none` · the feature cap is reached
   (default 10, the human may name another; every dispatched feature
   counts, skips included) · `.git/harness-run/STOP` exists (delete it,
   then stop).
2. **Milestone boundary:** when `NEXT` belongs to a different milestone
   than the current one, stop there by default. If the start instruction
   named a range ("through M21") and the next milestone is within it,
   create that milestone's branch from the current one (stacked branches,
   no push) and continue; beyond the range, stop.
3. Dispatch and verify exactly as harness-run Workflow steps 3–5 (the named
   `harness-builder` agent, its `SESSION:` line, then `status.sh --skip
   .git/harness-run/skip` and `git status --short` as proof), including its
   Evaluator step and Parallel lanes. A blocked parallel lane becomes a skip.
4. Verified (`NEXT` no longer names the id, tree clean) → print
   `<id> passing · <commit>`, loop.
5. **Skip, don't stop,** when the session is `blocked`, its gate is red, or
   the evaluator returned NEEDS_WORK twice (where harness-run would
   STOP and relay):
   1. leftover changes → `git stash push -u -m "harness-run skip <id>"`;
   2. append to the feature's `notes`: "Unattended <date>: skipped —
      <reason>. Question for the human: <one question>";
   3. commit FEATURES.json only ("harness-run: skip <id>");
   4. add the id to `.git/harness-run/skip`; loop.
6. A dispatch that produced neither a commit nor a recorded skip (no
   SESSION line, id still next, dirty tree) → stop, leaving the tree as it
   is, and End.

**No subagent tool:** run one harness-session inline for `NEXT:`, then End.

## End

Run `bash ../harness-run/scripts/run-report.sh <start-commit> --skip
.git/harness-run/skip --stop-reason "<why the run stopped>"`, commit the
file it prints (explicit path), and print that path as the last line. Skips
and stashes are recoverable from the report and `git stash list`.

## Red flags

| Thought | Reality |
|---|---|
| "I'll ask the human how to proceed" | Never asks. Skip with a question in the notes. |
| "Blocked — stop the run" | That is harness-run. Here a blocker is a skip. |
| "Discard the half-done changes" | Stash them; nothing is ever thrown away. |
| "Next milestone is ready, keep going" | Only when the start instruction named a range. |
| "Push the branch when done" | Never push; the owner decides. |
