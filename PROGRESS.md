# PROGRESS

Newest-first session log. One entry per working session. Read this (plus
`git log -20` and FEATURES.json) at the start of every session.

## 2026-07-07 — session 5

- Branch: `m8-audit` (PR).
- Done: M8-001 — check.sh + scripts/test-audit.sh fixture suite, gate-wired.
- Done: M8-002 — harness-audit SKILL.md (report + offer fix, never auto-fix).
- Gate: green.
- Next: M9-001 — PRD/requirements input guidance.

## 2026-07-07 — session 4

- Branch: `m7-plugin` (PR); repo renamed on GitHub to agent-harness-kit
  (local dir intentionally unchanged).
- Done: M7-001 — skills/harness-setup restructure, gate re-pointed.
- Done: M7-002 — .claude-plugin manifests; README plugin quickstart.
- Gate: green.
- Next: M8-001 — harness-audit checker + fixture tests.

## 2026-07-03 — session 3

- Branch: `master` (single direct commit — owner waived plan/branch/PR
  phases for this one).
- Done: M6-001 — option C: created SedyBenoitPeace/agent-harness-template
  (private, isTemplate=true): templates laid out at final paths with
  {{placeholders}}, bootstrap banner in AGENTS.md, CLAUDE.md/GEMINI.md
  pointers, PRODUCT.md skeleton, protocol doc copied whole. Scaffold passed
  the parent gate's checks before commit. README here links it; canonical
  source stays skill/harness-planning/templates/ (drift risk noted there).
- Gate: green (locally; CI runs on this push).
- Next: none failing. Owner installs the skill and field-tests it; repos
  still private — going public is the owner's call.

## 2026-07-03 — session 2

- Branch: `m5-ci-gate` (PR #2); PR #1 (v1, M0–M4) merged to master by owner.
  Repo published: private, SedyBenoitPeace/harness-planning-skill.
- Done: M5-001 — `.github/workflows/gate.yml` runs the gate on push to
  master and on PRs; proven by green Actions run 28664106358 on the PR.
- Gate: green (locally and in CI).
- Next: none failing. Remaining deferred spec item: standalone template-repo
  extraction (option C). Repo is private; going public is the owner's call.

## 2026-07-03 — session 1

- Branch: `m0-harness-scaffolding`
- Done: M0-001 — gate script, FEATURES.json, PROGRESS.md scaffolded.
- Done: M0-002 — LICENSE (MIT), .gitignore, README stub, AGENTS.md refreshed.
  Gate fix along the way: LICENSE check rewritten to avoid shellcheck SC2015.
- Done: M1-001 — FEATURES.json.tmpl + PROGRESS.md.tmpl; gate now validates
  templates (JSON-after-substitution, placeholder presence).
- Done: M1-002 — AGENTS.md.tmpl (40 lines, map + session loop + rules) and
  pointer.md.tmpl (one-liner for CLAUDE.md/GEMINI.md).
- Done: M1-003 — dev.sh.tmpl + e2e.sh.tmpl; gate shellchecks all *.sh.tmpl
  after substituting {{placeholders}} with `true`. Milestone 1 complete.
- Done: M2-001 — harness-protocol.md created: intro (core principle, pillar
  links, layout diagram) + full §1 Planning protocol (interview, PRODUCT.md,
  milestones, verify-field examples, plan, gate, retrofit rules). Gate
  enforces agent-neutrality (no 'claude' string) — it caught the layout
  diagram mentioning a vendor entry-file by name; wording made neutral.
- Done: M2-002 — §2 Coding-session protocol: context recovery order,
  feature selection, green-baseline rule ("fixing the gate IS the session"),
  test-first loop, close-out checklist, branch discipline, session prompt.
- Done: M2-003 — §3 Maintenance protocol: entropy GC, doc gardening,
  FEATURES.json gardening, "what's missing?" rule. Milestone 2 complete —
  the protocol doc is whole.
- Done: M3-001 — SKILL.md: mode detection, "run the shipped manual §1",
  template→destination copy table, retrofit rules, verify+commit, red-flags
  table. Gate bug found by its own run: template-reference regex allowed
  zero-length matches (bare `templates/` in prose); tightened to `+`.
- Done: M4-001 — full README: what/why, both quickstarts (skill install;
  single-file protocol for any agent), layout, dogfood note. Gate check
  reworded to '.claude/skills' after shellcheck SC2088 (quoted tilde).
- Done: M4-002 — acceptance test PASSED first try. Scaffolded a slugify
  sandbox from the templates (1 passing + 2 failing features); a fresh
  context-free subagent given only "read AGENTS.md and perform one session"
  picked M0-002, confirmed green baseline, worked test-first, flipped only
  its feature, appended PROGRESS.md, and logged a --no-ff deviation for the
  no-remote case. Fed back: protocol §2.6 now covers repos without remotes.
- Closed out: plan moved to docs/plans/completed/, AGENTS.md state → v1
  complete. All 11 features (M0–M4) passing.
- Gate: green (`bash scripts/e2e.sh`).
- Next: integration into master (awaiting owner's decision on push/PR) and,
  later, the deferred spec items: template-repo extraction, CI enforcement.
