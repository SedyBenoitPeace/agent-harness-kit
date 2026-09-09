# Architecture — agent-harness-kit

> Living document. Any session whose feature changes the shape described
> here — a new module, entity, cross-cutting invariant, or dependency
> direction — updates the relevant section **in the same commit**
> (harness-protocol.md §2.5). Record shape and invariants, not code
> listings: code churns, invariants rarely do.

## System diagram

```
[Claude Code / Codex plugin loader]
    ↓ reads
[.claude-plugin/  plugin.json + marketplace.json (versions in lockstep)]
    ↓ exposes
[skills/  harness-setup | harness-audit | harness-status | harness-handoff | harness-session]
    │         │                │               │              │                 │
    │    templates/ ★      scripts/check.sh  scripts/     scripts/          scripts/
    │    (canonical          │               status.sh    handoff.sh        context.sh +
    │     scaffold source)   └───────────── two-layer pattern ─────────────────┘  run-gate.sh
    ↓                                  (script = mechanics, SKILL.md = judgment)
[scripts/  e2e.sh (the gate) + test-audit.sh + test-status.sh + test-handoff.sh + test-session.sh]
    ↑ run by
[.github/workflows/gate.yml  CI on push/PR]
```

## Module map

| Path | Responsibility |
|---|---|
| `.claude-plugin/` | Plugin + marketplace manifests; version is the cache key |
| `skills/harness-setup/` | Planning interview + scaffold orchestration (SKILL.md only) |
| `skills/harness-setup/templates/` | ★ Canonical source of every scaffolded file, incl. `harness-protocol.md` |
| `skills/harness-audit/` | Readiness checker (`scripts/check.sh`) + report/repair judgment layer |
| `skills/harness-status/` | Read-only progress report (`scripts/status.sh`) |
| `skills/harness-handoff/` | Session-end ritual check + next-agent prompt (`scripts/handoff.sh`) |
| `skills/harness-session/` | Bounded session context report (`scripts/context.sh`, wraps harness-status) + concise gate wrapper (`scripts/run-gate.sh`) |
| `scripts/` | This repo's gate (`e2e.sh`) and the per-skill fixture test suites |
| `docs/plans/`, `docs/specs/` | Execution plans (active/completed) and the original design spec |

## Key entities & data flow

- **Templates** flow one way: `skills/harness-setup/templates/` → target
  repos (via the setup skill) and → the mirror repo
  `agent-harness-template` (manual resync; this repo stays canonical).
- **FEATURES.json schema** (id / milestone / title / status / verify /
  notes) is defined by `FEATURES.json.tmpl` and consumed by status.sh,
  handoff.sh, and check.sh — all three parse it with jq only.
- **Skill scripts share an exit-code contract:** 0 = report/ready,
  1 = blocked/not-ready, 2 = harness file broken (→ audit),
  3 = not initialized (→ setup). SKILL.md layers branch on these codes.
- **Session data flow:** `context.sh` calls `status.sh` for feature
  selection and last-session text, then layers on git/plan facts of its
  own; `run-gate.sh` calls the target's own `scripts/e2e.sh` unchanged
  and never re-implements or replaces it. Neither script decides what a
  dirty tree means — that judgment stays in `SKILL.md`.

## Cross-cutting invariants

Rules **no feature may violate**, whoever implements it. Read this section
before every session; violating an invariant is a defect even when the
gate is green.

- **Two-layer skill pattern:** everything mechanical lives in a
  deterministic, non-interactive `scripts/*.sh` with fixture tests;
  everything requiring judgment or dialogue lives in SKILL.md. Scripts
  never prompt; SKILL.mds never re-derive what a script computes.
- **`harness-protocol.md` is agent-neutral** — no vendor names (the gate
  greps for 'claude'); vendor specifics live in README and SKILL.mds.
- **`templates/` is the single canonical source**; `agent-harness-template`
  is a mirror, never edited independently.
- **FEATURES.json is append-only** — never delete or renumber ids;
  statuses only from {failing, passing, deferred, superseded}.
- **Both manifest versions stay identical and bump on every release**
  (plugin cache is keyed by version; without a bump, updates no-op).
