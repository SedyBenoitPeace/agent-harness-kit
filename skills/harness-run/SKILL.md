---
name: harness-run
description: Use when asked to run, work through, or build several features, a whole milestone, or "the rest of the plan" in one conversation on a repo using the long-running-agent harness — orchestrates one fresh subagent per feature (each a full harness-session) so the main context stays small.
---

# Harness Run

Orchestrates many harness sessions from one conversation. The main chat
only picks the next feature, dispatches it, and checks the result; each
feature runs as a normal harness-session inside a fresh built-in
subagent, so the orchestrator's context does not grow per feature.
Sessions already recover everything from the repo, so a fresh context
costs nothing.

**Announce at start:** "Using harness-run to orchestrate feature sessions."

For a run that keeps going past blocked features and ends with a report,
the human invokes the separate `harness-continuous` command; this skill
stays interactive and stops at the first problem.

## Workflow

1. Run `bash ../harness-session/scripts/context.sh` (path relative to this
   skill) from the target repo root.
   - Exit 3 / 2, a dirty worktree, `UPGRADE: offer`, or a `PREFLIGHT:`
     line → do not orchestrate; run one normal harness-session so the
     human sees and decides it, then STOP.
   - `NEXT: none` → report "run complete" and STOP.
2. Note the `NEXT:` id and its milestone (`M<n>`). Stop at the milestone
   boundary: when the next id belongs to a different milestone than the
   first one this run dispatched, report and STOP.
   Also stop at the cap (default 10 features per run; the human may name another).
3. Dispatch the named agent `harness-builder` (generated per CLI by
   `../../scripts/gen-agents.sh`; if absent, the agent's own built-in subagent) with exactly:
   "Use harness-session for <id>, inline. End with its SESSION line."
   Own tools only — never load an external workflow skill.
   When status.sh printed an `effort: <level>` line under `NEXT:`, the
   feature asks for that effort (protocol §1.4): set it as the dispatch
   tool's own effort setting if it has one, otherwise add the line
   "Effort: <level>." to the prompt. No line, no setting.
   When it printed a `paths:` line, add "Start reading from: <paths>." to
   the prompt, so the builder spends no round-trips finding its files.
4. Read only the subagent's final line:
   `SESSION: <id> · <passing|review|blocked> · gate <green|red> · <commit|reason>`
   A `review` line means the feature opted in (`evaluate` set): do the
   evaluator step below before step 5.
5. Verify from the repo, not from the subagent's word: run
   `bash ../harness-status/scripts/status.sh` and `git status --short`.
   The run continues only when `NEXT:` no longer names <id> and the
   worktree is clean.
   A `review` feature is not "next" (status.sh never selects it) but is not
   done either: it must leave `review` through the evaluator step.
6. Anything else — `blocked`, `gate red`, a missing SESSION line, <id>
   still next, or a dirty tree → relay the subagent's reason to the human
   in one or two lines and STOP. Do not retry or fix it yourself.
7. Print one progress line per feature (`<id> passing · <commit>`), then
   loop to step 1.

## Evaluator step

For a `review` session (only features with `evaluate` or `second_opinion`
set; absent means no evaluation and today's flow):

1. Record `git rev-parse HEAD`. Dispatch the named agent
   `harness-evaluator` (the evaluator at high or above: its effort setting
   if the dispatch tool has one, otherwise "Effort: high." in the prompt)
   with only: the feature entry, the commit range, its
   `bar`, whether `evaluate` is `ui` (QA mode), and — when any `paths`
   entry touches auth, payments, personal data or migrations — the
   security checklist. Never pass the builder's transcript. If the agent
   is missing, run `../../scripts/gen-agents.sh <target>` first, or STOP and tell the human.
2. Integrity check: `git status --short` must be empty and HEAD unchanged.
   Anything else rejects the verdict (the evaluator is read-only, but a
   parent's elevated permissions can reach child agents): discard its
   changes, relay to the human, STOP.
3. **Second opinion** (only when the feature has `second_opinion`): run
   `bash scripts/second-opinion.sh <cli> <id> <base-commit> <target>` (path
   relative to this skill; base = the commit before the feature's first).
   It runs that vendor's agent read-only with the same evaluator
   instructions and prints `VERDICT: PASS|NEEDS_WORK|REJECTED`. The feature
   passes only when both verdicts are `PASS` (a feature with only
   `second_opinion` and no `evaluate` skips step 1's dispatch: the second
   opinion is the evaluation). `REJECTED` (it changed the repo) or exit 2
   (CLI missing) → relay to the human and STOP. `NEEDS_WORK` → step 5 with
   its findings, prefixed with the CLI's name.
4. Both `PASS` → write `docs/verification/<id>.md` (verdict,
   findings and date, and each CLI that judged it), set the feature `passing`, one `PROGRESS.md`
   line, commit explicit paths.
5. Either verdict `NEEDS_WORK` → put the findings in the feature's `notes`,
   set it back to `failing`, add 1 to `eval_attempts`, commit explicit
   paths; the next session starts from those notes.
6. `eval_attempts` reaching 2 → relay the findings to the human and STOP.
   Any other first line counts as `NEEDS_WORK`.

## Parallel lanes

When `context.sh` prints `PARALLEL: <id> <id> …` (instead of
`PARALLEL: none`), those features declared `depends_on` / `paths` that
the script proved independent — never infer lanes yourself. Instead of
Workflow steps 3–5, for that batch:

1. For each id, create a lane from the current branch:
   `git worktree add ../<repo>-<id> -b lane/<id>`.
2. Dispatch one subagent per lane, in parallel, with exactly:
   "Use harness-session for <id>, inline, as a parallel lane in
   ../<repo>-<id>. End with its SESSION line."
   Lanes implement, run their own verify, commit, and never touch FEATURES.json or PROGRESS.md;
   each puts its `Decisions:` line in its commit message body.
3. Merge each `passing` lane into the current branch (`git merge --no-ff
   lane/<id>`), then remove its worktree and branch. A blocked lane is
   relayed to the human like step 6; its worktree stays for inspection.
4. Merge conflict → `git merge --abort`, drop that lane, and redo that feature sequentially after the others land.
5. Run one full gate (`bash ../harness-session/scripts/run-gate.sh final
   <target>`). Green → flip the merged ids to `passing`, write one
   `PROGRESS.md` entry naming them (with each lane's `Decisions:` line from
   its commit message), commit explicit paths. Red → STOP and
   report; flip nothing.
6. Verify as in Workflow step 5 (status.sh + clean tree), count the
   lanes toward the cap, and loop to Workflow step 1.

**No subagent tool** (the agent cannot dispatch subagents): run one
normal harness-session for `NEXT:` in this conversation and STOP — tell
the human to clear the context and invoke harness-run again.

The orchestrator never reads diffs or gate logs itself; a feature's
details stay in its subagent, its commit, and `PROGRESS.md`.

## Red flags

| Thought | Reality |
|---|---|
| "The subagent said passing, next one" | Verify with status.sh + clean tree first. |
| "Let me look at the diff to be sure" | Never. The commit and the gate are the proof. |
| "Blocked — I'll just fix it here" | Relay the blocker and stop; the human decides. |
| "Next milestone is ready too, keep going" | Stop at the milestone boundary. |
| "No subagents here, I'll run them all in this chat" | One session, then stop. That is the whole point. |
