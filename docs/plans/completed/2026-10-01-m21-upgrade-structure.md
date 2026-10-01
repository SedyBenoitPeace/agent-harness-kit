> **For agentic workers:** each task below is one harness coding session.
> Run it with the harness-session skill if it is installed; otherwise
> follow docs/agents/harness-protocol.md section 2. Do not load any other
> workflow skill or plugin to execute this plan.

# M21: Clear entry points — harness-initial-setup and harness-upgrade-structure

**Goal:** Two commands that say what they are for. `harness-initial-setup`
(the renamed `harness-setup`) scaffolds a harness into a repo that has
none. `harness-upgrade-structure` brings a repo that already has a
harness up to the structure the installed plugin ships, with one
command a human can also run by hand, no agent needed.

**Why:** "harness-setup" does not say it is only for new repos, and
upgrading today is an agent-offered report (`UPGRADE: offer`) with no
command behind it. Owners updating many repos need one explicit,
deterministic step.

**Out of scope:** changing what the harness files contain; auto-applying
an upgrade without the human choosing to run it.

## M21-001 — Rename harness-setup to harness-initial-setup

- `skills/harness-setup/` becomes `skills/harness-initial-setup/` (git mv,
  templates included); frontmatter `name: harness-initial-setup`; its
  description says it is for repos with no harness and points existing
  harnessed repos at harness-upgrade-structure.
- Every live reference follows (skills, scripts, tests, README,
  ARCHITECTURE, AGENTS.md, the shipped templates path). History (completed
  plans, specs, PROGRESS.md, past FEATURES entries) is not rewritten.
- No alias: the old name is gone. A gate check fails on any leftover
  reference outside history.

## M21-002 — upgrade.sh

- `skills/harness-upgrade-structure/scripts/upgrade.sh <repo>` for repos
  that already have FEATURES.json and PROGRESS.md (otherwise: points at
  harness-initial-setup, exit 3). Refuses a dirty tree. On the default
  branch it first creates `harness-upgrade` from it (never commits to the
  default branch).
- Idempotent: recopies the protocol when outdated, adds the harness-run
  line to AGENTS.md when missing, generates evaluator agent files only
  when features opt in. Prints what it changed and what still needs a
  human (an unbounded `scripts/e2e.sh`; `depends_on`/`paths` via
  harness-audit). It stages and commits nothing.

## M21-003 — harness-upgrade-structure skill, wiring, release

- `skills/harness-upgrade-structure/SKILL.md`: invoked by name, runs
  upgrade.sh, then offers harness-audit for `depends_on`/`paths`, and
  commits the result as its own commit.
- harness-session's `UPGRADE: offer` step points to this skill instead
  of listing the steps inline.
- README: a short "Upgrading existing repos" section with the by-hand
  command; the M20 walkthrough step 2 uses it. Release 3.0.0 (a skill was
  renamed, which breaks `/agent-harness-kit:harness-setup`).

## Decision log

- 2026-10-01 — Owner: rename `harness-setup` to `harness-initial-setup`
  and add `harness-upgrade-structure`, explicitly for existing repos;
  work branches from master.
- 2026-10-01 — Assumption (flag if wrong): clean rename with no alias,
  hence a major version (3.0.0). The default-branch rule (branch
  `harness-upgrade` off it) is how "go from master" is applied to the
  upgrade command.
- 2026-10-01 — M21-003: harness-session's `UPGRADE: offer` step now only
  offers harness-upgrade-structure (single source for the upgrade steps).
  The M20 walkthrough's gate checks stayed as they were: step 2 names the
  new skill and step 4 says the upgrade already generates evaluator
  files. The old-name gate check allows exactly one README line (the
  3.0.0 rename note).
