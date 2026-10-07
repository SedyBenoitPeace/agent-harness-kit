# PROGRESS

Newest-first session log. One entry per working session. Read this (plus
`git log -20` and FEATURES.json) at the start of every session.

## 2026-10-07 — session 37 (M24-002)

- Branch: `m24-claude-edition`.
- Done: M24-002 — `agents/src/*.md` take an optional `effort:`;
  `gen-agents.sh` emits `effort:` for Claude Code and
  `model_reasoning_effort` for Codex (no max there, so max → high), nothing
  for Copilot, and rejects unknown levels. The evaluator source sets
  `effort: high`. Fixtures in test-agents.sh (pass-through, max mapping on a
  copy of the sources, rejection, no line when absent). Generated Claude
  agents pass `claude plugin validate --strict`; Codex TOML parses.
- Decisions: built into the core generator, not the edition plugin (Codex
  has the same setting, so it is portable); rejected passing `xhigh` to
  Codex for max (not sure every Codex version accepts it); left the builder
  without a fixed effort because the feature's own `effort` (M23-002) is
  passed per dispatch.
- Gate: green.
- Next: M24-003 (auto-mode docs, skill eval suite).

## 2026-10-07 — session 36 (M24-001)

- Branch: `m24-claude-edition` (off master after PR #24 merged).
- Done: M24-001 — second plugin in the marketplace at `claude/`
  (`source: ./claude`), named `agent-harness-kit-mods`, depending on
  `agent-harness-kit`, version in lockstep (3.1.0). Gate checks the
  manifest, the marketplace entry, versions, no protocol copy, the README
  install line, and runs `claude plugin validate --strict claude` and
  `claude plugin validate .` when the CLI is present. README "Claude Code
  edition"; ARCHITECTURE module + invariant.
- Decisions: renamed from `agent-harness-kit-claude` (validator warning:
  reads as Anthropic's own); kept the folder `claude/` so the planned
  paths hold; made the CLI validate conditional because CI has no
  `claude` binary; assumed the core plugin (source `./`) does not load
  `claude/` (it loads only its root skills/agents/hooks).
- Gate: green.
- Next: M24-002 (agent effort in the generator).

## 2026-10-07 — session 35 (M23-003)

- Branch: `m23-decisions-and-effort`.
- Done: M23-003 — protocol §3.4: start lean, prefer a gate check over a
  prose rule, and end a rule written for one model's repeated failure with
  `(model: <name>)`; §3.2: re-test tagged rules when the model changes and
  delete those no longer needed. AGENTS.md.tmpl gains the one-line rule
  (62/80 lines). check.sh WARNs with the count of tagged rules (fixture in
  test-audit.sh; the template's own `<name>` example is not counted).
  README "Decision notes, effort and model-tagged rules". Released 3.1.0.
- Decisions: rejected FAILing on tagged rules (they are legitimate, only
  due for a re-test); rejected a per-model AGENTS file (one file to keep
  in sync); assumed target repos pick up the protocol changes through
  harness-upgrade-structure (the protocol copy differs, so UPGRADE: offer
  fires).
- Gate: green.
- Next: owner reviews and merges the PR. Then M24-001 (Claude edition
  skeleton) from a Claude Code CLI session: the M24/M25 features need the
  real runtime (`claude plugin validate`, `claude plugin test`, evals).

## 2026-10-07 — session 34 (M23-002)

- Branch: `m23-decisions-and-effort`.
- Done: M23-002 — optional per-feature `effort` (low|medium|high|max).
  Protocol §1.4 asks "How much verification does this deserve?" with a
  per-kind table; FEATURES.json.tmpl documents it; status.sh prints an
  indented `effort:` line under `NEXT:` (plain and `--skip` paths, fixtures
  in test-status.sh); check.sh WARNs on unknown values (fixture in
  test-audit.sh); harness-run passes the level as the dispatch tool's
  effort setting or a prompt line, and dispatches the evaluator at high or
  above; harness-session step 7 reads it. Gate rejects bad values in this
  repo's own FEATURES.json.
- Decisions: rejected a global effort setting (guidance is per task kind);
  rejected a model-router mod (the Claude Code agent tool already takes a
  per-dispatch effort); WARN not FAIL in check.sh (an unknown hint breaks
  nothing); assumed CLIs without an effort setting still benefit from the
  prompt line.
- Gate: green.
- Next: M23-003 (model-tagged rules, README, release 3.1.0).

## 2026-10-07 — session 33 (M23-001)

- Branch: `m23-decisions-and-effort` (off master).
- Done: M23 plan written (`docs/plans/active/2026-10-07-m23-decisions-and-effort.md`)
  with failing entries for M23 (core), M24 (Claude edition, native) and M25
  (Claude edition, mods). M23-001 — protocol §2.5 asks every session entry
  for a `Decisions:` line (options considered and rejected, assumptions
  made); §2.7 lets the evaluator read it as leads, not evidence;
  PROGRESS.md.tmpl, harness-builder, harness-evaluator and harness-session
  updated; gate checks each.
- Decisions: rejected a separate decisions file per feature (one more file
  to keep in sync; the session entry is already read first); rejected
  letting the evaluator treat Decisions: as evidence (it still judges by
  observing the repo); assumed a single line is enough per session.
- Gate: green.
- Next: M23-002 (per-feature effort).

## 2026-10-01 — session 32 (M22-001)

- Branch: `fix-skill-frontmatter` (off master after PR #22 merged).
- Done: M22-001 — Copilot CLI skipped harness-continuous and
  harness-upgrade-structure (`failed to parse YAML frontmatter`): an unquoted
  `: ` in their descriptions. Reworded both; the gate now fails on that
  pattern in `skills/*/SKILL.md` and `agents/src/*.md`. Verified with
  `copilot skill list` against project copies. Released 3.0.1.
- Gate: green.
- Next: owner merges the PR; then `copilot plugin update agent-harness-kit`.

## 2026-10-01 — session 31 (M21-003)

- Branch: `m21-upgrade-structure`.
- Done: M21-003 — `skills/harness-upgrade-structure/SKILL.md` (runs
  upgrade.sh, explains CHANGED/OK/TODO, offers harness-audit, commits as
  its own commit, never pushes); harness-session's `UPGRADE: offer` now
  points to it instead of listing steps; README "Upgrading existing repos"
  with the by-hand `upgrade.sh` command and the walkthrough step using it;
  ARCHITECTURE, AGENTS.md, layout updated. Released as 3.0.0 (plugin,
  marketplace, package) because `harness-setup` was renamed. M21 plan moved
  to `docs/plans/completed/` in this commit.
- Also: M21-003 was added to FEATURES.json as `failing` earlier (089619f)
  so the pending work was visible — a deliberate exception to adding
  entries only when proven.
- Gate: green.
- Next: owner merges the M21 PR.

## 2026-10-01 — session 30 (M21-002)

- Branch: `m21-upgrade-structure`.
- Done: M21-002 — `skills/harness-upgrade-structure/scripts/upgrade.sh
  [repo]`: for repos that already have a harness (exit 3 otherwise,
  pointing at harness-initial-setup). Refuses a dirty tree; on the default
  branch it creates `harness-upgrade` first. Idempotent: recopies the
  protocol, adds the harness-run line to AGENTS.md, generates evaluator
  files only for opted-in repos, and prints `CHANGED:`/`OK:`/`TODO:` lines
  (unbounded gate, harness-audit `depends_on`/`paths`). Stages and commits
  nothing. Fixtures in `scripts/test-upgrade.sh`, shellchecked in the gate.
- Gate: green.
- Next: M21-003 (the skill, harness-session wiring, README, release 3.0.0).

## 2026-10-01 — session 29 (M21-001)

- Branch: `m21-upgrade-structure` (off master after PR #21 merged).
- Done: M21-001 — `skills/harness-setup/` renamed to
  `skills/harness-initial-setup/` (templates included), no alias; all live
  references updated (skills, scripts, tests, README, ARCHITECTURE,
  AGENTS.md); description points existing repos at harness-upgrade-structure.
  New gate check fails on any leftover old-name reference outside history.
  M21 plan added (`docs/plans/active/`): M21-002 upgrade.sh, M21-003 skill,
  wiring and release 3.0.0 (assumed major bump for the breaking rename).
- Gate: green.
- Next: M21-002 (`upgrade.sh`).

## 2026-10-01 — session 28 (M20 close-out)

- Branch: `m20-unattended-runs`.
- Done: M20 plan moved to `docs/plans/completed/` in this PR instead of a
  post-merge close-out PR. Protocol §2.5 and harness-session close-out now
  say the session that finishes a plan's last feature moves the plan in
  the same commit (owner: waiting for the merge is an unnecessary step).
- Gate: green.
- Next: owner merges PR #21; then plan M21.

## 2026-10-01 — session 27 (M20-004)

- Branch: `m20-unattended-runs`. The owner's spec commit bb419ba (README
  walkthrough requirement) lived on another branch; cherry-picked as
  730b91d.
- Field test changed the design: Claude Code refuses writes under `.git/`
  even with allow rules, Codex's workspace-write sandbox makes `.git`
  read-only, Copilot refuses shell redirection without a skip-all flag.
  Owner decision: the plugin documents no CLI's permissions, and run
  state moves from `.git/harness-run/` to a git-ignored `.harness-run/`
  (the run adds the `.gitignore` line in its own commit). harness-continuous
  skill, test-run.sh, plan and the M20-002/M20-004 verify text updated; the
  skill also gained a fallback when `run-report.sh` cannot run.
- Done: M20-004 — protocol §2.8 Continuous runs; README skills entry,
  "Unattended runs" and "Upgrading a repo and running continuously"
  (ordered, gate-enforced), layout and lifecycle updates; ARCHITECTURE
  row; AGENTS.md state. Released as 2.0.0 (owner's call, not 1.11.0):
  package.json, plugin.json, marketplace.json, gate assertion.
- Gate: green.
- Not field-tested: invoking harness-continuous in Codex CLI and Copilot
  CLI (only Claude Code's `/agent-harness-kit:harness-continuous`, which
  loaded the skill and stopped at the baseline check). The README tells
  other agents to ask for it by name.
- Next: M20 is complete — push and open the PR; the owner merges.

## 2026-10-01 — session 26 (M20-003)

- Branch: `m20-unattended-runs`.
- Done: M20-003 — `skills/harness-run/scripts/run-report.sh <start-commit>
  [--skip FILE] [--stop-reason TEXT]` writes `docs/runs/<YYYY-MM-DD-HHMM>.md`
  (stamp = HEAD's commit date, so a fixed repo state gives identical
  output) and prints its path. Sections: Summary (start, end, stop reason,
  counts), Done (id, title, commit), Skipped (reason and question parsed
  from the notes, plus the stash ref), Not started (depends-on a skipped
  id via `status.sh --skip`, else "not reached" with the stop reason),
  Branches. Git, FEATURES.json, skip file only: no network, no models.
  Fixture-proven in `scripts/test-run.sh`; shellchecked in the gate. A
  render against this repo caught a garbled date format the fixture
  missed; the test now asserts the Start/End lines.
- Gate: green.
- Next: M20-004 (docs, per-CLI permission setup, release 1.11.0).

## 2026-10-01 — session 25 (M20-002)

- Branch: `m20-unattended-runs`.
- Done: M20-002 — new `skills/harness-continuous/SKILL.md`: invoked by
  name (no trigger word), never asks, run state in `.git/harness-run/`
  (`start`, `skip`, `STOP`). A blocked session, red gate or two
  NEEDS_WORK verdicts becomes a skip (stash, note with one question,
  FEATURES.json-only commit, `status.sh --skip`); stops on NEXT none,
  cap, STOP, baseline problem, or a dispatch with no commit and no skip.
  Crosses milestones only for a named range, with stacked branches, no
  push. harness-run points to it and is otherwise unchanged. Contract
  proven by new `scripts/test-run.sh`, wired into the gate.
- Gate: green.
- Next: M20-003 (`run-report.sh`; the skill's End step already calls it).

## 2026-10-01 — session 24 (M20-001)

- Branch: `m20-unattended-runs` (off master after PR #20 merged).
- Done: M20-001 — `status.sh --skip FILE` excludes listed ids, features
  whose `depends_on` hits an excluded id (to a fixpoint), and
  dependency-less features that follow an excluded one; prints one
  `SKIPPED: <id> — <why>` per exclusion and `NEXT: none` when nothing is
  eligible. `context.sh --skip` passes it through; NEXT, PLAN and PARALLEL
  follow the first eligible feature. Without `--skip` the output is
  byte-identical (golden fixture in `scripts/test-session.sh`).
- Gate: green.
- Next: M20-002 (harness-continuous skill). Open the M20 PR only after
  M20-004.

## 2026-09-30 — session 23 (M18-003)

- Branch: `m18-evaluator`.
- Done: M18-003 — protocol §1.4 asks "Can the gate prove this? If not,
  what is the bar?" (`evaluate` / `bar`), §2.7 documents the review step,
  security checklist and `docs/verification/<id>.md`; `review` added to the
  status list. FEATURES.json.tmpl documents the status and fields.
  harness-setup and the harness-session upgrade offer run
  `../../scripts/gen-agents.sh`; harness-audit WARNs when features opt in
  without an evaluator agent file and suggests `evaluate: "ui"` for
  manual/UI-shaped verifies. README and ARCHITECTURE name the evaluator.
  Released as 1.9.0 (plugin, marketplace, package). M18 plan moved to
  `docs/plans/completed/`. Existing repos see `PROTOCOL: outdated` and are
  offered the recopy; evaluation stays opt-in.
- Gate: green.
- Next: M19 (harness-brief) — plan is in `docs/plans/active/`; open the M18 PR.

## 2026-09-30 — session 22 (M18-002)

- Branch: `m18-evaluator`.
- Done: M18-002 — new status `review` (accepted by e2e.sh and
  harness-audit); optional `evaluate` (ui|none) / `bar` / `eval_attempts`
  validated by the gate. status.sh totals show `review N` and an
  `REVIEW:` line only when present (output otherwise unchanged); review is
  never NEXT and does not count as passing. harness-session ends
  `evaluate` features in `review` (SESSION line gains `review`);
  harness-run gets the evaluator step: dispatch `harness-evaluator`,
  clean-tree + HEAD-unchanged check, PASS writes
  `docs/verification/<id>.md`, NEEDS_WORK writes notes + `eval_attempts`,
  STOP at 2. `agents/models.json` gains `sensitive_globs` (security
  checklist trigger).
- Noted, unchanged: NEXT ignores `depends_on` (only lanes use it), so a
  failing feature depending on a `review` one can still be NEXT.
- Gate: green.
- Next: M18-003 (protocol, planning interview, audit, release 1.9.0).

## 2026-09-30 — session 21 (M18-001)

- Branch: `m18-evaluator`.
- Done: M18-001 — neutral `agents/src/harness-{builder,evaluator}.md`,
  `agents/models.json` (tier -> model per CLI) and `scripts/gen-agents.sh`
  emitting Claude (.md), Copilot (.agent.md) and Codex (.toml) files;
  `scripts/test-agents.sh` wired into the gate. Evaluator: read-only tools
  in every format, Codex `sandbox_mode = "read-only"`. Re-checked all three
  vendor docs 2026-09-30: they match the plan table (Codex docs moved to
  learn.chatgpt.com). Model names in models.json are editable defaults,
  not verified against each CLI's current model list.
- Gate: green.
- Next: M18-002 (review status, orchestrator step, evidence file).

## 2026-09-25 — session 20 (M17-003)

- Branch: `m17-harness-run`.
- Done: M17-003 — protocol §1.4 asks the optional "Depends on?" /
  "Paths touched?" questions and new §2.7 "Orchestrated runs" states the
  harness-run rules (agent-neutral). FEATURES.json.tmpl `_instructions`
  documents the fields; AGENTS.md.tmpl and README (skill list,
  lifecycle, prompts, layout, update note) name harness-run. Existing
  repos: the `PROTOCOL: outdated` upgrade now also adds the harness-run
  line to AGENTS.md; harness-audit proposes lane fields on approval;
  absent fields stay sequential. Released as 1.8.0. M17 plan moved to
  `docs/plans/completed/`.
- Gate: green.
- Next: no failing feature — M17 complete; open the PR.

## 2026-09-25 — session 19 (M17-002)

- Branch: `m17-harness-run`.
- Done: M17-002 — `context.sh` prints `PARALLEL: <id> …` (max 3) or
  `PARALLEL: none`, computed in jq from optional `depends_on` / `paths`:
  lanes start at NEXT, stay in its milestone, need all deps passing and
  non-overlapping glob prefixes; any missing field → sequential.
  harness-run gains a "Parallel lanes" section (worktree + `lane/<id>`
  branch per lane, orchestrator merges, runs one gate, flips statuses,
  writes one PROGRESS entry; conflict → redo sequentially).
  harness-session gains the lane variant (own verify + commit only).
  Gate type-checks the optional fields; M17-002's own entry uses them.
- Gate: green.
- Next: M17-003 — docs, planning interview, AGENTS.md template, 1.8.0.

## 2026-09-25 — session 18 (M17-001)

- Branch: `m17-harness-run`.
- Done: M17-001 — new `skills/harness-run/SKILL.md`: a sequential
  orchestrator that loops context.sh → dispatches one fresh built-in
  subagent per feature ("harness-session for <id>, inline") → verifies
  via status.sh + clean tree → stops on a blocker, the milestone
  boundary, or the cap (default 10). No subagent tool → one normal
  session, then stop. harness-session now ends with a fixed
  `SESSION: <id> · <passing|blocked> · gate <green|red> · <commit|reason>`
  line and always runs inline inside a subagent. Gate greps both.
- Gotcha: gate greps are line-based, so contract phrases must sit on one
  line in SKILL.md.
- Gate: green.
- Next: M17-002 — parallel lanes (add its FEATURES.json entry with the
  implementing commit).

## 2026-09-16 — session 17 (M16-001)

- Branch: `m16-native-workflows`.
- Done: M16-001 — protocol §1.5 now tells the agent to plan with its own
  native plan mode and forbids plan headers that mandate an external
  skill; §2.4 gains an "Execution mode" choice (inline by default, or
  delegated to the agent's own built-in subagents for independent parts,
  own tools only). harness-setup and harness-session SKILL.md, the
  AGENTS.md template, and the README carry the same rule. Gate greps the
  new text and rejects any third-party workflow plugin name under
  `skills/` or in the README. Released as 1.7.0; plan filed directly
  under `docs/plans/completed/`.
- Trigger: a Copilot CLI session in a harnessed repo followed an external
  `REQUIRED SUB-SKILL` plan header, front-loaded ~800 lines of process
  text, and ran 16 subagent round-trips for 7 tasks in one session.
- Gate: green.
- Next: no failing feature — plan new work or run a maintenance pass.

## 2026-09-16 — session 17b (M16-002, M16-003, M16-004)

- Branch: `m16-native-workflows` (same PR #17, still 1.7.0).
- Deviation: three features in one session at the owner's request; one
  commit each, red-green per feature.
- Done: M16-002 — `e2e.sh.tmpl` bounds its own output with a `step`
  wrapper (full log as `FULL_LOG`, one line per passing step, tail on
  failure, `GATE_VERBOSE=1` to stream); harness-audit WARNs on a gate
  with no `FULL_LOG` marker; protocol §1.6 states the contract.
- Done: M16-003 — protocol §1.5 ships a verbatim plan header routing each
  task through one harness coding session (harness-session if installed,
  else §2); AGENTS.md.tmpl names harness-session as the entry point;
  harness-session triggers on "execute a plan".
- Done: M16-004 — protocol §2, AGENTS.md.tmpl and harness-status tell
  agents to use the `show-me` skill, when installed, for explanations and
  summaries; README credits HumanLayer.
- Done: M16-005 — `context.sh` reports `GATE_OUTPUT`, `PROTOCOL` and
  `UPGRADE: offer|none` so a session notices a repo scaffolded by an
  older plugin; harness-session offers the upgrade once as its own
  commit before the feature.
- Gate: green.
- Next: no failing feature — plan new work or run a maintenance pass.

## 2026-09-09 — session 16 (M15-004)

- Branch: `m15-efficient-sessions`.
- Done: M15-004 — released `harness-session` as plugin `1.6.0` and closed
  the M15 milestone. Extended the root gate's manifest-sync check to also
  assert `package.json`'s version matches `plugin.json`/`marketplace.json`
  (previously only the two plugin manifests were compared). Bumped all
  three version fields to `1.6.0` and moved
  `docs/plans/active/2026-09-09-m15-efficient-coding-sessions.md` to
  `docs/plans/completed/`.
- Since versions already agreed at `1.5.0`, this task used the existing
  synchronization gate rather than manufacturing a production-code RED
  failure, per the plan's Task 4 note.
- Verified: `bash scripts/e2e.sh` green; `bash
  skills/harness-session/scripts/context.sh .` reports M15 4/4 passing
  and `NEXT: none`.
- Gate: green.
- Next: no failing feature — plan new work or run a maintenance pass.

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

## 2026-09-30 — session 24 (M19-001)

- Branch: `m19-harness-brief` (cut from master after M18 merged).
- Done: M19-001 — `skills/harness-brief/` (SKILL.md: at most three
  questions, stranger test before saving, runs check-brief.sh;
  `templates/brief.md.tmpl`; `scripts/check-brief.sh` emitting one
  PASS/FAIL line per check: nine sections present and non-empty, Open
  questions empty, every Done-when line carries a backticked command).
  `scripts/test-brief.sh` proves a complete fixture passes and each defect
  fixture (missing section, open question, vague Done-when) fails with its
  own FAIL line; wired into `scripts/e2e.sh`.
- Gate: green.
- Next: M19-002 (independent brief reviewer agent).

## 2026-09-30 — session 25 (M19-002)

- Branch: `m19-harness-brief`.
- Done: M19-002 — neutral source `agents/src/harness-brief-reviewer.md`
  (read-only; input is only the brief file; first line exactly `READY` or
  `GAPS`, then numbered gaps). gen-agents.sh emits it for all three CLIs
  unchanged. harness-brief SKILL.md step 6 dispatches it after saving,
  asks the human about GAPS, and stops after 2 review rounds.
  `test-agents.sh` now checks both read-only agents per format plus the
  reviewer contract; `test-brief.sh` checks the SKILL.md dispatch.
- Gate: green.
- Next: M19-003 (planning consumes briefs; Needs-a-human; release 1.10.0).

## 2026-09-30 — session 26 (M19-003)

- Branch: `m19-harness-brief`.
- Done: M19-003 — protocol §1.1 "Already have a brief?" (Done-when seeds
  `verify`, Quality bar seeds `evaluate`/`bar`, Needs-a-human is a
  stop-and-ask boundary); AGENTS.md.tmpl gains a "Needs a human" section
  with the six defaults (54→60 lines, under the 80 cap); README lifecycle
  step 0 shows brief → plan → run. Released as 1.10.0 (plugin,
  marketplace, package). M19 plan moved to `docs/plans/completed/`;
  AGENTS.md state line and ARCHITECTURE.md updated. Existing repos see
  `PROTOCOL: outdated` and are offered the recopy.
- Gate: green.
- Next: M20 (continuous runs) — plan is in `docs/plans/active/`; open the M19 PR.
