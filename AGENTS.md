# AGENTS.md — agent-harness-kit

Open-source Claude Code skill + portable protocol pack for planning
applications with the long-running-agent harness approach (in-repo
FEATURES.json / PROGRESS.md / plans / e2e gate), consumable by any AI agent.

## State: 3.1.0 ready (M0–M23); M24–M25 (Claude edition) queued as failing

1. Spec: `docs/specs/2026-07-03-harness-planning-skill-design.md`
2. Active plans: `docs/plans/active/` (one per milestone; completed ones in `docs/plans/completed/`)
3. Scope/status: `FEATURES.json` · Session log: `PROGRESS.md` · Shape: `ARCHITECTURE.md`
4. Gate: `bash scripts/e2e.sh` (exit 0 = green; run at session start and end)
5. Deliverables: `.claude-plugin/` (manifests), `skills/` (harness-initial-setup, harness-audit,
   harness-session, harness-run, harness-continuous, harness-upgrade-structure,
   harness-status, harness-handoff), README.

Any agent can build this repo: plans and FEATURES.json are agent-neutral. If
the harness-session skill is available, use it; otherwise follow
`skills/harness-initial-setup/templates/harness-protocol.md` section 2.

## Session loop

Read `git log -20` + PROGRESS.md + FEATURES.json → pick the lowest failing
feature (new work gets a plan in `docs/plans/active/` first) → gate green
baseline → implement test/check-first → gate green → flip the feature to
`passing` in FEATURES.json in the same commit → PROGRESS.md entry.

## Rules

- Plans, decisions, and progress live in this repo. If it's not committed
  here, it doesn't exist for the next session.
- Keep this file a table of contents (≤100 lines); depth goes in `docs/`.
- Open-source hygiene: no personal paths, keys, or private project names in
  any committed file; templates use `{{placeholders}}` only.
- Integrate via PR; the owner merges.
