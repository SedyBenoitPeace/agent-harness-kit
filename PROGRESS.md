# PROGRESS

Newest-first session log. One entry per working session. Read this (plus
`git log -20` and FEATURES.json) at the start of every session.

## 2026-09-09 — session 15 (M15-003)

- Branch: `m15-efficient-sessions`.
- Done: M15-003 — integrated the shipped `harness-session` skill into the
  agent-neutral protocol, the scaffold template, and this repo's own
  README/ARCHITECTURE. `harness-protocol.md` §2.3 now states the
  git-status check before claiming a clean baseline, the three-way
  clean/CONTINUING-INTERRUPTED-FEATURE/ambiguous branch, and the optional
  target `scripts/preflight.sh` step; §2.4 adds the
  out-of-scope-tracked-warning rule; §2.5 mentions the gate wrapper as an
  alternative to the raw gate call. All portable manual commands remain
  the fallback. `AGENTS.md.tmpl` gained an "accelerator, not a
  dependency" note (still 46/80 lines). README gained the harness-session
  skill entry, lifecycle step, usage-table row, and repository-layout
  entry. `ARCHITECTURE.md` gained the `run-gate.sh` module/diagram
  coverage, a session-data-flow bullet, four new cross-cutting invariants
  (status is the sole selector; session scripts are read-only except
  executing the target's own commands; full gate logs are always
  retained; dirty ownership is never inferred mechanically), and an
  expanded M15 subsystem note.
- Proven test-first: added the seven new gate grep checks first (root
  `scripts/e2e.sh`), watched the gate fail on the first missing phrase,
  then edited docs until `bash scripts/e2e.sh` was green again.
- Gate: green.
- Next: **M15-004** — release `harness-session` as plugin 1.6.0 and close
  the milestone.

## 2026-09-09 — session 14 (M15-002)

- Branch: `m15-efficient-sessions`.
- Done: M15-002 — `skills/harness-session/scripts/run-gate.sh <baseline|final>
  [TARGET_DIR]` wraps, but never replaces, the target's own
  `scripts/e2e.sh`: retains the complete captured output in a timestamped
  log under `${TMPDIR:-/tmp}`, prints an absolute `FULL_LOG` path, and
  bounds the terminal report to the final 20 lines on success or 80 on
  failure while returning the target gate's own exit code unchanged.
  Invalid phase input is a usage error (exit 2). `SKILL.md` now routes
  both the baseline and final gate through the wrapper and states
  explicitly that a bounded report never licenses ignoring a non-zero
  exit.
- Proven by `bash scripts/test-session.sh` (300-line success log retains
  >=301 lines while the terminal report stays <=25 lines; a failing fake
  gate exposes its sentinel while preserving exit 7; invalid phase
  returns 2) and `bash scripts/e2e.sh`.
- Gate: green.
- Next: **M15-003** — protocol, setup template, and lifecycle
  documentation integration.

## 2026-09-09 — session 13 (M15-001)

- Branch: `m15-efficient-sessions`.
- Done: M15-001 — `skills/harness-session/scripts/context.sh` delegates
  feature selection to `harness-status`, then adds `git log -5 --oneline`,
  a clean/dirty worktree report (`git status --short`), active-plan
  matching against the selected feature's id under `docs/plans/active/`,
  and discovery (never execution) of an optional target
  `scripts/preflight.sh`. Exit codes 3/2 propagate unchanged from the
  delegated `status.sh` call via `set -e`. `SKILL.md` covers clean start,
  continuing an interrupted feature, and stopping on ambiguous dirty
  state; it invokes `bash scripts/e2e.sh` directly until M15-002 adds the
  concise `run-gate.sh` wrapper.
- Proven by `bash scripts/test-session.sh` (bare/broken delegation, clean
  report contents, five-commit cap, dirty-tree facts, preflight
  discovery) and `bash scripts/e2e.sh`.
- Gate: green.
- Next: **M15-002** — concise gate runner retaining full evidence.

## 2026-09-09 — session 12 (M15 efficient coding sessions planned)

- Branch: `m15-efficient-sessions` (planning branch from updated `master`).
- Why: a field M1-003 coding session took roughly 43 minutes and consumed excessive context because the plugin has setup, audit, status, and handoff skills but no skill that owns protocol §2 execution.
- Planned only — no implementation: added the approved design spec and a four-feature implementation plan for `harness-session`: bounded context and interrupted-work safety (M15-001), concise retained gate logs (M15-002), protocol/docs/architecture integration (M15-003), and release 1.6.0 (M15-004).
- Owner-approved boundaries: keep the final full gate and one-feature rule; reuse `harness-status` as the sole selector; never infer ambiguous dirty-file ownership; keep stack-specific service checks in an optional target `scripts/preflight.sh`; do not modify target gates.
- Baseline and planning gate: **GREEN**.
- Next: **M15-001** — implement the `harness-session` bounded context script, skill workflow, and fixture tests exactly as planned.

