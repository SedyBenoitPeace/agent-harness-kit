# PROGRESS

Newest-first session log. One entry per working session. Read this (plus
`git log -20` and FEATURES.json) at the start of every session.

## 2026-10-15 — session 71 (M32-002 Claude Code tokens in usage.log)

- Branch: `m32-m33-run`.
- Done: merged `lane/M32-002` (d6c511c) with `--no-ff` and checked it against the owner's 2.1.300 API-types answers in the M32 plan's decision log. Main-loop turns go to `orchestration`, subagent turns are summed per agentId onto the feature named in the SESSION line, and the model comes from the usage. Added two mod tests to `claude/tests/usage.test.ts`. The first proves an orchestration line is on disk after each completed main-loop turn, so a killed run keeps its orchestrator tokens. The second proves a resumed builder adds another line on the same feature, which run-report.sh already sums. No hook code changed. Both tests passed right away, which confirms the lane already appends one line per orchestrator turn.
- Decisions: Kept the lane's design. Rejected an end-of-run flush for orchestration, because per-turn appends already survive a kill. Rejected keeping one running total per feature across SESSION lines, because the report sums repeated scope lines. The lane's two unverified assumptions (usage covers the whole turn, and main-loop usage leaves out subagents) are now settled by owner answers 1 and 3, so orchestration does not double count. Known gaps: a subagent turn without a SESSION line (an evaluator, or a builder killed before it finishes) stays in memory and is never logged, so those tokens are missing from the report. An inline builder with no agentId counts as orchestration. The new tests confirm existing behaviour, so they were never red.
- Gate: GREEN (bash scripts/e2e.sh, all suites, 42 mod tests).
- Next: M32-005.

## 2026-10-15 — session 70 (M32 fixtures from real CLI sessions)

- Branch: `m32-m33-run`.
- Done: Codex and Copilot session formats confirmed on the owner's machine (Codex CLI 0.162.1, Copilot CLI 1.0.94). Fixtures in `scripts/fixtures/`, both synthetic in the confirmed formats (no real session data in this open-source repo): Codex shaped like a run with an orchestrator, four builders (one retry) and a guardian; Copilot with an orchestrator and two builders. `scripts/fixtures/README.md` holds the format facts and expected totals. M32 plan, M32-003 and M32-004 updated. No feature code yet.
- Decisions: both CLIs tag subagents and builders end with their SESSION line, so Codex and Copilot tokens attribute to features exactly; time-window attribution and Copilot's status-line snapshot are dropped. Fixtures synthetic by owner decision: open-source repo, so no real session data, trimmed or not.
- Gate: GREEN (bash scripts/e2e.sh, all suites).
- Next: unattended run `harness-continuous through M33` from this branch.

## 2026-10-15 — session 69 (M33 plan: model size separate from effort)

- Branch: `m32-token-usage`.
- Done: plan `docs/plans/active/2026-10-15-m33-model-sizes.md` and M33-001…005 as `failing`. M32 tasks re-marked with sizes (001 and 005 `small`, 005 also `effort: low`). No code yet.
- Decisions: optional `model` field (small/medium/large, or a CLI alias for that CLI only), separate from `effort`; absent keeps today's effort mapping. Model names live only in an optional per-repo size map; Claude Code needs none. Haiku 5.5 checked against Anthropic's announcement and docs before sizing: a real coding subagent, weaker on long shell work, so `small` = narrow and pattern-following.
- Gate: GREEN (bash scripts/e2e.sh, all suites).
- Next: owner reviews both plans; then M32-001.

## 2026-10-15 — session 68 (M32 plan: token usage for every CLI)

- Branch: `m32-token-usage`.
- Done: plan `docs/plans/active/2026-10-15-m32-token-usage.md` and its five tasks in FEATURES.json as `failing` (M32-001…005). No code yet.
- Decisions: tokens for Claude Code, Codex and Copilot through one shared `.harness-run/usage.log`; dollars stay Claude Code only, no price table (owner, 2026-10-15). Codex and Copilot formats are confirmed on real sessions and committed as fixtures before code relies on them; without a real sample those tasks defer with `Needs a human:`. All tasks `effort: medium`.
- Gate: GREEN (bash scripts/e2e.sh, all suites).
- Next: owner reviews the plan; then M32-001, after which 002–004 can run as parallel lanes.

## 2026-10-14 — session 67 (M31-001, release 3.9.0)

- Branch: `release/3.8.1`.
- Done: M31-001 — the Claude Code edition splits a run's cost into feature agents (any subagent running) and orchestration (the orchestrator alone), slice by slice from the session's cost, so parallel lanes count once; written to `.harness-run/run-cost`. run-report.sh adds a Cost line (total, split, orchestration %) and a Cost by model line (cost.log by the model models.log recorded) to the Summary. Tests: 3 new mod tests, run-report tests in test-run.sh. README and CHANGELOG 3.8.1 updated.
- Decisions: dollars, not tokens: token counts are not comparable across models (an opus token costs more than a sonnet one) and cache reads swamp them; the kit's budgets are already in dollars. Split by who was running rather than per-agent cost, because Claude Code reports one session cost; slices with a subagent running go to agents even if the orchestrator also spent then. Released as 3.9.0 (owner approved the minor bump; 3.8.1 was never published). Protocol §2.8 left unchanged so the template mirror needs no sync.
- Gate: GREEN (bash scripts/e2e.sh, all suites, 34 mod tests, shellcheck 0.11).
- Next: merge by the maintainer.

