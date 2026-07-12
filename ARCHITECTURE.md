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
[skills/  harness-setup | harness-audit | harness-status | harness-handoff]
    │         │                │               │              │
    │    templates/ ★      scripts/check.sh  scripts/     scripts/
    │    (canonical          │               status.sh    handoff.sh
    │     scaffold source)   └──────── two-layer pattern ────────┘
    ↓                                  (script = mechanics, SKILL.md = judgment)
[scripts/  e2e.sh (the gate) + test-audit.sh + test-status.sh + test-handoff.sh]
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

### M14 — observability
Protocol §1.9 asks planning to name a logging/observability approach
(never picks one for the human); `ARCHITECTURE.md.tmpl` gained a named
`{{LOGGING_STRATEGY}}` invariant slot; `check.sh` WARNs when a repo's
`ARCHITECTURE.md` doesn't record one. This repo's own answer: the
PASS/FAIL/WARN grammar is the observability layer (see Cross-cutting
invariants) — no separate logging system needed for a CLI tool.
