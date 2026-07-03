# harness-planning Skill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the open-source `harness-planning` Claude Code skill + portable protocol pack described in `docs/specs/2026-07-03-harness-planning-skill-design.md`, dogfooding the harness in this repo itself.

**Architecture:** Everything of substance lives in portable markdown templates under `skill/harness-planning/templates/`; `SKILL.md` is a thin Claude orchestration layer on top. This repo runs its own harness (FEATURES.json, PROGRESS.md, `scripts/e2e.sh` lint gate), and every task below follows a TDD analog: extend the gate with a failing check → create the artifact → gate green → record feature as passing → commit.

**Tech Stack:** bash + jq + shellcheck (gate), plain markdown (deliverables). No build system, no dependencies beyond `jq` and `shellcheck`.

## Global Constraints

- Spec is authoritative: `docs/specs/2026-07-03-harness-planning-skill-design.md`.
- `AGENTS.md` (this repo and the template) is a table of contents: **≤100 lines** (template budget: ≤80 lines, leaving adaptation room).
- FEATURES.json statuses are exactly: `failing | passing | deferred | superseded`. Every feature has a non-empty `verify` field. Never delete or renumber entries.
- **A FEATURES.json entry is added in the same commit that implements it and proves it passing** — never commit a standalone batch of `failing` entries (user harness rule; the full backlog lives in this plan instead).
- Templates use `{{PLACEHOLDER}}` syntax only. No personal paths, keys, or private project names in any committed file (the gate enforces the path part mechanically).
- The gate is sacred: `bash scripts/e2e.sh` must exit 0 at the end of every task.
- Work happens on local branch `m0-harness-scaffolding` (and successor milestone branches). **No GitHub interaction until the user says so** — no remotes, no PRs; integration method decided later.
- Pillar articles are linked, never reproduced: [Anthropic — Effective harnesses for long-running agents](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents), [OpenAI — Harness engineering](https://openai.com/index/harness-engineering/).
- Every session: append a newest-first entry to `PROGRESS.md` before ending.

## Task → Feature map (the backlog; entries land in FEATURES.json as they pass)

| Task | Feature | Milestone | Deliverable |
|------|---------|-----------|-------------|
| 1 | M0-001 | 0 Harness scaffolding | `scripts/e2e.sh` gate + FEATURES.json + PROGRESS.md |
| 2 | M0-002 | 0 Harness scaffolding | LICENSE, .gitignore, README stub, AGENTS.md refresh |
| 3 | M1-001 | 1 Portable templates | `FEATURES.json.tmpl` + `PROGRESS.md.tmpl` |
| 4 | M1-002 | 1 Portable templates | `AGENTS.md.tmpl` + `pointer.md.tmpl` |
| 5 | M1-003 | 1 Portable templates | `dev.sh.tmpl` + `e2e.sh.tmpl` |
| 6 | M2-001 | 2 Protocol doc | `harness-protocol.md` §1 Planning protocol |
| 7 | M2-002 | 2 Protocol doc | `harness-protocol.md` §2 Coding-session protocol |
| 8 | M2-003 | 2 Protocol doc | `harness-protocol.md` §3 Maintenance protocol |
| 9 | M3-001 | 3 Claude skill | `SKILL.md` |
| 10 | M4-001 | 4 Release | Full README.md |
| 11 | M4-002 | 4 Release | Acceptance test: fresh agent completes one session in a scaffolded sandbox |

---

### Task 1: The gate + repo harness files (M0-001)

**Files:**
- Create: `scripts/e2e.sh`
- Create: `FEATURES.json`
- Create: `PROGRESS.md`

**Interfaces:**
- Produces: `bash scripts/e2e.sh` — exit 0 = green, prints `GATE GREEN`; `fail()` helper prints `GATE FAIL: <msg>` and exits 1. All later tasks append checks to this script above the final `echo "GATE GREEN"` line.
- Produces: `FEATURES.json` with top-level keys `_instructions` (string), `milestones` (object), `features` (array of `{id, milestone, title, status, verify, notes}`).

- [ ] **Step 1: Verify the failing baseline**

Run: `bash scripts/e2e.sh`
Expected: FAIL — `bash: scripts/e2e.sh: No such file or directory`

- [ ] **Step 2: Check tool availability**

Run: `command -v jq && command -v shellcheck`
If either is missing: `brew install jq shellcheck`

- [ ] **Step 3: Write `scripts/e2e.sh`**

```bash
#!/usr/bin/env bash
# Gate for the harness-planning-skill repo. Exit 0 = green.
# Run at the start (baseline) and end (proof) of every session.
set -euo pipefail
cd "$(dirname "$0")/.."

fail() { echo "GATE FAIL: $*" >&2; exit 1; }

command -v jq >/dev/null || fail "jq is required (brew install jq)"
command -v shellcheck >/dev/null || fail "shellcheck is required (brew install shellcheck)"

# --- repo harness ---------------------------------------------------------

# FEATURES.json: valid JSON with the required top-level shape
jq -e '(.milestones | type == "object") and (.features | type == "array")' \
  FEATURES.json >/dev/null 2>&1 \
  || fail "FEATURES.json: invalid JSON or missing milestones/features"

# every feature entry is complete and uses a legal status
jq -e '[ .features[]
         | select( ((.id? // "") == "") or ((.title? // "") == "")
                   or ((.verify? // "") == "")
                   or ((.status? // "") | IN("failing","passing","deferred","superseded") | not) )
       ] | length == 0' FEATURES.json >/dev/null \
  || fail "FEATURES.json: entry missing id/title/verify or has illegal status"

# AGENTS.md stays a table of contents
[ "$(wc -l < AGENTS.md)" -le 100 ] || fail "AGENTS.md exceeds 100 lines"

# no personal/local paths leaked into tracked files
if git grep -nIE '/Users/[a-z]|/home/[a-z]' -- ':!scripts/e2e.sh' >/dev/null 2>&1; then
  fail "personal path leaked into a tracked file"
fi

# this repo's scripts are clean shell
shellcheck scripts/*.sh

echo "GATE GREEN"
```

- [ ] **Step 4: Write `FEATURES.json`**

The `_instructions` string is the spec §5 text verbatim. Milestones are declared upfront (they are not `failing` entries); only the feature this commit proves is present.

```json
{
  "_instructions": "Source of truth for the build. DO NOT delete, edit, or renumber existing ids/titles. Statuses: passing (done+proven), failing (actionable), deferred (postponed; notes say when actionable), superseded (dead, kept for history). Flip failing->passing only when a test or the stated manual check proves it. Append new features with the next id in their milestone. Work ONE feature per session: lowest milestone, then lowest id, among 'failing'.",
  "milestones": {
    "0": "Harness scaffolding & open-source hygiene",
    "1": "Portable templates",
    "2": "harness-protocol.md (agent-neutral operating manual)",
    "3": "Claude skill front-end (SKILL.md)",
    "4": "Release: README + acceptance test"
  },
  "features": [
    {
      "id": "M0-001",
      "milestone": 0,
      "title": "Repo gate (scripts/e2e.sh) + FEATURES.json + PROGRESS.md scaffolded",
      "status": "passing",
      "verify": "bash scripts/e2e.sh exits 0 and prints GATE GREEN",
      "notes": "Backlog for remaining features lives in docs/plans/active/2026-07-03-harness-planning-skill-implementation.md; entries are appended here in the commit that proves them."
    }
  ]
}
```

- [ ] **Step 5: Write `PROGRESS.md`**

```markdown
# PROGRESS

Newest-first session log. One entry per working session. Read this (plus
`git log -20` and FEATURES.json) at the start of every session.

## 2026-07-03 — session 1

- Branch: `m0-harness-scaffolding`
- Done: M0-001 — gate script, FEATURES.json, PROGRESS.md scaffolded.
- Gate: green (`bash scripts/e2e.sh`).
- Next: M0-002 — LICENSE, .gitignore, README stub, AGENTS.md refresh.
```

- [ ] **Step 6: Make executable and run the gate**

Run: `chmod +x scripts/e2e.sh && bash scripts/e2e.sh`
Expected: `GATE GREEN`, exit 0

- [ ] **Step 7: Commit**

```bash
git add scripts/e2e.sh FEATURES.json PROGRESS.md
git commit -m "feat(M0-001): repo gate + FEATURES.json + PROGRESS.md"
```

---

### Task 2: Open-source hygiene (M0-002)

**Files:**
- Create: `LICENSE`
- Create: `.gitignore`
- Create: `README.md` (stub — Task 10 completes it)
- Modify: `AGENTS.md` (refresh state + map; keep ≤100 lines)
- Modify: `FEATURES.json` (append M0-002 passing)
- Modify: `PROGRESS.md`

**Interfaces:**
- Consumes: `scripts/e2e.sh` gate from Task 1.
- Produces: `README.md` with a `## Status` line Task 10 will replace.

- [ ] **Step 1: Add the failing gate check**

Append to `scripts/e2e.sh` above `echo "GATE GREEN"`:

```bash
# --- open-source hygiene --------------------------------------------------

[ -f LICENSE ] && grep -q "MIT License" LICENSE || fail "LICENSE missing or not MIT"
[ -f .gitignore ] || fail ".gitignore missing"
[ -f README.md ] || fail "README.md missing"
```

Run: `bash scripts/e2e.sh`
Expected: `GATE FAIL: LICENSE missing or not MIT`

- [ ] **Step 2: Write `LICENSE`** — standard MIT text, header lines:

```
MIT License

Copyright (c) 2026 Stefano Rifici
```

(then the canonical MIT permission/warranty paragraphs, unmodified)

- [ ] **Step 3: Write `.gitignore`**

```gitignore
.DS_Store
Thumbs.db
*.swp
*.swo
.idea/
.vscode/
.claude/settings.local.json
```

- [ ] **Step 4: Write `README.md` stub**

```markdown
# harness-planning

Plan applications with the long-running-agent harness approach — in-repo
FEATURES.json / PROGRESS.md / execution plans / e2e gate — as a Claude Code
skill plus a portable protocol usable by any AI agent.

Pillars: [Anthropic — Effective harnesses for long-running agents](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents)
· [OpenAI — Harness engineering](https://openai.com/index/harness-engineering/)

## Status

Under construction — see `FEATURES.json` and `PROGRESS.md`. This repo is
built with its own harness.

## License

MIT
```

- [ ] **Step 5: Refresh `AGENTS.md`**

Replace the "State" and "Next action" content (spec pointer stays):

```markdown
# AGENTS.md — harness-planning skill

Open-source Claude Code skill + portable protocol pack for planning
applications with the long-running-agent harness approach (in-repo
FEATURES.json / PROGRESS.md / plans / e2e gate), consumable by any AI agent.

## State: implementing (dogfooding its own harness)

1. Spec: `docs/specs/2026-07-03-harness-planning-skill-design.md`
2. Plan + backlog: `docs/plans/active/2026-07-03-harness-planning-skill-implementation.md`
3. Scope/status: `FEATURES.json` · Session log: `PROGRESS.md`
4. Gate: `bash scripts/e2e.sh` (exit 0 = green; run at session start and end)

## Session loop

Read `git log -20` + PROGRESS.md + the plan → take the next unchecked task →
gate green baseline → implement (gate check first) → gate green → append the
feature to FEATURES.json as passing in the same commit → PROGRESS.md entry.

## Rules

- Plans, decisions, and progress live in this repo. If it's not committed
  here, it doesn't exist for the next session.
- Keep this file a table of contents (≤100 lines); depth goes in `docs/`.
- Open-source hygiene: no personal paths, keys, or private project names in
  any committed file; templates use `{{placeholders}}` only.
- Local branches only for now — no remotes/PRs until the owner says so.
```

- [ ] **Step 6: Run the gate**

Run: `bash scripts/e2e.sh`
Expected: `GATE GREEN`

- [ ] **Step 7: Append M0-002 to `FEATURES.json`, update `PROGRESS.md`, commit**

New feature entry:

```json
{
  "id": "M0-002",
  "milestone": 0,
  "title": "Open-source hygiene: MIT LICENSE, .gitignore, README stub, AGENTS.md refresh",
  "status": "passing",
  "verify": "Gate checks LICENSE (MIT), .gitignore, README.md exist; AGENTS.md <= 100 lines; no personal paths tracked",
  "notes": ""
}
```

```bash
git add LICENSE .gitignore README.md AGENTS.md FEATURES.json PROGRESS.md scripts/e2e.sh
git commit -m "feat(M0-002): open-source hygiene (LICENSE, .gitignore, README stub)"
```

---

### Task 3: FEATURES.json.tmpl + PROGRESS.md.tmpl (M1-001)

**Files:**
- Create: `skill/harness-planning/templates/FEATURES.json.tmpl`
- Create: `skill/harness-planning/templates/PROGRESS.md.tmpl`
- Modify: `scripts/e2e.sh`, `FEATURES.json`, `PROGRESS.md`

**Interfaces:**
- Produces: `TMPL_DIR="skill/harness-planning/templates"` shell variable in the gate — later template tasks reuse it.
- Produces: placeholder convention `{{UPPER_SNAKE_CASE}}` — all templates use it; the gate substitutes with regex `{{[A-Za-z0-9_]*}}`.

- [ ] **Step 1: Add the failing gate check**

Append to `scripts/e2e.sh` above `echo "GATE GREEN"`:

```bash
# --- templates ------------------------------------------------------------

TMPL_DIR="skill/harness-planning/templates"

# FEATURES.json.tmpl: contains placeholders, valid JSON once they are substituted
grep -q '{{' "$TMPL_DIR/FEATURES.json.tmpl" \
  || fail "FEATURES.json.tmpl has no {{placeholders}}"
sed 's/{{[A-Za-z0-9_]*}}/X/g' "$TMPL_DIR/FEATURES.json.tmpl" | jq -e . >/dev/null \
  || fail "FEATURES.json.tmpl: not valid JSON after placeholder substitution"

[ -f "$TMPL_DIR/PROGRESS.md.tmpl" ] || fail "PROGRESS.md.tmpl missing"
grep -q '{{' "$TMPL_DIR/PROGRESS.md.tmpl" || fail "PROGRESS.md.tmpl has no {{placeholders}}"
```

Run: `bash scripts/e2e.sh` — Expected: `GATE FAIL` (template missing)

- [ ] **Step 2: Write `FEATURES.json.tmpl`**

Same `_instructions` string as this repo's FEATURES.json (spec §5 verbatim):

```json
{
  "_instructions": "Source of truth for the build. DO NOT delete, edit, or renumber existing ids/titles. Statuses: passing (done+proven), failing (actionable), deferred (postponed; notes say when actionable), superseded (dead, kept for history). Flip failing->passing only when a test or the stated manual check proves it. Append new features with the next id in their milestone. Work ONE feature per session: lowest milestone, then lowest id, among 'failing'.",
  "milestones": {
    "0": "{{MILESTONE_0_TITLE}}",
    "1": "{{MILESTONE_1_TITLE}}"
  },
  "features": [
    {
      "id": "M0-001",
      "milestone": 0,
      "title": "{{FIRST_FEATURE_TITLE}}",
      "status": "failing",
      "verify": "{{HOW_AN_AGENT_PROVES_THIS_FEATURE_WORKS}}",
      "notes": ""
    }
  ]
}
```

- [ ] **Step 3: Write `PROGRESS.md.tmpl`**

```markdown
# PROGRESS

Newest-first session log for {{PROJECT_NAME}}. One entry per working
session. Read this (plus `git log -20` and FEATURES.json) at the start of
every session; append an entry before ending one.

## {{DATE}} — session 1 (harness scaffolded)

- Branch: `{{BRANCH_NAME}}`
- Done: harness scaffolded (AGENTS.md, FEATURES.json, PROGRESS.md, scripts/, docs/).
- Gate: {{GATE_STATUS_GREEN_OR_WHY_NOT}}
- Next: M0-001 — {{FIRST_FEATURE_TITLE}}
```

- [ ] **Step 4: Run gate** — Expected: `GATE GREEN`

- [ ] **Step 5: Append M1-001 (passing) to FEATURES.json, PROGRESS.md entry, commit**

```json
{
  "id": "M1-001",
  "milestone": 1,
  "title": "FEATURES.json.tmpl + PROGRESS.md.tmpl",
  "status": "passing",
  "verify": "Gate: FEATURES.json.tmpl parses as JSON after {{placeholder}} substitution; both templates contain placeholders",
  "notes": ""
}
```

```bash
git add skill/harness-planning/templates/ scripts/e2e.sh FEATURES.json PROGRESS.md
git commit -m "feat(M1-001): FEATURES.json and PROGRESS.md templates"
```

---

### Task 4: AGENTS.md.tmpl + pointer.md.tmpl (M1-002)

**Files:**
- Create: `skill/harness-planning/templates/AGENTS.md.tmpl`
- Create: `skill/harness-planning/templates/pointer.md.tmpl`
- Modify: `scripts/e2e.sh`, `FEATURES.json`, `PROGRESS.md`

**Interfaces:**
- Consumes: `TMPL_DIR` gate variable (Task 3).
- Produces: `AGENTS.md.tmpl` referencing `docs/agents/harness-protocol.md` — the path where the skill copies the protocol doc into target repos (Tasks 6–9 depend on this exact path).

- [ ] **Step 1: Add the failing gate check** (above `echo "GATE GREEN"`):

```bash
# AGENTS.md.tmpl: map-not-encyclopedia, with adaptation headroom
[ -f "$TMPL_DIR/AGENTS.md.tmpl" ] || fail "AGENTS.md.tmpl missing"
[ "$(wc -l < "$TMPL_DIR/AGENTS.md.tmpl")" -le 80 ] || fail "AGENTS.md.tmpl exceeds 80 lines"
grep -q 'docs/agents/harness-protocol.md' "$TMPL_DIR/AGENTS.md.tmpl" \
  || fail "AGENTS.md.tmpl does not point at the protocol doc"

# pointer.md.tmpl: a pointer, nothing more
[ -f "$TMPL_DIR/pointer.md.tmpl" ] || fail "pointer.md.tmpl missing"
[ "$(wc -l < "$TMPL_DIR/pointer.md.tmpl")" -le 5 ] || fail "pointer.md.tmpl must stay a one-line pointer"
```

Run: `bash scripts/e2e.sh` — Expected: `GATE FAIL: AGENTS.md.tmpl missing`

- [ ] **Step 2: Write `AGENTS.md.tmpl`** (complete content):

```markdown
# AGENTS.md — {{PROJECT_NAME}}

{{ONE_PARAGRAPH_PROJECT_SUMMARY}}

This repository is operated with the long-running-agent harness. The full
operating manual is `docs/agents/harness-protocol.md` — read it before your
first session. This file is only the map.

## Map

- `docs/PRODUCT.md` — vision, users, UX concept, roadmap (the "why")
- `FEATURES.json` — source of truth for scope and status (read its `_instructions`)
- `PROGRESS.md` — newest-first session log; how a fresh session recovers context
- `docs/plans/active/` — execution plans in flight (decision logs live inside them)
- `docs/plans/completed/` — finished plans, kept for history
- `scripts/dev.sh` — boot the dev environment
- `scripts/e2e.sh` — the gate: tests + analyzers; exit 0 = green

## Session loop (summary — full version in the protocol doc)

1. Read `git log -20`, `PROGRESS.md`, and `FEATURES.json`.
2. Pick the feature to work on: lowest milestone, then lowest id, among
   `status: "failing"` (skip `deferred` and `superseded`).
3. Run `bash scripts/e2e.sh` — confirm a green baseline before touching code.
4. Implement that ONE feature, test-first.
5. Re-run the gate. Flip the feature to `"passing"` only when its own
   `verify` criterion proves it — never touch other entries.
6. Commit, then append an entry to `PROGRESS.md`.

## Rules

- The repo is the only interface: if it's not committed here, it doesn't
  exist for the next session.
- Never delete or renumber FEATURES.json entries; append only.
- Every session starts and ends green (`scripts/e2e.sh`).
- Branch off `{{DEFAULT_BRANCH}}`; one branch per milestone-chunk of work;
  integrate via pull request, not local fast-forward.
- Keep this file ≤100 lines; anything deeper goes in `docs/`.

{{PROJECT_SPECIFIC_SECTIONS}}
```

- [ ] **Step 3: Write `pointer.md.tmpl`**:

```markdown
See [AGENTS.md](AGENTS.md) — the single agent entry point for this repository.
```

- [ ] **Step 4: Run gate** — Expected: `GATE GREEN`

- [ ] **Step 5: Append M1-002 (passing), PROGRESS.md entry, commit**

```json
{
  "id": "M1-002",
  "milestone": 1,
  "title": "AGENTS.md.tmpl + pointer.md.tmpl",
  "status": "passing",
  "verify": "Gate: AGENTS.md.tmpl <= 80 lines and references docs/agents/harness-protocol.md; pointer.md.tmpl <= 5 lines",
  "notes": ""
}
```

```bash
git add skill/harness-planning/templates/ scripts/e2e.sh FEATURES.json PROGRESS.md
git commit -m "feat(M1-002): AGENTS.md and pointer templates"
```

---

### Task 5: dev.sh.tmpl + e2e.sh.tmpl (M1-003)

**Files:**
- Create: `skill/harness-planning/templates/dev.sh.tmpl`
- Create: `skill/harness-planning/templates/e2e.sh.tmpl`
- Modify: `scripts/e2e.sh`, `FEATURES.json`, `PROGRESS.md`

**Interfaces:**
- Consumes: `TMPL_DIR`, `{{UPPER_SNAKE_CASE}}` placeholder convention.
- Produces: script templates that pass shellcheck after placeholder substitution (placeholders sit on their own command lines so substitution yields runnable shell).

- [ ] **Step 1: Add the failing gate check** (above `echo "GATE GREEN"`):

```bash
# script templates: must be clean shell once placeholders are substituted
found_sh_tmpl=0
for t in "$TMPL_DIR"/*.sh.tmpl; do
  [ -e "$t" ] || continue
  found_sh_tmpl=1
  sub="$(mktemp)"
  sed 's/{{[A-Za-z0-9_]*}}/true/g' "$t" > "$sub"
  shellcheck -s bash "$sub" || fail "$(basename "$t") fails shellcheck after substitution"
  rm -f "$sub"
done
[ "$found_sh_tmpl" -eq 1 ] || fail "no *.sh.tmpl templates found"
```

Run: `bash scripts/e2e.sh` — Expected: `GATE FAIL: no *.sh.tmpl templates found`

- [ ] **Step 2: Write `dev.sh.tmpl`**:

```bash
#!/usr/bin/env bash
# Boots the dev environment for {{PROJECT_NAME}}.
# Adapt the placeholder line to your stack, e.g.:
#   npm:     npm install && npm run dev
#   flutter: flutter pub get && flutter run
#   python:  uv sync && uv run python -m {{PROJECT_NAME}}
set -euo pipefail
cd "$(dirname "$0")/.."

{{DEV_BOOT_COMMAND}}
```

- [ ] **Step 3: Write `e2e.sh.tmpl`**:

```bash
#!/usr/bin/env bash
# The gate for {{PROJECT_NAME}}: exit 0 = green.
# Run at the START of every session (confirm green baseline) and at the END
# (prove the feature). Keep it fast; keep it honest — a gate that lies is
# worse than no gate.
set -euo pipefail
cd "$(dirname "$0")/.."

# Tests (adapt to your stack, e.g. "npm test", "flutter test", "pytest")
{{TEST_COMMAND}}

# Static analysis / linters (e.g. "npm run lint", "dart analyze", "ruff check .")
{{ANALYZER_COMMAND}}

echo "GATE GREEN"
```

- [ ] **Step 4: Run gate** — Expected: `GATE GREEN`

- [ ] **Step 5: Append M1-003 (passing), PROGRESS.md entry, commit**

```json
{
  "id": "M1-003",
  "milestone": 1,
  "title": "dev.sh.tmpl + e2e.sh.tmpl script templates",
  "status": "passing",
  "verify": "Gate: every *.sh.tmpl passes shellcheck after {{placeholder}} substitution",
  "notes": ""
}
```

```bash
git add skill/harness-planning/templates/ scripts/e2e.sh FEATURES.json PROGRESS.md
git commit -m "feat(M1-003): dev.sh and e2e.sh script templates"
```

**End of milestone 1** — merge `m0-harness-scaffolding` into `master` locally is NOT done; keep working on the branch until the user decides integration (global constraint).

---

### Task 6: harness-protocol.md §1 — Planning protocol (M2-001)

**Files:**
- Create: `skill/harness-planning/templates/harness-protocol.md`
- Modify: `scripts/e2e.sh`, `FEATURES.json`, `PROGRESS.md`

**Interfaces:**
- Produces: `harness-protocol.md` with top-level heading structure `## 1. Planning protocol`, `## 2. Coding-session protocol`, `## 3. Maintenance protocol` (Tasks 7–8 append §2/§3; Task 9's SKILL.md references this file by path).
- Constraint: plain markdown, **zero Claude-isms** (no "Claude", no skill/tool names) — usable via Codex AGENTS.md, Cursor rules, or pasted into any chat model.

- [ ] **Step 1: Add the failing gate check** (above `echo "GATE GREEN"`):

```bash
# protocol doc: exists, has the planning section, no Claude-isms
PROTO="$TMPL_DIR/harness-protocol.md"
[ -f "$PROTO" ] || fail "harness-protocol.md missing"
grep -q '^## 1\. Planning protocol' "$PROTO" || fail "protocol: '## 1. Planning protocol' missing"
grep -q 'PRODUCT\.md' "$PROTO" || fail "protocol: planning section never mentions PRODUCT.md"
grep -qi 'verify' "$PROTO" || fail "protocol: planning section never teaches the verify field"
! grep -qi 'claude' "$PROTO" || fail "protocol doc must be agent-neutral (found 'claude')"
```

Run: `bash scripts/e2e.sh` — Expected: `GATE FAIL: harness-protocol.md missing`

- [ ] **Step 2: Write the file** — header + §1 complete; §2/§3 headings present as stubs so the doc's shape is stable (their gate checks land in Tasks 7–8):

Required structure and content of §1 (write full prose for each element; this is the checklist, not the text):

```markdown
# The Harness Protocol
(intro: what this is, the core principle "the repo is the only interface",
links to the two pillar articles, and the file layout diagram from spec §4)

## 1. Planning protocol
### 1.1 Interview the human
(the interview question list — REQUIRED questions, copy-paste ready:
 what is the product and who is it for? · what does v1 do end-to-end that
 makes it real? · what stack, and what already exists? · what is explicitly
 out of scope? · how will we run and test it locally? · what does "done"
 look like for the first milestone?)
### 1.2 Write docs/PRODUCT.md
(vision, users, UX concept, roadmap; the "why" that outlives any session)
### 1.3 Cut milestones
(each milestone = a coherent, demoable slice; milestone 0 is always the
harness itself)
### 1.4 Write FEATURES.json entries
(schema from FEATURES.json.tmpl; the verify field is the acceptance test.
 REQUIRED worked examples, verbatim:
 GOOD: "verify": "POST /login with wrong password returns 401 and no
 session cookie; test tests/auth_test.py::test_bad_password passes"
 BAD:  "verify": "login works correctly"
 Rule: refuse to add a feature you cannot state a falsifiable verify for.)
### 1.5 First execution plan
(write docs/plans/active/<date>-<milestone>.md with task list + decision log)
### 1.6 Scaffold or adapt the gate
(copy e2e.sh.tmpl / dev.sh.tmpl, adapt commands, run it, commit everything;
 the planning phase ends with a green gate and a first commit)

## 2. Coding-session protocol
(placeholder sentence: "Completed in the next revision." — replaced by Task 7)

## 3. Maintenance protocol
(placeholder sentence — replaced by Task 8)
```

- [ ] **Step 3: Run gate** — Expected: `GATE GREEN`

- [ ] **Step 4: Append M2-001 (passing), PROGRESS.md entry, commit**

```json
{
  "id": "M2-001",
  "milestone": 2,
  "title": "harness-protocol.md: planning protocol section",
  "status": "passing",
  "verify": "Gate: doc exists with '## 1. Planning protocol', mentions PRODUCT.md and verify, contains no 'claude' string",
  "notes": "Sections 2 and 3 are stubs until M2-002/M2-003."
}
```

```bash
git add skill/harness-planning/templates/harness-protocol.md scripts/e2e.sh FEATURES.json PROGRESS.md
git commit -m "feat(M2-001): protocol doc with planning section"
```

---

### Task 7: harness-protocol.md §2 — Coding-session protocol (M2-002)

**Files:**
- Modify: `skill/harness-planning/templates/harness-protocol.md`
- Modify: `scripts/e2e.sh`, `FEATURES.json`, `PROGRESS.md`

- [ ] **Step 1: Add the failing gate check**:

```bash
grep -q '^## 2\. Coding-session protocol' "$PROTO" || fail "protocol: coding-session section missing"
grep -q 'git log -20' "$PROTO" || fail "protocol: session loop must start from git log -20"
grep -q 'ONE feature' "$PROTO" || fail "protocol: one-feature-per-session rule missing"
```

Run: `bash scripts/e2e.sh` — Expected: FAIL (stub section has no `git log -20`)

- [ ] **Step 2: Replace the §2 stub with the full section.** Required content (write full prose; spec §6.2 is the source):

- Context recovery: read `git log -20`, `PROGRESS.md`, `FEATURES.json` — in that order, before anything else.
- Feature selection: lowest milestone, then lowest id, among `failing`; skip `deferred`/`superseded`; work exactly ONE feature per session.
- Green baseline: run the gate before touching code; if red, fixing the gate IS the session.
- Implement test-first: write the check that proves `verify`, watch it fail, implement, watch it pass.
- Close out: re-run gate → flip status (only your feature, only when `verify` proves it) → commit → append PROGRESS.md entry (branch, what was done, gate status, next feature).
- Branch discipline: branch off the default branch, one branch per milestone-chunk, no branch-of-a-branch, integrate via PR, small focused commits, stage explicit paths.
- A copy-paste session prompt block the human can hand any agent:
  ```
  Read AGENTS.md, then docs/agents/harness-protocol.md section 2, and
  perform exactly one coding session.
  ```

- [ ] **Step 3: Run gate** — Expected: `GATE GREEN`

- [ ] **Step 4: Append M2-002 (passing), PROGRESS.md entry, commit**

```json
{
  "id": "M2-002",
  "milestone": 2,
  "title": "harness-protocol.md: coding-session protocol section",
  "status": "passing",
  "verify": "Gate: '## 2. Coding-session protocol' present with 'git log -20' and 'ONE feature' rules",
  "notes": ""
}
```

```bash
git add skill/harness-planning/templates/harness-protocol.md scripts/e2e.sh FEATURES.json PROGRESS.md
git commit -m "feat(M2-002): protocol coding-session section"
```

---

### Task 8: harness-protocol.md §3 — Maintenance protocol (M2-003)

**Files:**
- Modify: `skill/harness-planning/templates/harness-protocol.md`
- Modify: `scripts/e2e.sh`, `FEATURES.json`, `PROGRESS.md`

- [ ] **Step 1: Add the failing gate check**:

```bash
grep -q '^## 3\. Maintenance protocol' "$PROTO" || fail "protocol: maintenance section missing"
grep -qi 'entropy' "$PROTO" || fail "protocol: maintenance section must cover entropy GC"
```

Run: `bash scripts/e2e.sh` — Expected: FAIL

- [ ] **Step 2: Replace the §3 stub with the full section.** Required content (from spec §6.3, OpenAI pillar):

- Cadence-based entropy GC: scan for drift from the repo's documented conventions; fix in small, focused cleanup PRs — never big-bang rewrites.
- Doc gardening: AGENTS.md stays ≤100 lines; stale docs updated or deleted; completed plans moved `active/` → `completed/`.
- FEATURES.json gardening: mark dead features `superseded` (never delete); revisit `deferred` notes.
- "What's missing?" rule: when a session fails, the fix is usually a missing tool, guardrail, or doc — feed it back into the repo.
- A copy-paste maintenance prompt block, same style as §2's.

- [ ] **Step 3: Run gate** — Expected: `GATE GREEN`

- [ ] **Step 4: Append M2-003 (passing), PROGRESS.md entry, commit**

```json
{
  "id": "M2-003",
  "milestone": 2,
  "title": "harness-protocol.md: maintenance protocol section",
  "status": "passing",
  "verify": "Gate: '## 3. Maintenance protocol' present and covers entropy GC",
  "notes": ""
}
```

```bash
git add skill/harness-planning/templates/harness-protocol.md scripts/e2e.sh FEATURES.json PROGRESS.md
git commit -m "feat(M2-003): protocol maintenance section"
```

---

### Task 9: SKILL.md (M3-001)

**Files:**
- Create: `skill/harness-planning/SKILL.md`
- Modify: `scripts/e2e.sh`, `FEATURES.json`, `PROGRESS.md`

**Interfaces:**
- Consumes: every template from Tasks 3–8 (SKILL.md references them by relative path `templates/<name>`).
- Constraint: SKILL.md is **thin orchestration** — all substance stays in the templates; the skill's core instruction is "copy and adapt templates; never improvise the schema".

- [ ] **Step 1: Add the failing gate check**:

```bash
# SKILL.md: valid frontmatter, references only templates that exist
SKILL="skill/harness-planning/SKILL.md"
[ -f "$SKILL" ] || fail "SKILL.md missing"
[ "$(head -1 "$SKILL")" = "---" ] || fail "SKILL.md: missing frontmatter"
grep -q '^name: harness-planning$' "$SKILL" || fail "SKILL.md: frontmatter name wrong"
grep -q '^description: ' "$SKILL" || fail "SKILL.md: frontmatter description missing"
while read -r ref; do
  [ -f "skill/harness-planning/$ref" ] || fail "SKILL.md references missing file: $ref"
done < <(grep -o 'templates/[A-Za-z0-9._-]*' "$SKILL" | sort -u)
```

Run: `bash scripts/e2e.sh` — Expected: `GATE FAIL: SKILL.md missing`

- [ ] **Step 2: Write `SKILL.md`.** Required structure:

```markdown
---
name: harness-planning
description: Use when planning a new application or feature-set, or when a
  repo needs a durable agent-operable structure — scaffolds the long-running-
  agent harness (AGENTS.md, FEATURES.json, PROGRESS.md, plans, e2e gate) so
  any agent can plan and build one feature per session.
---
(workflow:
 1. Detect mode: greenfield (empty/near-empty dir) vs retrofit (existing code).
 2. Read templates/harness-protocol.md §1 and RUN it — the skill follows its
    own shipped manual; never improvise the schema.
 3. Scaffold by COPYING templates and substituting {{placeholders}}:
    AGENTS.md.tmpl → AGENTS.md · pointer.md.tmpl → CLAUDE.md (and GEMINI.md
    if asked) · FEATURES.json.tmpl → FEATURES.json · PROGRESS.md.tmpl →
    PROGRESS.md · dev.sh.tmpl → scripts/dev.sh · e2e.sh.tmpl →
    scripts/e2e.sh · harness-protocol.md → docs/agents/harness-protocol.md
    (copied whole, not generated)
 4. Retrofit rules: existing AGENTS.md/CLAUDE.md content preserved and
    linked, never clobbered; existing tests become the initial gate;
    existing code maps to passing features ONLY when a verify criterion
    actually proves it — otherwise it enters as failing with honest notes.
 5. Verify: bash scripts/e2e.sh must exit 0; then make the first commit.
 red-flags table — rows, verbatim:
 | "I'll just write FEATURES.json from memory" | Copy the template. The schema is not yours to improvise. |
 | "This feature is obviously done, I'll mark it passing" | Only a verify criterion flips a status. |
 | "The verify field can just say 'works correctly'" | Unfalsifiable. Write the test or the manual check. |
 | "I'll put the plan in my head / a gist / chat" | If it's not in the repo, it doesn't exist. |
 | "Existing AGENTS.md is messy, I'll rewrite it" | Retrofit extends and links; it never clobbers. |)
```

- [ ] **Step 3: Run gate** — Expected: `GATE GREEN`

- [ ] **Step 4: Append M3-001 (passing), PROGRESS.md entry, commit**

```json
{
  "id": "M3-001",
  "milestone": 3,
  "title": "SKILL.md thin orchestration layer",
  "status": "passing",
  "verify": "Gate: frontmatter valid (name harness-planning, description present); every templates/ path referenced in SKILL.md exists",
  "notes": ""
}
```

```bash
git add skill/harness-planning/SKILL.md scripts/e2e.sh FEATURES.json PROGRESS.md
git commit -m "feat(M3-001): SKILL.md orchestration layer"
```

---

### Task 10: Full README (M4-001)

**Files:**
- Modify: `README.md`, `scripts/e2e.sh`, `FEATURES.json`, `PROGRESS.md`

- [ ] **Step 1: Add the failing gate check**:

```bash
# README: both quickstarts present
grep -q '~/.claude/skills' README.md || fail "README: Claude install quickstart missing"
grep -q 'harness-protocol.md' README.md || fail "README: non-Claude quickstart missing"
```

Run: `bash scripts/e2e.sh` — Expected: FAIL

- [ ] **Step 2: Complete `README.md`.** Required sections (spec §9): what the harness approach is (link both pillars); **Quickstart — Claude Code users**: copy/symlink `skill/harness-planning/` into `~/.claude/skills/harness-planning`; **Quickstart — any other agent**: point your agent at `skill/harness-planning/templates/harness-protocol.md` ("read this and run section 1"); repository layout; dogfood note ("this repo is built with its own harness — see FEATURES.json / PROGRESS.md"); license (MIT). Replace the stub's "Status: under construction" section.

- [ ] **Step 3: Run gate** — Expected: `GATE GREEN`

- [ ] **Step 4: Append M4-001 (passing), PROGRESS.md entry, commit**

```json
{
  "id": "M4-001",
  "milestone": 4,
  "title": "Full README with both quickstarts",
  "status": "passing",
  "verify": "Gate: README mentions ~/.claude/skills install and harness-protocol.md pointer",
  "notes": ""
}
```

```bash
git add README.md scripts/e2e.sh FEATURES.json PROGRESS.md
git commit -m "feat(M4-001): full README"
```

---

### Task 11: Acceptance test (M4-002) — the spec §6 bar

**Files:**
- Create: sandbox OUTSIDE the repo (scratchpad dir) — nothing sandbox-related is committed
- Modify: `FEATURES.json`, `PROGRESS.md` (result recorded in notes)

This is the spec's acceptance test: *"hand a scaffolded repo to a non-Claude agent whose only instruction is 'read AGENTS.md and do one session' — it must complete a correct one-feature session."* We approximate "non-Claude" with a fresh subagent that receives ONLY that instruction (no skill, no spec, no conversation context).

- [ ] **Step 1: Scaffold a sandbox by hand from the templates** — in the scratchpad, create a tiny fake project (e.g. a bash utility with one function), `git init`, copy/substitute every template exactly as SKILL.md step 3 prescribes, add 2–3 FEATURES.json entries with real `verify` criteria (one `passing`, two `failing`), working `scripts/e2e.sh` (e.g. runs a bats/bash test file), commit.

- [ ] **Step 2: Verify the sandbox gate is green**: `bash scripts/e2e.sh` in the sandbox → exit 0.

- [ ] **Step 3: Dispatch a fresh general-purpose subagent** with exactly this prompt (plus the sandbox path):

```
You are working in <sandbox path>. Read AGENTS.md and perform one session.
```

- [ ] **Step 4: Grade the result against the four criteria** (all must hold):
  1. It picked the correct feature (lowest milestone, lowest id, `failing`).
  2. It ran the gate before and after.
  3. It flipped only that feature's status, and only with `verify` satisfied.
  4. It appended a PROGRESS.md entry.

If any criterion fails: the fix is a template/protocol wording change (what was ambiguous?), not a re-roll. Apply it, re-run the test, and log the change in this plan's Decision log.

- [ ] **Step 5: Append M4-002 to FEATURES.json, record the outcome, commit**

```json
{
  "id": "M4-002",
  "milestone": 4,
  "title": "Acceptance test: context-free agent completes a correct one-feature session",
  "status": "passing",
  "verify": "Manual: fresh subagent given only 'read AGENTS.md and do one session' in a template-scaffolded sandbox meets all 4 criteria (right feature, gate ran, legal flip, PROGRESS.md entry)",
  "notes": "Outcome + any template fixes recorded in the plan's decision log."
}
```

```bash
git add FEATURES.json PROGRESS.md
git commit -m "feat(M4-002): acceptance test passed by context-free agent"
```

- [ ] **Step 6: Close out the plan** — move this file to `docs/plans/completed/`, update AGENTS.md state line, commit. Integration into `master` waits for the user's go-ahead (local-only constraint).

---

## Decision log

- 2026-07-03 — Work stays on local branches; no GitHub remote/PRs until the owner says so (owner instruction).
- 2026-07-03 — Per the owner's harness rules, FEATURES.json entries are appended in the commit that proves them passing; the full backlog lives in this plan, not as pre-committed `failing` entries.
- 2026-07-03 — Template AGENTS.md budget set at 80 lines (below the 100 cap) to leave adaptation headroom for target repos.
- 2026-07-03 — `PRODUCT.md.tmpl` deliberately not shipped: spec §7's template list omits it; PRODUCT.md content is project-specific and produced by the protocol's interview (§1.2). YAGNI.