## 2026-10-13 — session 66 (release 3.8.1, docs only)

- Branch: `release/3.8.1`.
- Done: README section "Start a repo from scratch — just chat" (generic example prompt, scaffold provenance table, audit-then-commit flow). Released 3.8.1 with an Upgrade block (nothing to do). Bumped package.json, both .claude-plugin manifests, claude/.claude-plugin/plugin.json, the e2e version check and the AGENTS.md state line.
- Decisions: patch bump, documentation only; template repo needs no sync because skills/harness-initial-setup/templates/ is unchanged. Considered always generating the agent files at setup; rejected for now, left as a possible later change.
- Gate: GREEN (bash scripts/e2e.sh, all suites).
- Next: merge by the maintainer.

## 2026-10-12 — session 65 (M30-005, release 3.8.0)

- Branch: `m30-models-budget`.
- Done: M30-005 — protocol 1.5: once a plan is approved, its tasks enter
  FEATURES.json as `failing` in the plan's commit. harness-audit FAILs when
  a task heading in an active plan names an id missing from FEATURES.json
  (ids mentioned in prose are ignored). Released 3.8.0 with its Upgrade
  block (dollar budgets in /config, `model_floor`, re-run harness-audit).
  Mirror synced: agent-harness-template PR #4. All M30 features pass; plan
  moved to completed.
- Decisions: audit reads task headings only, so a plan can mention other
  features in prose; FAIL rather than WARN because a missing feature hides
  the plan's progress, which is the point of the rule.
- Gate: green (31 mod tests; shellcheck 0.9 clean).
- Next: owner merges kit PR, then template PR #4.

## 2026-10-12 — session 64 (M30-004)

- Branch: `m30-models-budget`.
- Done: M30-004 — `status.sh --line` prints the harness in one line for a
  person's own status line script (next feature, passing/total, waiting on
  a human, the run's dollars from `.harness-run/cost.log`), and nothing
  (exit 3) outside a harness so their line is unchanged there. `--watch
  [SECONDS]` redraws the report for a second terminal; `HARNESS_WATCH_COUNT`
  bounds it for tests. Both for any agent. README explains both.
- Decisions: `--line` computes the next feature with the same held logic as
  the report (the jq definition moved up so both share it); silence rather
  than an error line outside a harness, since it runs inside someone else's
  status line.
- Gate: green; shellcheck 0.9 clean.
- Next: M30-005 (plan tasks in FEATURES.json once approved; release 3.8.0).

## 2026-10-12 — session 63 (M30-003)

- Branch: `m30-models-budget`.
- Done: M30-003 — the edition's own status line (beside the person's own,
  never replacing it): `harness <feature> · <passing>/<total> passing ·
  $spent/$budget · <model> · N waiting on you`, with the last budget or
  supervisor notice appended; refreshed at session start, each builder start
  and each turn. `/harness` prints milestones, the next feature (held ones
  skipped), what waits on a human and the session's cost from FEATURES.json:
  no model call. Checked live with `claude -p "/harness"` on this repo, which
  showed milestones 28-30 had no names in FEATURES.json: named now.
- Decisions: the status helper is a top-level function (the engine follows
  `$` only into top-level functions of the hooks file); the supervisor and
  budget notices became part of the line instead of replacing it.
- Gate: green (31 mod tests).
- Next: M30-004 (status.sh --line and --watch).

## 2026-10-12 — session 62 (M30-002)

- Branch: `m30-models-budget`.
- Done: M30-002 — budgets in dollars. `feature_budget_usd` (default $5)
  and `run_budget_usd` (default $50) replace `feature_token_budget`; both
  measured from `$.session.usage().cost.usd`, counted from session start and
  reset per feature at each SESSION line. Over budget during a run: STOP and
  a `budget.log` line; outside a run only the status line; 0 turns a budget
  off; no cost ledger, no action. Each builder session's cost goes once to
  `.harness-run/cost.log` (an orchestrator echo is not counted again). The
  run report sums it per feature and adds the model and any step-up from
  `models.log`. README updated.
- Decisions: the session's own cost figure rather than tokens times a price
  table (verified live to include subagents); per-feature cost is the delta
  between SESSION lines, so parallel lanes share one figure (documented);
  defaults $5 and $50 are placeholders for the owner to set in /config.
- Gate: green (27 mod tests; shellcheck 0.9 clean).
- Next: M30-003 (status line and /harness).

## 2026-10-12 — session 61 (M30-001)

