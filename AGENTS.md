# AGENTS.md — agent-harness-kit

This repository is operated with the long-running-agent harness, plugin or
not: the full manual is `docs/agents/harness-protocol.md` — read it before
your first feature session.

Open-source Claude Code skill + portable protocol pack for planning
applications with the long-running-agent harness approach (in-repo
FEATURES.json / PROGRESS.md / plans / e2e gate), consumable by any AI agent.

## State: 3.30.0 ready (M0–M69); Claude Code edition `agent-harness-kit-claude` in `claude/`

1. Spec: `docs/specs/2026-07-03-harness-planning-skill-design.md`
2. Active plans: `docs/plans/active/` (one per milestone; completed ones in `docs/plans/completed/`)
3. Scope/status: `FEATURES.json` · Session log: `PROGRESS.md` · Shape: `ARCHITECTURE.md`
4. Gate: `bash scripts/e2e.sh` (exit 0 = green; run at session start and end)
5. Deliverables: `.claude-plugin/` (manifests), `skills/` (harness-initial-setup, harness-audit,
   harness-session, harness-run, harness-continuous, harness-upgrade-structure,
   harness-status, harness-handoff, harness-issues), README.

Any agent can build this repo: plans and FEATURES.json are agent-neutral. If
the harness-session skill is available, use it; otherwise follow
`skills/harness-initial-setup/templates/harness-protocol.md` section 2.

## Session loop

Feature work only: a FEATURES.json entry or plan task (or work needing one), a
change to what the product does, or an edit to agent instructions (this file,
`docs/agents/`, FEATURES.json, skills, prompts). Anything else is a small task:
do it, check that one result (grep a moved path; run the gate once if code,
tests, scripts or CI/build config change), stop. If it proves to be feature
work, stop and say so. Rules and Needs a human always apply.
If the human says to skip the harness ("just build it"): no brief or plan, but
FEATURES.json and its archive stay the source of truth: append an entry with
the next free id, build it, run the gate, flip it to `passing`, commit.
An approved plan or outline from another workflow: skip harness-brief, turn it
into FEATURES.json entries plus a plan section, then go to harness-run.
Feature work only (a FEATURES.json entry, a plan task, or a kit behaviour change); a file move or doc fix is a small task: do it, check it, stop.

Read `git log -20` + PROGRESS.md + FEATURES.json → pick the lowest failing
feature (new work gets a plan in `docs/plans/active/` first) → gate green
baseline → implement test/check-first → gate green → flip the feature to
`passing` in FEATURES.json in the same commit → PROGRESS.md entry.

## Rules

- Read rule: `grep -n` first, then `sed -n` ≤80 lines; never `cat` a source file over 200 lines; one read per command, never chained (`sed …; sed …; rg …`).
- Plans, decisions, and progress live in this repo. If it's not committed
  here, it doesn't exist for the next session.
- Keep this file a table of contents (≤100 lines); depth goes in `docs/`.
- Open-source hygiene: no personal paths, keys, or private project names in
  any committed file, commit message or PR text (`ci-local.sh` checks files and
  messages; check a PR body with `scripts/check-private-names.sh <file>`);
  templates use `{{placeholders}}` only.
- Integrate via PR; the owner merges. Before every push, `bash scripts/ci-local.sh`
  must print `CI-LOCAL GREEN` (CI's gate in Docker on a clean clone, no git
  identity): a local `e2e.sh` alone misses clean-checkout and tool-version gaps.
- After a release PR merges on GitHub, run `bash scripts/upgrade-all.sh` (list in
  `.git/info/upgrade-repos`, never committed; a line may be a folder of repos, `--add <folder>`; or `bash scripts/upgrade-all.sh <repo>` for one path, no list): it opens the upgrade PR in each listed repo.
