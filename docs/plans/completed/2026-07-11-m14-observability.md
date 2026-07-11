# M14: Logging/observability planning gap + audit repair flow — Implementation Plan

**Goal:** The harness surfaces the logging/observability gap without imposing
a technology choice. Planning (§1.9, new) asks the human to name where logs
land and how a session inspects them, the same way §1.7 names the
verification tool. `harness-audit` WARNs when a harnessed repo's
`ARCHITECTURE.md` doesn't record that decision and offers the same
derive/interview/skip repair flow used for the ARCHITECTURE.md gap itself.
Released as plugin 1.5.0.

**Why:** Field observation — two repos the owner ran the harness on are
otherwise healthy, but neither planning nor audit ever raised logging. The
owner would have to run a separate ad-hoc plan per repo to retrofit it.
Mirrors the exact gap ARCHITECTURE.md closed in M13: a decision that matters
to every future debugging session but that nothing in the harness asks for
or checks.

**Scope boundary (explicit, per owner):** the harness only highlights the
gap and records the decision — it never picks a logging technology or
implementation on the human's behalf. "None yet, revisit at milestone N" is
a legal, complete answer. Actually building logging infrastructure where a
repo has none is ordinary feature work: a `FEATURES.json` entry with a
falsifiable `verify`, built through the normal one-feature-per-session loop
— not a new skill.

**Design decision (no new skill):** logging/observability does not get its
own `harness-*` skill. Same reasoning as ARCHITECTURE.md: the audit +
repair-flow mechanism already exists precisely to absorb new gaps like this
one; a skill per gap would keep multiplying the command surface for no
reader benefit.

## Tasks

### Task 1: Branch + plan
- [x] `m14-observability` off master.
- [ ] Commit this plan.

### Task 2 (M14-001, gate-first): protocol + template placeholder
- `harness-protocol.md`: new **§1.9 Choose the logging/observability
  approach**, appended after §1.8 (never renumber 1.1-1.8 — greps and
  cross-refs depend on it, same rule M13 established). Per-stack table
  mirroring §1.7's shape (web/API/CLI/mobile/library — where logs land,
  how a session inspects them). States the scope boundary: planning
  decision, not a build task; recorded in ARCHITECTURE.md's cross-cutting
  invariants; "none yet" is legal.
- `templates/ARCHITECTURE.md.tmpl`: Cross-cutting invariants section gains
  a named `{{LOGGING_STRATEGY}}` placeholder (distinct from the generic
  `{{INVARIANT_1}}`/`{{INVARIANT_2}}` slots) so scaffolding forces the
  decision onto the page instead of leaving it implicit.
- `harness-setup/SKILL.md`: step referencing §1.9 alongside the existing
  §1.8 ARCHITECTURE.md step.
- Gate: protocol contains 'Choose the logging/observability approach' and
  stays agent-neutral; ARCHITECTURE.md.tmpl contains `{{LOGGING_STRATEGY}}`.

### Task 3 (M14-002, gate-first): audit WARN + repair flow
- `harness-audit/scripts/check.sh`: WARN (never FAIL) when `ARCHITECTURE.md`
  exists but doesn't mention a logging/observability approach — same
  non-blocking treatment as the ARCHITECTURE.md-missing check, so repos
  harnessed before 1.5.0 stay legal.
- `harness-audit/SKILL.md`: "Missing logging strategy — repair flow"
  section, same three options as the ARCHITECTURE.md repair flow (derive
  from code / interview the human / skip), plus the explicit note that
  building actual logging infra (vs. documenting the decision) is ordinary
  feature work, not part of this flow.
- `scripts/test-audit.sh`: fixtures gain the logging line (via the
  template placeholder); new case — stripping it from a fixture's
  ARCHITECTURE.md still exits 0 but emits the WARN line.

### Task 4 (M14-003): README + release 1.5.0
- README: one-line mention alongside existing ARCHITECTURE.md coverage.
  Bump both manifests to 1.5.0.

### Task 5 (M14-004): dogfood this repo's own answer
- This repo's own `ARCHITECTURE.md` gains a real (not placeholder) logging
  entry: the PASS/FAIL/WARN report grammar the skill scripts already emit
  *is* this repo's observability layer (established M7-M8, no separate
  logging system needed for a CLI tool with no running service). Recorded
  under Cross-cutting invariants + a short M14 Subsystem note.

### Task 6: Close out — FEATURES.json M14-001..004 + PROGRESS.md, PR.
**Owner merges.**

## Decision log

- **2026-07-11 — no new skill.** Same reasoning as M13's ARCHITECTURE.md
  repair flow: the audit+repair-flow mechanism exists to absorb exactly
  this kind of gap. Owner explicitly confirmed.
- **2026-07-11 — WARN only, never FAIL.** Mechanical detection of "does
  this repo log adequately" isn't reliable across arbitrary stacks; the
  check can only prove "was it planned," not "was it done well" — same
  limitation the ARCHITECTURE.md check already accepts.
- **2026-07-11 — §1.9 appended after §1.8, not inserted after §1.7** (its
  more natural neighbor). Renumbering would break existing greps/cross-refs
  for zero reader benefit — same rule as M13's §1.8 placement.
- **2026-07-11 — named `{{LOGGING_STRATEGY}}` placeholder, not folded into
  the generic invariant slots.** Forces the decision to be visible at
  scaffold time and gives `check.sh`'s WARN a stable anchor string instead
  of a generic "logging" keyword grep across arbitrary invariant prose.
- **2026-07-11 — retrofitting the two owner repos is out of scope for this
  plan.** It's the ordinary audit → repair-flow path once 1.5.0 ships, run
  per repo, not harness-kit work.
