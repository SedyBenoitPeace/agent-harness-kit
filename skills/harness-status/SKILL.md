---
name: harness-status
description: Use when asked where a harnessed project stands, what was done so far, what to do next, or for a progress/status report on a repo using the long-running-agent harness — reads FEATURES.json and PROGRESS.md via a deterministic script and reports milestone progress, the exact next feature, and last-session notes; tells the user if the harness is not initialized.
---

# Harness Status

Read-only "where am I?" report for a harnessed repo. The mechanical
parsing lives in `scripts/status.sh` — run it, never re-derive it by hand.

**Announce at start:** "Using harness-status to report where this project stands."

## Workflow

1. Run `bash scripts/status.sh` (path relative to this skill) from the
   target repo root.
   - Exit 3 → harness not initialized: tell the human plainly, offer the
     harness-setup skill, STOP.
   - Exit 2 → a harness file is broken: relay the message, suggest the
     harness-audit skill, STOP.
2. Add the one thing the script can't see: `git log -5 --oneline` for
   recent commit context.
3. Relay the report: milestone rollup, totals, last session, and the
   NEXT feature — this is the same pick a coding session (protocol §2)
   would make, so "what to do next" is deterministic.
4. Offer `--run-gate` only if the human wants health confirmed — gates
   can be slow.
5. Status is read-only. Change nothing, flip no statuses. To do the
   work, start a coding session (protocol §2).

## Red flags

| Thought | Reality |
|---|---|
| "I'll parse FEATURES.json myself" | The script is the parser. Run it. |
| "While I'm here I'll flip that stale status" | Status is read-only. Report; a session changes state. |
| "Not initialized — I'll just scaffold it now" | Offer harness-setup; the human decides. |
| "Status and audit are basically the same" | Audit = is the harness well-formed. Status = how is the work going. |
