# AGENTS.md — harness-planning skill

Open-source Claude Code skill + portable protocol pack for planning
applications with the long-running-agent harness approach (in-repo
FEATURES.json / PROGRESS.md / plans / e2e gate), consumable by any AI agent.

## State: designed, not yet planned or implemented

1. **Read the approved spec first:**
   `docs/specs/2026-07-03-harness-planning-skill-design.md`
2. **Next action:** write the implementation plan to `docs/plans/active/`
   (per spec §8, this repo dogfoods its own harness), then scaffold
   FEATURES.json + PROGRESS.md + `scripts/e2e.sh` and work one feature per
   session.

## Rules (from the spec — they apply to this repo too)

- Plans, decisions, and progress live in this repo. If it's not committed
  here, it doesn't exist for the next session.
- Keep this file a table of contents (≤100 lines); depth goes in `docs/`.
- Open-source hygiene: no personal paths, keys, or private project names in
  any committed file; templates use `{{placeholders}}` only.