- Branch: `m30-models-budget`.
- Done: M30-001 — the Claude Code edition picks each harness builder's
  model in an `agent.spawn` hook: effort low haiku, medium or none sonnet,
  high/max opus (aliases only); one tier up per earlier start of the feature
  (`.harness-run/models.log`) and per `eval_attempts`, capped at opus; the
  evaluator and features whose paths touch auth, payments, billing,
  migrations, secrets, credentials or personal data never below sonnet;
  `model_floor` and `route_models` settings. Forks, teammates, workflow
  agents, other subagents and the main session are untouched. Checked live
  first on 2.1.296: the rewrite starts the subagent on `claude-haiku-5-5`.
- Decisions: escalation counts earlier starts instead of parsing outcomes
  (any retry means the last model was not enough); a feature with no effort
  starts on sonnet, not haiku (an unlabelled feature is not known to be easy).
- Gate: green (27 mod tests).
- Next: M30-002 (budgets in dollars).

## 2026-10-07 — session 60 (M29-002 follow-up)

- Branch: `m29-run-speed`.
- Done: upgrade.sh updates the first line of AGENTS.md's "Needs a human"
  section itself when it is still the old template wording (CHANGED), says
  OK when current, and prints a TODO only when the owner edited that
  section. Fixtures in test-upgrade.sh. The 3.7.0 Upgrade block no longer
  asks for a manual edit.
- Decisions: replace only an exact match of the old template line; an
  edited section is the owner's text and is never rewritten.
- Gate: green.
- Next: owner merges.

## 2026-10-07 — session 59 (M29-003, release 3.7.0)

- Branch: `m29-run-speed`.
- Done: M29-003 — status.sh prints `paths:` under `NEXT:` and harness-run
  passes them to the builder ("Start reading from: …"). The run report
  shows minutes per done feature (commit times since the previous feature
  or skip) and tokens from `.harness-run/tokens.log`, which the Claude Code
  edition's budget guard writes once per feature at its builder's SESSION
  line (an orchestrator's echo is ignored). Band test stubs left the test
  world. Released 3.7.0; mirror synced onto the open template PR #3. All
  M29 features pass; plan moved to completed.
- Decisions: builder effort left unchanged until real per-feature numbers
  exist; minutes come from git so every agent gets them, tokens only where
  an agent can count them.
- Gate: green. Checked with Ubuntu's shellcheck 0.9 too (what CI runs).
- Next: owner merges; CI checked after push.

## 2026-10-07 — session 58 (M29-002)

- Branch: `m29-run-speed`.
- Done: M29-002 — waiting on a human. A `deferred` feature whose notes
  start `Needs a human: <question>` is listed by status.sh
  (`WAITING ON HUMAN:`), and failing features whose `depends_on` reaches it,
  transitively, are `HELD:` and never NEXT, with or without `--skip`. The
  run report gets a "Waiting on a human" section and explains held
  features under Not started. Planning §1.4 asks the question; AGENTS.md.tmpl,
  harness-session and the runs part tell a blocked session to defer its own
  feature that way, so later runs do not retry it. README explains both
  this and the reused baseline.
- Decisions: reused `deferred` plus a notes prefix rather than a new
  `needs_human` field (status.sh already skips deferred; no schema change);
  only explicit `depends_on` holds a feature (an undeclared one may well be
  independent, unlike a skip where the run must be conservative).
- Gate: green.
- Next: M29-003 (paths hint, per-feature time and tokens, release 3.7.0).

## 2026-10-07 — session 57 (M29-001)

- Branch: `m29-run-speed`.
- Done: M29-001 — run-gate.sh reuses a proven-green baseline. Every green
  run stores a fingerprint (git tree of the working tree through a
  throwaway index; ignored files, PROGRESS.md and docs/plans/ left out) in
  the clone's git dir; a red run deletes it. A baseline on a clean tree
  with the same fingerprint prints `GATE: green (baseline reused …)` without
  running the gate. Fixtures: bookkeeping-only commit reuses; a code
  change, FEATURES.json change, new file, dirty tree, red last run and
  `HARNESS_GATE_REUSE=0` each run it; the worktree is never written.
  Protocol 2.3 and harness-session say a reused baseline is green.
- Decisions: fingerprint the tree rather than compare HEAD with the last
  green commit (the final gate runs before the status-flip commit, so HEAD
  never matches); FEATURES.json stays in the fingerprint because gates may
  validate it; stored under the git dir so nothing needs ignoring and each
  worktree has its own.
- Gate: green.
- Next: M29-002 (waiting on a human).

## 2026-10-07 — session 56 (M28-004, release 3.6.0)

- Branch: `m28-lean`.
- Done: M28-004 — the next-steps band mod is gone (hook, state atoms,
  state types, test, README bullet); the decision register, supervisor and
  budget guard stay (17 mod tests green). Released 3.6.0: CHANGELOG entry
  with its Upgrade block, all manifests bumped. Mirror synced onto the
  still-open agent-harness-template PR #3 (retitled 3.6.0; its banner and
  README now point planning at `harness-protocol-planning.md`). All M28
  features pass; plan moved to completed.
