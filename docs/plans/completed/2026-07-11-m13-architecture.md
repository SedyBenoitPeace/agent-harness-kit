# M13: ARCHITECTURE.md scaffolding + audit repair flow — Implementation Plan

**Goal:** The harness scaffolds and maintains a root `ARCHITECTURE.md`
(system diagram, module map, key entities, cross-cutting invariants,
per-milestone subsystem notes). The audit detects its absence and offers a
repair flow — derive from code, interview the human, or skip — the human
chooses. Released as plugin 1.4.0.

**Why:** Field evidence — a coding session in a harnessed repo
(insurance-reminder) invented `ARCHITECTURE.md` spontaneously and linked it
from AGENTS.md. PRODUCT.md captures the why, FEATURES.json the scope;
nothing captured the technical shape, so sessions re-derive it from code.

**Detail-vs-staleness resolution:** depth comes from *accretion with
enforcement*, not a big up-front document. The doc records **shape and
invariants** (which change rarely), never code listings (which churn); each
session that changes the shape updates it **in the same commit** (protocol
§2.5 rule); maintenance (§3.2) checks it against reality.

## Tasks

### Task 1: Branch + plan
- [x] `m13-architecture` off master (post-#11); M12 plan-move folded in.
- [ ] Commit this plan.

### Task 2 (M13-001, gate-first): template + protocol + AGENTS.md.tmpl
- `templates/ARCHITECTURE.md.tmpl`: living-doc banner; required sections
  `## System diagram`, `## Module map`, `## Key entities & data flow`,
  `## Cross-cutting invariants`, `## Subsystem notes (per milestone)`.
- Protocol: repo-shape diagram gains ARCHITECTURE.md; new **§1.8 Write
  ARCHITECTURE.md** (greenfield = intended architecture from the interview,
  marked as such; retrofit = derived from reading the code, human reviews;
  detail rule); §2.5 close-out gains "update ARCHITECTURE.md in the same
  commit" step; §3.2 gains the drift-check bullet. Existing section numbers
  untouched (append 1.8; greps/cross-refs depend on 1.1–1.7).
- `AGENTS.md.tmpl` map gains the ARCHITECTURE.md line.
- Gate: tmpl exists + placeholders + required headers + agent-neutral;
  protocol greps ('Write ARCHITECTURE.md', 'update ARCHITECTURE.md in the
  same commit'); AGENTS.md.tmpl grep.

### Task 3 (M13-002, gate-first): setup scaffolds it, audit repairs it
- `harness-setup/SKILL.md`: scaffold-table row + §2 bullet (§1.8).
- `harness-audit/scripts/check.sh`: WARN (not FAIL) when ARCHITECTURE.md
  missing — pre-1.4.0 harnessed repos stay valid.
- `harness-audit/SKILL.md`: repair flow — on that WARN, offer the human a
  choice: (a) **derive** — read the codebase, draft from the template's
  sections, human reviews before commit; (b) **interview** — ask about
  layers/entities/invariants, then write it; (c) **skip** — record nothing.
  Never silently invent invariants.
- `scripts/test-audit.sh`: fixtures gain ARCHITECTURE.md; new case —
  missing doc still exits 0 with the WARN line.

### Task 4 (M13-003): README coverage + Codex quickstart + release 1.4.0
- README: harness-approach shape, lifecycle step 1 scaffold list, layout
  tree; gate grep. Bump both manifests to 1.4.0.
- New "Quickstart — Codex (plugin)" section (commands field-tested by the
  owner): `codex plugin marketplace add <repo-url>`, `codex plugin add
  agent-harness-kit@agent-harness-kit`, upgrade via `codex plugin
  marketplace upgrade agent-harness-kit`. Claude quickstart gains its
  update command (`claude plugin update agent-harness-kit`).

### Task 5: Close out — FEATURES.json M13-001..003 + PROGRESS.md, PR.
**Owner merges; publish decision (repo → public) follows the merge.**

## Decision log

- **2026-07-11 — root ARCHITECTURE.md, not docs/.** Matches the user's
  field practice (insurance-reminder) and the widely-known
  matklad ARCHITECTURE.md convention; AGENTS.md points to it.
- **2026-07-11 — audit WARNs; the skill layer repairs.** check.sh stays
  deterministic and non-blocking (older harnessed repos are legal); the
  choose-your-repair flow (derive/interview/skip) is judgment, so it lives
  in SKILL.md. User explicitly requested the human chooses.
- **2026-07-11 — §1.8 appended rather than inserting after §1.2.**
  Renumbering 1.3–1.7 would break the gate's greps and the doc's internal
  cross-references (§1.4 etc.) for zero reader benefit.
- **2026-07-11 — Codex quickstart folded into M13.** The owner supplied
  the field-tested commands mid-plan; no reason to defer.
- **2026-07-11 — follow-up, not in this milestone:** resync
  agent-harness-template with the new template + protocol.