- **Gate greps are single-line:** any phrase the gate enforces must not
  wrap across lines in the prose that carries it.
- **No personal paths** (`/Users/…`, `/home/…`) in tracked files;
  templates use `{{PLACEHOLDERS}}` only.
- **Line budgets:** AGENTS.md ≤ 100 lines; AGENTS.md.tmpl ≤ 80;
  pointer.md.tmpl ≤ 5.
- **Logging/observability:** this repo has no running service, so it has
  no separate logging system — the PASS/FAIL/WARN report grammar the
  skill scripts already emit (established M7-M8) *is* the observability
  layer. Any future stateful component (a daemon, a server) gets a real
  logging entry here before it ships.
- **`status.sh` remains the sole deterministic feature selector** —
  `context.sh` and any future session tooling delegate to it rather than
  re-deriving the failing/lowest-milestone-then-id pick.
- **Session scripts are read-only** except for executing the target
  repo's own commands (`scripts/e2e.sh`, an optional `scripts/preflight.sh`) —
  `context.sh` and `run-gate.sh` never write to the target repo.
- **Full gate logs are always retained on disk**, even when the terminal
  report is bounded — `run-gate.sh` never discards captured output, only
  the printed summary is capped.
- **Dirty-worktree ownership is never inferred mechanically** — scripts
  report facts (clean/dirty, matching plan or not); classifying a dirty
  tree as continuation, unrelated, or ambiguous is SKILL.md judgment.

## Subsystem notes (per milestone)

### M0–M6 — protocol + templates + CI + mirror repo
Agent-neutral protocol doc and scaffold templates; gate validates
templates by substitution (JSON parse, shellcheck); CI runs the gate;
mirror template repo extracted (Option C).

### M7–M8 — plugin packaging + audit
Repo became the plugin `agent-harness-kit`; `check.sh` established the
two-layer pattern and the PASS/FAIL/WARN report grammar (WARN never
fails a repo — used for legal-but-noteworthy states).

### M11 — status
`status.sh` set the shared exit-code contract (0/2/3) and the rule that
fixture design follows the script's dependencies (git-free script →
plain-dir fixtures).

### M12 — handoff
`handoff.sh` added exit 1 (blocked) to the contract and inverted the
gate default (`--skip-gate` opt-out) because handoff's gate run is the
trust boundary. Fixtures are git repos (clean tree is the point).
Plain-string blocker accumulation: macOS bash 3.2 + `set -u` breaks on
empty-array expansion.

### M13 — architecture
`ARCHITECTURE.md` became a scaffolded artifact (template + protocol
§1.8/§2.5/§3.2); audit WARNs when missing and offers
derive/interview/skip. This file is the dogfood instance.

### M15 — session
`context.sh` bundles harness-status's report with the git/plan facts a
coding session also needs (recent commits, worktree clean/dirty, matching
active plan, optional target `scripts/preflight.sh` discovery) into one
non-mutating call, so an agent starts a session with one round trip
instead of several. It delegates feature selection to `status.sh` rather
than re-deriving it — the two-layer split stays: the script stops at
facts, `SKILL.md` carries the clean/continuation/ambiguous judgment.
`run-gate.sh` wraps the target's own `scripts/e2e.sh` unchanged, retains
the complete captured output in a timestamped log, and bounds the
terminal report so a session doesn't burn context on framework noise —
the exit code always passes through unchanged, so a bounded report is
never a license to treat a red gate as green. `harness-protocol.md` §2.3
and §2.4 were updated in the same milestone to state the clean/
continuation/ambiguous branch, the optional preflight step, and the
out-of-scope-warning rule as portable manual fallbacks, so a repo without
the plugin still gets the same discipline.

### M14 — observability
Protocol §1.9 asks planning to name a logging/observability approach
(never picks one for the human); `ARCHITECTURE.md.tmpl` gained a named
`{{LOGGING_STRATEGY}}` invariant slot; `check.sh` WARNs when a repo's
`ARCHITECTURE.md` doesn't record one. This repo's own answer: the
PASS/FAIL/WARN grammar is the observability layer (see Cross-cutting
invariants) — no separate logging system needed for a CLI tool.