- Decisions: stacked the mirror sync on open PR #3 rather than a second PR
  (one merge for the owner, and #3 was not yet merged); kept
  `register.tsx` as its file name (renaming to .ts churns hooks.json and the
  gate for nothing).
- Gate: green.
- Next: owner merges both PRs; then the first real unattended run.

## 2026-10-07 — session 55 (M28-003)

- Branch: `m28-lean`.
- Done: M28-003 — size limits and rule expiry. The gate fails when the
  session core passes 150 lines (proved by padding it) or AGENTS.md.tmpl
  passes 70. A rule a session adds to AGENTS.md ends with
  `(added <YYYY-MM-DD>)`, plus `; model: <name>` for one model's failure;
  harness-audit warns on rules older than 90 days and still counts
  model-tagged ones (both tag forms). The show-me rule left AGENTS.md.tmpl:
  it lives once, in the session core.
- Decisions: expiry by date rather than a free-text "remove when"
  condition (a date is checkable by script); 90 days, about two model
  releases; a WARN, never a FAIL (deleting rules is a human call).
- Gate: green.
- Next: M28-004 (drop the next-steps band; release 3.6.0).

## 2026-10-07 — session 54 (M28-002)

- Branch: `m28-lean`.
- Done: M28-002 — the protocol is four files. `harness-protocol.md` is the
  session core (§2.1–2.6, 143 lines, was 592) with an index;
  `harness-protocol-planning.md` (§1), `harness-protocol-runs.md` (§2.7–2.8)
  and `harness-protocol-maintenance.md` (§3) are read only when needed.
  Setup copies all four; upgrade.sh, harness-audit, context.sh and
  sync-template.sh handle each (fixtures for a missing part, a drifted
  part, a pre-split repo). Planning and maintenance prompts name their
  files; handoff keeps the old prompt for repos not yet upgraded.
- Decisions: kept section numbers and the core's file name, so every `§`
  reference, plan header and "section 2" prompt still works (no 4.0.0);
  rejected a single file with "read only up to here" markers (agents read
  whole files). Trimmed the show-me and workflow-plugin paragraphs while
  moving them.
- Gate: green.
- Next: M28-003 (size limits and rule expiry).

## 2026-10-07 — session 53 (M28-001)

- Branch: `m28-lean`.
- Done: M28-001 — no model names anywhere. `agents/models.json` deleted;
  agent sources lose `tier`; generated agents carry no model line, so every
  CLI uses its own default; second-opinion.sh passes no model flag and the
  fallback is gone; harness-run states the security-checklist trigger in
  words (auth, payments, personal data, migrations) instead of globs. README
  has one line of advice with no model names.
- Decisions: dropped the table outright rather than defaulting every tier to
  `auto` (a table nobody fills is still a table to maintain); kept `effort`,
  which is vendor-neutral and does not go stale.
- Gate: green.
- Next: M28-002 (split the protocol).

## 2026-10-07 — session 52 (M27-005, release 3.5.0)

- Branch: `m27-upgrades`.
- Done: M27-005 — `scripts/sync-template.sh <mirror> [--check]` writes every
  template to its agent-harness-template path, keeping the mirror's banner
  (bare `>` lines included), README and docs/PRODUCT.md; idempotent;
  `--check` exits 1 on drift. Fixture in `scripts/test-sync-template.sh`.
  The real mirror was last synced at M13: synced now, agent-harness-template
  PR #3 (`--check` IN SYNC). CHANGELOG's release checklist names the script.
  Released 3.5.0. All M27 features pass; plan moved to completed.
- Decisions: the mirror keeps only what is truly its own (banner, README,
  PRODUCT skeleton); everything else is generated, so drift is a script
  run away. A first sync cut the banner at a bare `>` line: caught by
  reading the result, fixed, and the fixture now has one.
- Also: two commits earlier on this branch (949033a, da5fc3d) were made on a
  red gate because its output was piped to `tail`, hiding the exit code;
  fixed in 0a325cc, and every commit since checks the gate's own exit code.
- Gate: green.
- Next: owner merges both PRs; then the first real unattended run.

## 2026-10-07 — session 51 (M27-004)

- Branch: `m27-upgrades`.
- Done: M27-004 — a clear upgrade every release. `CHANGELOG.md` (3.0.0 to
  3.5.0, newest first) gives each release an `Upgrade:` block; the gate fails
  when the current version has none. upgrade.sh stamps
  `docs/agents/harness-kit-version` and prints `UPGRADE-NOTE: <version>:
  <step>` for every release after the stamp up to the installed kit, oldest
  first (all when unstamped). harness-upgrade-structure relays the notes;
  README "Upgrading after every release" is the eight-step checklist (plugin
  update commands checked against copilot 1.0.92 and codex 0.160.1 help).
  Fixtures in test-upgrade.sh.
- Decisions: notes live in the CHANGELOG (one source a human and the script
  both read) instead of per-release scripts; portable version compare in
  bash (macOS has no tac, and sort -V is not guaranteed); notes capped at the
  installed kit version so a CHANGELOG ahead of the manifests prints nothing
  extra.
- Gate: green.
- Next: M27-005 (template mirror sync, release 3.5.0).

## 2026-10-07 — session 50 (M27-003)

- Branch: `m27-upgrades`.
- Done: M27-003 — run-report.sh puts each done feature's newest PROGRESS.md
  `Decisions:` line under it (wrapped lines joined), adds a Supervisor
  section from `.harness-run/decisions/<id>.skipped.md` and a Budget section
  from `.harness-run/budget.log`, each only when the files exist. Protocol
  §2.8 says so. Fixtures in test-run.sh; output stays deterministic.
- Decisions: read the signals from `.harness-run/` at report time rather
  than copying them into commits (they are run state, git-ignored); one line
  per feature for skipped work so the report stays a one-page read.
- Gate: green.
- Next: M27-004 (upgrade process).
- Note: the M27-003 code landed in 3c84130, but its status flip, this entry
  and the protocol line were left out by a failed edit step; they landed
  with the M27-004 follow-up commit.

## 2026-10-07 — session 49 (M27-002)

- Branch: `m27-upgrades`.
- Done: M27-002 — models.json follows the owner's rule of thumb: Claude
  `opus` for complex work and `sonnet` for implementation; ChatGPT
  `gpt-6-astra` for complex work and `gpt-6.1-sol` for executing (Codex);
  Copilot's strong tier is `gpt-6-astra`, so a Copilot second opinion next to
  a Claude builder is another vendor. A tier of `auto` (or none) lets the
  CLI choose: gen-agents.sh writes no model line, second-opinion.sh passes
  no flag. second-opinion.sh retries once without a model when the CLI
  rejects the named one, printing `MODEL: <name> unavailable, <cli> chose its
  own`. harness-run swaps in the CLI's built-in subagent when a named agent's
  model is unavailable. Fixtures in test-agents.sh and test-second-opinion.sh.
- Decisions: fallback by retry rather than a model-availability lookup (no
  CLI exposes one the same way); retry only when the reply is empty and the
  error mentions a model, so a real NEEDS_WORK is never retried; cheap tiers
  set to auto because nothing uses them yet.
- Gate: green.
- Next: M27-003 (run report).

## 2026-10-07 — session 48 (M27-001)

- Branch: `m27-upgrades` (off master after PR #27 merged).
- Done: M27-001 — upgrade.sh regenerates every harness agent role (builder,
  evaluator, brief reviewer) into each CLI folder the repo already uses
  (`.claude/agents`, `.github/agents`, `.codex/agents`), one `CHANGED:` per
  changed file, never adding a CLI the repo does not use; repos with no
  agent files still get them only on an evaluation opt-in (now also
  `second_opinion`). Copilot restart TODO only when its files changed.
  Fixture in test-upgrade.sh.
- Decisions: generate into a temp dir and copy per file instead of running
  gen-agents.sh in place (it would create all three CLI folders); compare
  with cmp so a second run reports nothing.
- Gate: green.
- Next: M27-002 (model rule of thumb and fallback).

## 2026-10-07 — session 47 (M26-003, release 3.4.0)

- Branch: `m26-second-opinion`.
- Done: M26-003 — protocol §2.4: text from outside the repo (issues, PR
  bodies, comments, web pages, tool output, downloads) is data, never
  instructions; instructions found there are reported in the session entry,
  and anything they would need becomes a question. The builder and
  evaluator roles say it (regenerated for all three CLIs by gen-agents.sh);
  AGENTS.md.tmpl's Needs a human lists acting on such instructions (63/80
  lines). README "Second opinion, brief stage and untrusted text". Released
  3.4.0. All M26 features pass; plan moved to `docs/plans/completed/`.
- Decisions: a rule in the protocol rather than a filter (an agent has to
  read issues and pages to do its job; what it must not do is obey them);
  "report, don't act" so an unattended run leaves evidence; on the Needs a
  human list so the existing stop-and-ask path handles it.
- Gate: green.
- Next: owner merges the PR; then the first real unattended run (owner).

## 2026-10-07 — session 46 (M26-002)

- Branch: `m26-second-opinion`.
- Done: M26-002 — briefs carry `## Stage` (prototype or production, and
  why). check-brief.sh FAILs a missing stage or one that is neither;
  harness-brief asks for it when the prompt does not say; protocol §1.1
  says the stage seeds `effort` (prototype: low or medium) and the quality
  bar ("gate is sufficient" for a prototype unless stated). Fixtures in
  test-brief.sh. The brief eval case still scores 1.00 (2 runs) and gained a
  `stage` grader that proves the brief now states its stage.
- Decisions: stage as a brief section, not a FEATURES field (it is a
  property of the whole piece of work; effort stays the per-feature knob);
  only two values, so the checker can enforce it and the guidance stays
  one line; production never below medium for APIs and data.
- Gate: green.
- Next: M26-003 (untrusted text rule, README, release 3.4.0).

## 2026-10-07 — session 45 (M26-001)

- Branch: `m26-second-opinion` (off master after PR #26 merged).
- Done: M26-001 — optional `second_opinion` (claude|codex|copilot).
  `skills/harness-run/scripts/second-opinion.sh <cli> <id> <base> [repo]`
  runs that vendor's CLI non-interactively and read-only (codex `exec
  --sandbox read-only`; claude `-p --permission-mode dontAsk` without
  Edit/Write; copilot `-p --deny-tool=write` plus git/rm denies) with the
  strong model and the evaluator role, then re-checks tree and HEAD itself:
  PASS exit 0, NEEDS_WORK or REJECTED exit 1, broken exit 2. harness-run
  requires both verdicts to PASS; harness-continuous skips on exit 2 or
  REJECTED; harness-session ends such a feature in review; check.sh WARNs
  when the CLI is missing. Protocol §1.4/§2.7 (vendor-neutral). Fixtures with
  stub CLIs (`scripts/test-second-opinion.sh`); live run with the real claude
  CLI returned PASS with the tree untouched.
- Decisions: shell out per CLI instead of a generated agent file (another
  vendor's agent is another process); the script's own integrity check is
  the guarantee, read-only flags are defence in depth (copilot's shell can
  still write); a feature with only `second_opinion` uses it as its
  evaluation rather than also dispatching the in-CLI evaluator; codex and
  copilot not run live (no credentials in this workspace).
- Gate: green.
- Next: M26-002 (brief Stage).

## 2026-10-07 — session 44 (release 3.3.0)

- Branch: `m25-mods`.
- Done: released 3.3.0 (package, both plugin manifests, marketplace).
  Live check in headless Claude Code 2.1.292 with the core and the edition
  on `--plugin-dir`: the hooks module loads (events session.start,
  tool.call, turn.complete, ui.render), `register_decision` is listed in a
  harnessed repo and absent in a plain one, and a real call wrote
  `.harness-run/decisions/M1-001.md` with `git status` still clean. With
  the edition alone the engine disables it (dependency-unsatisfied), as it
  should: installing the edition installs the core.
- Decisions: 3.3.0 rather than 4.0.0 for the rename, since the 3.2.0 name
  was public for under an hour; README carries the uninstall/install note.
- Gate: green.
- Next: owner merges the PR.

## 2026-10-07 — session 43 (M25-004)

- Branch: `m25-mods`.
- Done: M25-004 — next-steps band. After a main-loop SESSION line reporting
  `passing` outside an unattended run, an AbovePrompt band offers Next
  feature, Explain (big picture, few words) and Quiz me (each fills the
  prompt for the person to send) and Hide; state in `$.state`
  (`claude/types/index.d.ts`). Nothing for blocked sessions, builder
  subagents or during a run. 5 engine tests over terminal and desktop (22
  total), tsc clean. README documents all four mods and the upgrade from
  the 3.2.0 name; the gate checks it and fails on any other reference to
  the old name (proven). All M23–M25 features pass, so the plan moved to
  `docs/plans/completed/`.
- Decisions: buttons fill the prompt instead of sending it (the person
  stays in control of what runs and what it costs); the band clears on the
  next SESSION line rather than on a timer; the quiz button is the
  podcast's "quiz me after a task" habit made one click.
- Gate: green.
- Next: release 3.3.0, then the PR.

## 2026-10-07 — session 42 (M25-003)

- Branch: `m25-mods`.
- Done: M25-003 — budget guard, in the same `turn.complete` hook as the
  supervisor (one hook per event). Sums each turn's usage per builder
  subagent (one feature) and on the main loop between SESSION lines. Over
  `feature_token_budget` (userConfig, default 1,500,000): a status line;
  during a run (`.harness-run/start` exists) also a reason line in
  `.harness-run/budget.log` and `.harness-run/STOP`, which
  harness-continuous honours after the current feature. 6 engine tests
  (17 total), tsc clean.
- Decisions: excluded cache reads from the count (a tenth of the price,
  and they dominate long sessions, so they would trip the budget on cost
  that barely exists); no STOP outside a run (an interactive session has
  nobody's run to stop, and a stale STOP would end the next run early —
  harness-continuous deletes leftovers, but better not to create them);
  flag each feature once.
- Gate: green.
- Next: M25-004 (next-steps band).

## 2026-10-07 — session 41 (M25-002)

- Branch: `m25-mods`.
- Done: M25-002 — done-check supervisor. On a `turn.complete` whose answer
  has the protocol's `SESSION: <id> · …` line (harnessed repo only), one
  cheap check against the feature's `verify` returns
  `{done, blocked, skipped_work}`: the main loop forks its own cached
  transcript; a builder subagent's messages are read and sent to haiku.
  Skipped work goes to `.harness-run/decisions/<id>.skipped.md` (beside the
  decisions file); a status line says done / blocked / skipped N. Once per
  feature outcome. 7 engine tests (11 total), tsc clean.
- Decisions: rejected forking for subagents (a fork only sees the main
  thread, so it would judge the orchestrator); rejected matching on agent
  type (the SESSION line is the protocol's own contract and works inline
  too); kept the turn's answer unchanged (the supervisor reports, never
  rewrites); capped the subagent transcript at 12k chars to keep it cheap.
- Gate: green.
- Next: M25-003 (budget guard).

## 2026-10-07 — session 40 (M25-001)

- Branch: `m25-mods`.
- Done: M25-001 — the edition's hooks module (`claude/hooks/register.ts`,
  pure logic in `lib.ts`) registers `register_decision` at session start in
  a harnessed repo only. Each call appends `- chose X over Y: why` to
  `.harness-run/decisions/<id>.md`; ids that are not `M<n>-<nnn>` are denied,
  so nothing is written outside `.harness-run/`, which gets a `*`
  .gitignore. harness-session folds the file into the `Decisions:` line.
  4 engine tests (`claude plugin test`), run by the gate when the CLI is
  present; type-checked with tsc against the 2.1.292 declarations.
- Decisions: all hooks in one file (the engine refuses `$` passed across an
  import); one `session.start` hook owns every feature's start step (one
  hook per event); validated the id instead of normalising paths (an
  allow-list is the robust guard); self-ignoring `.harness-run/` instead of
  editing the root .gitignore (harness-run needs a clean tree and must not
  commit run state).
- Gate: green.
- Next: M25-002 (done-check supervisor).

## 2026-10-07 — session 39 (M25-005)

- Branch: `m25-mods` (off master after PR #25 merged).
- Done: M25-005 — the Claude Code edition plugin is `agent-harness-kit-claude`
  again (manifest, marketplace entry, READMEs, ARCHITECTURE). The gate's
  `claude plugin validate --strict` now reads the JSON report and fails on
  every error and warning except the name warning; proven by removing the
  author field (gate red).
- Decisions: kept strict validation instead of dropping to plain validate
  (it would hide real warnings); added the rename as its own feature for
  traceability, done before M25-001 at the owner's request.
- Gate: green.
- Next: M25-001 (decision register mod).

## 2026-10-07 — session 38 (M24-003)

- Branch: `m24-claude-edition`.
- Done: M24-003 — README "Claude Code edition": unattended runs start with
  `claude --permission-mode auto`, never the bypass mode; how to run the
  evals. `claude/evals/` suite: `brief-from-rough-prompt` (rough request →
  brief with all sections, checker run, nothing built) and
  `session-builds-next-feature` (harnessed fixture: builds only M1-001,
  gate run, M1-002 untouched, Decisions: logged, SESSION line). Scaffold
  scripts shellchecked by the gate; results/ ignored.
- Eval result (`claude plugin eval . --eval-dir claude/evals --scaffold
  --allow-tools Write Bash Edit`, 3 runs per arm, about $1.65):
  brief-from-rough-prompt with 1.00 / without 0.50 (Δ +0.50);
  session-builds-next-feature with 1.00 / without 0.75 (Δ +0.25). Every
  case passing.
- Found by the evals: harness-brief and harness-session did not always
  trigger (Claude did the work freehand from the description). Rewrote both
  descriptions to say when, and to always load the skill.
- Decisions: graded files on disk, not prose (stable); dropped the
  fixture's Decisions: line so the case measures what the skill adds (it
  first scored Δ 0.00); kept the eval run out of the gate (costs model
  usage, CI has no claude CLI) and gated the suite's structure instead;
  installed bubblewrap/socat in this workspace so Bash cases are sandboxed.
- Gate: green.
- Next: release 3.2.0 (descriptions changed), then M25-001 (decision
  register mod).

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

## 2026-10-15 — session 71 (M32-001)

- Branch: `m32-m33-run`.
- Done: M32-001 — run-report.sh reads `.harness-run/usage.log`: each done feature gets `<total> tok (in, cached, out)`, Summary gets `Tokens: <total> — feature agents <n>, orchestration <n>`, and the by-model line carries tokens (`Cost by model` with dollars, `Tokens by model` without cost.log). Nothing changes without usage.log. harness-continuous End runs `usage-<cli>.sh` first when it exists. e2e.sh runs every `scripts/test-usage-*.sh`. Fixtures in test-run.sh.
- Decisions: total = input + output (cached is a share of input, not added). Humanising uses integer math (round half up, `1.2M`/`85k`), no printf float, so BWK awk and bash 3.2 stay deterministic. By-model line is a union of cost models and usage models, so orchestration's model shows even with no cost entry; matching is by exact model name, so a cost.log model name differing from the CLI's reported name shows as two entries (shortcut, not reconciled). Rejected: a second awk pass appending tokens only to existing cost entries (would hide the orchestrator's model).
- Gate: green.
- Next: M32-002 (Claude Code hooks write usage.log).

## 2026-10-15 — session 72 (M32 parallel lanes, unattended)

- Branch: `m32-m33-run` (harness-continuous through M33).
- Done: M32-004 (lane, dff5342): `usage-copilot.sh` collects Copilot tokens per feature from SESSION lines, the rest is orchestration; `scripts/test-usage-copilot.sh` reproduces the fixture totals.
- Decisions: M32-004: per-record timestamp filtering against the start commit time (rejected whole-session created_at; rejected session.shutdown totals: absent in crashed sessions, no per-feature split). jq required; repo match on workspace.yaml cwd/git_root only; env overrides COPILOT_HOME and HARNESS_USAGE_REPO for the fixture; premium cross-check not implemented.
- Skipped: M32-002 (lane/M32-002 kept, d6c511c): verify needs an observation from a real Claude Code session; question in its notes. M32-003 (lane/M32-003, e4dcaf3) merged red on the gate's personal-path check (`$W/home/...` in test-usage-codex.sh matches `/home/[a-z]`); merge dropped, redone sequentially next.
- Gate: green.

## 2026-10-15 — session 73 (M32-003)

- Branch: `m32-m33-run`.
- Done: M32-003 — merged lane/M32-003 (e4dcaf3): `usage-codex.sh` collects Codex tokens per feature from SESSION lines (rest is orchestration, model per line); `second-opinion.sh` logs an `<id>/second-opinion codex` line from summed turn.completed usage. Fixed the red gate: test dir `$W/home` renamed `$W/codexhome` so it no longer matches the `/home/[a-z]` hygiene regex (check unchanged).
- Decisions: rejected a time-window split (builder SESSION line attributes exactly); rejected summing token_count events (last total is cumulative). Assumed: a builder thread without a SESSION line counts as orchestration; second-opinion logs only when .harness-run exists, with model "-"; collector appends, so run once at End. Shortcut: .jsonl.zst skipped when zstd is missing, untested (no zst fixture). Rejected weakening the hygiene regex.
- Gate: green.
- Next: M33 features.

## 2026-10-15 — session 74 (M32-005, blocked on the mirror)

- Branch: `m32-m33-run`.
- Done: M32-005 — protocol §2.7/§2.8 gains a token-usage bullet (tokens per feature where the CLI exposes them, nothing estimated, no CLI named); README run-report and upgrade step; CHANGELOG 3.10.0 entry with Upgrade block and the bash 3.2 / BWK awk gate fix; version 3.10.0 in package.json, both plugin manifests and marketplace.json; AGENTS.md state line. e2e.sh checks 3.10.0, the token line and the bash 3.2 changelog mention (red first, then green).
- Decisions: the verify says "protocol 2.8", but the protocol has no numeric version; read it as §2.8 and put the token bullet in §2.7/§2.8 (the run report). Rejected a `PROTOCOL` version stamp (none exists, would be a new mechanism). Rejected estimating tokens for CLIs without usage. Assumed: the protocol copy change makes existing harness repos outdated, so the 3.10.0 Upgrade block says to run harness-upgrade-structure. Shortcut: the token phrase is checked by grep, not by rendering a run report.
- Blocked: `sync-template.sh ../agent-harness-template --check` reports 9 stale files; the mirror PR is outside this repo and was not pushed or written. Status stays `failing` with the note in FEATURES.json.
- Gate: green.
- Next: owner opens the template mirror PR (sync-template.sh), then M32-005 flips to passing; M33 features.

## 2026-10-15 — session 75 (M32-005, mirror prepared)

- Branch: `m32-m33-run`.
- Done: M32-005 — in the template repo cut `sync-3.10.0` from origin/master, ran sync-template.sh (wrote only docs/agents/harness-protocol-runs.md, the 3-line token bullet), committed locally as 23271c2; `--check` is IN SYNC. The mirror branch sync-3.10.0 is committed locally, NOT pushed: awaiting the owner's push and PR. Flipped to passing.
- Decisions: rejected pushing or opening the PR (owner does that). Assumed "clean against the mirror PR" is satisfied by the local mirror branch. The earlier 9 stale files were just the old m13-sync base; origin/master needed only one.
- Gate: green.

## 2026-10-15 — session 76 (M33-001)

- Branch: `m32-m33-run`.
- Done: M33-001 — planning protocol §1.4 gains the `model` question, the small/medium/large table, the alias override, the floors and the step-up rule (no vendor names); FEATURES.json.tmpl `_instructions` names the field; status.sh prints `  model: <value>` under NEXT beside `effort:`; harness-audit WARNs on a model that is not a lowercase alias form (sizes are aliases of that form). Red first in test-status.sh, test-audit.sh and e2e.sh (protocol/template greps), then green.
- Decisions: the plan says "protocol 1.4" and the table lives in harness-protocol-planning.md (the only 1.x file). Rejected an enum-plus-alias-list check in audit (the kit ships no CLI model names, so "known alias" can only mean a form: `^[a-z][a-z0-9._-]*$`); shortcut: a typo like `smal` passes as an alias. Rejected touching the protocol copy in this repo's docs/ (none exists; template is the source). Assumed the existing template mirror drift is handled by M33-005's sync.
- Gate: green.
- Next: M33-002 (Claude Code edition chooseModel reads `model`).
