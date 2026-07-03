# AGENTS.md — harness-planning skill

Open-source Claude Code skill + portable protocol pack for planning
applications with the long-running-agent harness approach (in-repo
FEATURES.json / PROGRESS.md / plans / e2e gate), consumable by any AI agent.

## State: v1 complete (M0–M4 passing, acceptance test passed)

1. Spec: `docs/specs/2026-07-03-harness-planning-skill-design.md`
2. Executed plan: `docs/plans/completed/2026-07-03-harness-planning-skill-implementation.md`
3. Scope/status: `FEATURES.json` · Session log: `PROGRESS.md`
4. Gate: `bash scripts/e2e.sh` (exit 0 = green; run at session start and end)
5. Deliverables: `skill/harness-planning/` (SKILL.md + templates), README.

## Session loop

Read `git log -20` + PROGRESS.md + FEATURES.json → pick the lowest failing
feature (new work gets a plan in `docs/plans/active/` first) → gate green
baseline → implement test/check-first → gate green → append the feature to
FEATURES.json as passing in the same commit → PROGRESS.md entry.

## Rules

- Plans, decisions, and progress live in this repo. If it's not committed
  here, it doesn't exist for the next session.
- Keep this file a table of contents (≤100 lines); depth goes in `docs/`.
- Open-source hygiene: no personal paths, keys, or private project names in
  any committed file; templates use `{{placeholders}}` only.
- Local branches only for now — no remotes/PRs until the owner says so.