## 2026-07-11 — session 11

- Branch: `m14-observability` (PR).
- Why: owner ran the harness on two field repos — both healthy, but
  logging was never raised by planning or audit; retrofitting it would
  have meant a bespoke ad-hoc plan per repo. Same shape as the M13
  ARCHITECTURE.md gap.
- Done: M14-001 — protocol §1.9 (per-stack logging/observability table,
  appended after §1.8, never renumbering); `ARCHITECTURE.md.tmpl` gained a
  named `{{LOGGING_STRATEGY}}` invariant slot; harness-setup SKILL.md
  references it.
- Done: M14-002 — `check.sh` WARNs (never FAILs) when `ARCHITECTURE.md`
  doesn't record a logging/observability approach; harness-audit SKILL.md
  gained the same derive/interview/skip repair flow as ARCHITECTURE.md's,
  plus an explicit note that building real logging infra is ordinary
  feature work, not part of the flow. test-audit.sh covers the new WARN.
- Done: M14-003 — README coverage; 1.5.0.
- Done: M14-004 — dogfood: this repo's own ARCHITECTURE.md now records its
  answer (the PASS/FAIL/WARN grammar is the observability layer for a
  service-less CLI tool).
- Design decision (owner-confirmed): no new `harness-*` skill for this —
  folds into the existing audit + repair-flow mechanism, same reasoning as
  M13. The harness only surfaces the gap and records the decision; it
  never picks a logging technology for the human.
- Gate: green.
- Next: none failing. Owner runs `harness-audit` on the two field repos
  post-merge to pick up the new WARN (ordinary audit → repair-flow path,
  not harness-kit work).

## 2026-07-11 — session 10

- Branch: `m13-architecture` (PR). M12 plan moved to completed/ (folded in,
  M9-style, to spare a separate closeout PR).
- Done: M13-001 — ARCHITECTURE.md.tmpl (5 required sections, living-doc
  banner) + protocol §1.8 create / §2.5 same-commit update / §3.2 drift
  check + AGENTS.md.tmpl map line.
- Done: M13-002 — setup scaffolds it; audit WARNs when missing and the
  SKILL.md offers derive/interview/skip (human chooses).
- Done: M13-003 — README ARCHITECTURE coverage, Codex quickstart
  (owner-tested commands), claude/codex update commands, 1.4.0.
- Done: M13-004 — dogfood ARCHITECTURE.md for this repo (audit PASS line
  proven) + AGENTS.md pointer; M13 plan moved to completed/ (owner: no
  separate closeout PR). agent-harness-template resynced same day.
- Gate: green.
- Next: none failing. Publish decision (repo → public) deferred by owner.

## 2026-07-11 — session 9

- Branch: `m12-handoff` (PR).
- Done: M12-001 — harness-handoff skill (handoff.sh + git-repo fixtures +
  SKILL.md). Ritual checks: clean tree, green gate (default-on,
  --skip-gate opt-out with WARNING); prints an agent-neutral one-feature
  prompt for the next agent.
- Done: M12-002 — README four-skills list, lifecycle handoff step,
  "Switching agents (Claude Code ↔ Codex)" section, prompts-table row.
- Done: M12-003 — 1.3.0 bump.
- Gate: green. Smoke: handoff.sh on this repo → READY + planning prompt.
- Next: none failing. Plan moves to docs/plans/completed/ after merge.

## 2026-07-08 — session 8

- Branch: `m11-status` (PR).
- Done: M11-001 — harness-status skill (status.sh + fixtures + SKILL.md).
- Done: M11-002 — harness-setup already-initialized guard.
- Done: M11-003 — README lifecycle section + slash-command forms.
- Done: M11-004 — 1.2.0 bump + manifest version-sync gate check.
- Gate: green.
- Next: none failing. Plan moves to docs/plans/completed/ after merge.

## 2026-07-08 — session 7

- Branch: `m10-verification-guidance` (PR).
- Done: M10-001 — protocol §1.7 per-stack verification tooling (web→browser
  automation, API→curl, CLI→binary run) + end-to-end-proof rule;
  e2e.sh.tmpl gains E2E_PROOF_COMMAND.
- Done: M10-002 — README "Using the skills" prompt cheatsheet.
- Gate: green. Template repo protocol re-synced on its open PR #1.
- Next: none failing. Owner field-tests the kit on a real repo.

## 2026-07-07 — session 6

- Branch: `m9-final` (single consolidated PR — owner asked to pack M9 and
  plan close-out together for time).
- Done: M9-001 — PRD/requirements input documented in README, protocol
  §1.1, and harness-setup SKILL.md.
- Done: plan moved to docs/plans/completed/; agent-harness-template README
  links updated to the renamed repo.
- Gate: green.
- Next: none failing. Pending owner decisions: repo public flip; run
  `claude plugin update agent-harness-kit` after merge to expose
  harness-audit.

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
