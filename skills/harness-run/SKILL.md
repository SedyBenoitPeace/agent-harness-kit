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
3. Dispatch the agent's own built-in subagent with exactly:
   "Use harness-session for <id>, inline. End with its SESSION line."
   Own tools only — never load an external workflow skill.
4. Read only the subagent's final line:
   `SESSION: <id> · <passing|blocked> · gate <green|red> · <commit|reason>`
5. Verify from the repo, not from the subagent's word: run
   `bash ../harness-status/scripts/status.sh` and `git status --short`.
   The run continues only when `NEXT:` no longer names <id> and the
   worktree is clean.
6. Anything else — `blocked`, `gate red`, a missing SESSION line, <id>
   still next, or a dirty tree → relay the subagent's reason to the human
   in one or two lines and STOP. Do not retry or fix it yourself.
7. Print one progress line per feature (`<id> passing · <commit>`), then
   loop to step 1.

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
