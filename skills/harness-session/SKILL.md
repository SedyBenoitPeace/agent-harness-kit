---
name: harness-session
description: Use when asked to implement, continue, carry on, or execute a feature in a repo using the long-running-agent harness — runs one bounded coding session (context recovery, gate, red-green-refactor, close-out) instead of separate manual status/gate/log calls.
---

# Harness Session

Runs exactly one harness coding session (protocol §2) with bounded,
deterministic context recovery. `scripts/context.sh` replaces the manual
status + `git log` + `git status` + plan-grep sequence with one call.

**Announce at start:** "Using harness-session to run one coding session."

## Workflow

1. Run `bash scripts/context.sh` (path relative to this skill) from the
   target repo root.
   - Exit 3 / 2 → relayed from harness-status: not initialized or broken.
     Offer harness-setup / harness-audit, STOP.
2. If the report names `PREFLIGHT: scripts/<path>`, execute it now — it is
   discovered, never auto-run. Non-zero blocks the session; report it and
   STOP.
3. **Clean worktree:** run the baseline full gate through the wrapper —
   `bash scripts/run-gate.sh baseline <target>` (path relative to this
   skill). It runs the target's own `scripts/e2e.sh` unchanged, retains
   the complete output in the printed `FULL_LOG` path, and prints a
   bounded terminal report. A bounded report does not mean the gate can
   be ignored — treat a non-zero `run-gate.sh` exit exactly as a red
   gate, and read more of `FULL_LOG` if the printed tail isn't enough to
   diagnose it. Confirm green before touching code.
4. **Dirty worktree clearly matching the selected feature and plan**
   (the diff and the `PLAN:` match both point at the same `NEXT:` id):
   announce "CONTINUING INTERRUPTED FEATURE", inspect the existing diff,
   run the feature's focused verify command first, and never claim a
   clean baseline — state plainly that the full gate has not been
   re-confirmed from scratch.
5. **Dirty worktree that is unrelated or ambiguous** (no plan match, or
   the diff touches something other than the selected feature): stop and
   ask the human before doing anything else.
6. Follow red-green-refactor for the one selected feature only.
7. Do not investigate or expand a passing gate's warning that is already
   tracked by another failing or deferred feature, unless the selected
   feature's verify criterion requires it.
8. Run the final full gate through `bash scripts/run-gate.sh final
   <target>`, flip only the selected feature's status to `passing`,
   append one `PROGRESS.md` entry, commit explicit paths, then STOP —
   do not start a second feature.

## Red flags

| Thought | Reality |
|---|---|
| "I'll run status, then git log, then git status separately" | context.sh bundles them in one call. |
| "Dirty tree, but it's probably fine" | Only proceed on a clear match to the selected feature; otherwise ask. |
| "The gate showed an unrelated warning, let me fix that too" | Out of scope unless the selected verify requires it. |
| "I'll flip a second feature while I'm in here" | One feature per session, always. |
| "The report was short, so the gate must be fine" | Bounded output ≠ permission to ignore a non-zero exit; check `FULL_LOG`. |
