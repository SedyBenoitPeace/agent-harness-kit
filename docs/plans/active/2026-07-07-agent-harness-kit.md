# agent-harness-kit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn this repo into the canonical **agent-harness-kit** Claude Code plugin: rename repo (GitHub-only), restructure `skill/` → `skills/harness-setup`, add plugin manifests, add a `harness-audit` skill with a deterministic checker + fixture tests, and document PRD input.

**Architecture:** The repo root becomes the plugin root (`.claude-plugin/` manifests + `skills/`). The existing gate (`scripts/e2e.sh`) stays the single test entry point; every new invariant is enforced there (TDD: add the gate check RED, make it GREEN). The audit is two layers: deterministic `check.sh` (repeatable, CI-usable) + a thin SKILL.md judgment layer.

**Tech Stack:** bash + jq + shellcheck (same as existing gate), Claude Code plugin manifests (plugin.json / marketplace.json), gh CLI.

**Spec:** `docs/specs/2026-07-07-agent-harness-kit-plugin-design.md`

## Global Constraints

- **NEVER rename the local working directory** — it stays `harness-planning-skill` on disk (conversation history is keyed by path). Only GitHub and `origin` change.
- Protocol doc (`harness-protocol.md`) must stay agent-neutral: the gate fails on any case-insensitive `claude` inside it.
- `AGENTS.md` ≤ 100 lines; `AGENTS.md.tmpl` ≤ 80; `pointer.md.tmpl` ≤ 5.
- Templates use `{{PLACEHOLDER}}` syntax only; no personal paths (`/Users/...`, `/home/...`) in any tracked file.
- FEATURES.json: never delete/renumber entries; new entries land **in the same commit** that proves them passing. Legal statuses: `failing`, `passing`, `deferred`, `superseded` (all four — the spec's shorter list is superseded by the repo schema; see decision log).
- Stage explicit paths (no `git add -A`). One branch per milestone off `master`; integrate via PR; **the owner merges PRs** — pause at each PR checkpoint.
- Plugin name/version everywhere: `agent-harness-kit` / `1.0.0`.
- Gate must print `GATE GREEN` (exit 0) at every commit point.

---

### Task 1: Rename the GitHub repo (no commit)

**Files:** none (GitHub admin operation)

**Interfaces:**
- Produces: remote `SedyBenoitPeace/agent-harness-kit`; all later tasks use this URL in file content.

- [ ] **Step 1: Confirm current remote**

Run: `git remote get-url origin`
Expected: `https://github.com/SedyBenoitPeace/harness-planning-skill.git`

- [ ] **Step 2: Rename on GitHub**

```bash
gh repo rename agent-harness-kit --repo SedyBenoitPeace/harness-planning-skill --yes
```

`gh` updates the local `origin` URL automatically when run inside the repo. GitHub redirects the old URL and old remotes keep working.

- [ ] **Step 3: Verify**

Run: `gh repo view SedyBenoitPeace/agent-harness-kit --json name -q .name && git remote get-url origin`
Expected: `agent-harness-kit` and an origin URL ending `agent-harness-kit.git`.
Do **not** rename the local directory.

### Task 2: PR the docs (spec + this plan)

**Files:**
- Already committed on branch `agent-harness-kit-spec`: `docs/specs/2026-07-07-agent-harness-kit-plugin-design.md`
- Commit on same branch: `docs/plans/active/2026-07-07-agent-harness-kit.md` (this file)

- [ ] **Step 1: Commit the plan on `agent-harness-kit-spec`**

```bash
git add docs/plans/active/2026-07-07-agent-harness-kit.md
git commit -m "docs: implementation plan for agent-harness-kit (M7-M9)"
```

- [ ] **Step 2: Push and open PR**

```bash
git push -u origin agent-harness-kit-spec
gh pr create --title "docs: agent-harness-kit spec + implementation plan" \
  --body "Design spec and M7–M9 implementation plan for plugin packaging, harness-audit, and PRD input. Docs only.

🤖 Generated with [Claude Code](https://claude.com/claude-code)"
```

- [ ] **Step 3: CHECKPOINT — owner merges PR, then:**

```bash
git checkout master && git pull
```

### Task 3 (M7): Restructure to `skills/harness-setup` — gate-first

**Files:**
- Modify: `scripts/e2e.sh:2,46,95,98,101`
- Rename: `skill/harness-planning/` → `skills/harness-setup/` (whole tree)
- Modify: `skills/harness-setup/SKILL.md:2,13`

**Interfaces:**
- Produces: template dir `skills/harness-setup/templates/` and skill name `harness-setup` — used by Tasks 4–9.

- [ ] **Step 1: Branch**

```bash
git checkout -b m7-plugin master
```

- [ ] **Step 2 (RED): Point the gate at the new paths**

In `scripts/e2e.sh` change exactly these lines:

```bash
# line 2 (comment):
# Gate for the agent-harness-kit repo. Exit 0 = green.
# line 46:
TMPL_DIR="skills/harness-setup/templates"
# line 95:
SKILL="skills/harness-setup/SKILL.md"
# line 98:
grep -q '^name: harness-setup$' "$SKILL" || fail "SKILL.md: frontmatter name wrong"
# line 101 (inside the while loop):
  [ -f "skills/harness-setup/$ref" ] || fail "SKILL.md references missing file: $ref"
```

- [ ] **Step 3: Run gate to verify it fails**

Run: `bash scripts/e2e.sh`
Expected: FAIL (template checks can't find `skills/harness-setup/...`).

- [ ] **Step 4 (GREEN): Move the tree and rename the skill**

```bash
git mv skill skills
git mv skills/harness-planning skills/harness-setup
```

In `skills/harness-setup/SKILL.md`:
- line 2: `name: harness-setup`
- line 13: `**Announce at start:** "Using harness-setup to set up the agent harness."`

- [ ] **Step 5: Run gate to verify it passes**

Run: `bash scripts/e2e.sh`
Expected: `GATE GREEN`

- [ ] **Step 6: Commit**

```bash
git add scripts/e2e.sh skills skill
git commit -m "feat(M7): restructure skill/ -> skills/harness-setup for plugin layout"
```

(Note: `git add skill` stages the deletions recorded by `git mv`; FEATURES.json entry for M7-001 lands in Task 6 with the rename proof.)

### Task 4 (M7): Plugin manifests — gate-first

**Files:**
- Modify: `scripts/e2e.sh` (append new section after the `--- open-source hygiene ---` block)
- Create: `.claude-plugin/plugin.json`
- Create: `.claude-plugin/marketplace.json`

**Interfaces:**
- Produces: plugin/marketplace name `agent-harness-kit`, `source: "./"` — README (Task 5) and install validation (Task 10) depend on these names.

- [ ] **Step 1 (RED): Add gate checks**

Append to `scripts/e2e.sh` directly after the open-source hygiene block (after the `[ -f README.md ]` line):

```bash
# --- plugin packaging -------------------------------------------------------

jq -e '.name == "agent-harness-kit" and (.version | type == "string")' \
  .claude-plugin/plugin.json >/dev/null 2>&1 \
  || fail "plugin.json missing, invalid, or wrong name"
jq -e '.plugins[0].name == "agent-harness-kit" and .plugins[0].source == "./"' \
  .claude-plugin/marketplace.json >/dev/null 2>&1 \
  || fail "marketplace.json missing, invalid, or wrong plugin entry"
```

Run: `bash scripts/e2e.sh` — Expected: `GATE FAIL: plugin.json missing...`

- [ ] **Step 2 (GREEN): Create `.claude-plugin/plugin.json`**

```json
{
  "name": "agent-harness-kit",
  "description": "Full long-running-agent harness toolkit: scaffold FEATURES.json / PROGRESS.md / plans / e2e gate into any repo, and audit repos for harness-readiness.",
  "version": "1.0.0",
  "author": { "name": "Stefano Rifici" },
  "homepage": "https://github.com/SedyBenoitPeace/agent-harness-kit",
  "repository": "https://github.com/SedyBenoitPeace/agent-harness-kit",
  "license": "MIT",
  "keywords": ["harness", "planning", "agents", "scaffolding", "audit"]
}
```

- [ ] **Step 3: Create `.claude-plugin/marketplace.json`**

```json
{
  "$schema": "https://anthropic.com/claude-code/marketplace.schema.json",
  "name": "agent-harness-kit",
  "description": "Long-running-agent harness toolkit",
  "owner": { "name": "Stefano Rifici" },
  "plugins": [
    {
      "name": "agent-harness-kit",
      "source": "./",
      "description": "Scaffold and audit the long-running-agent harness",
      "version": "1.0.0",
      "category": "productivity"
    }
  ]
}
```

- [ ] **Step 4: Run gate to verify it passes**

Run: `bash scripts/e2e.sh` — Expected: `GATE GREEN`

- [ ] **Step 5: Commit**

```bash
git add scripts/e2e.sh .claude-plugin
git commit -m "feat(M7): plugin.json + marketplace.json (repo doubles as its own marketplace)"
```

### Task 5 (M7): README + AGENTS.md for the new identity — gate-first

**Files:**
- Modify: `scripts/e2e.sh` (README section, ~line 105)
- Modify: `README.md` (title, quickstarts, layout diagram)
- Modify: `AGENTS.md` (title, deliverables line, state line)

- [ ] **Step 1 (RED): Add gate check for the plugin quickstart**

In `scripts/e2e.sh`, README section becomes:

```bash
# README: all three quickstarts present
grep -q '/plugin marketplace add' README.md || fail "README: plugin install quickstart missing"
grep -q '\.claude/skills' README.md || fail "README: manual copy fallback missing"
grep -q 'harness-protocol.md' README.md || fail "README: non-Claude quickstart missing"
```

Run: `bash scripts/e2e.sh` — Expected: `GATE FAIL: README: plugin install quickstart missing`

- [ ] **Step 2 (GREEN): Update README.md**

- Line 1: `# agent-harness-kit`
- Lines 3–5 (intro) become:

```markdown
Full long-running-agent harness toolkit — scaffold in-repo
FEATURES.json / PROGRESS.md / execution plans / e2e gate into any project,
and audit repos for harness-readiness. Ships as a Claude Code plugin plus a
portable protocol usable by any AI agent.
```

- Replace the whole "Quickstart — Claude Code users" section with:

````markdown
## Quickstart — Claude Code (plugin, recommended)

```
/plugin marketplace add SedyBenoitPeace/agent-harness-kit
/plugin install agent-harness-kit
```

Two skills come with it:

- **harness-setup** — interview → PRODUCT.md + FEATURES.json → scaffold the
  whole harness. Say *"set up the agent harness in this repo"*.
- **harness-audit** — check any repo's harness-readiness. Say *"audit this
  repo's harness"*.

Manual fallback (no plugin): copy `skills/harness-setup` into
`~/.claude/skills/`.
````

- Update the "Repository layout" diagram to:

````markdown
```
.claude-plugin/         plugin + marketplace manifests
skills/
├── harness-setup/
│   ├── SKILL.md        planning/scaffolding orchestration (thin)
│   └── templates/
│       ├── harness-protocol.md   ★ the agent-neutral operating manual
│       ├── AGENTS.md.tmpl        entry point scaffold (≤100-line map)
│       ├── FEATURES.json.tmpl    scope/status source of truth
│       ├── PROGRESS.md.tmpl      session log
│       ├── dev.sh.tmpl           dev-environment boot
│       ├── e2e.sh.tmpl           the gate
│       └── pointer.md.tmpl       one-line CLAUDE.md/GEMINI.md pointer
└── harness-audit/
    ├── SKILL.md        audit orchestration: report + offer fixes
    └── scripts/check.sh          deterministic readiness checker
```
````

- In the remaining sections, update every `skill/harness-planning/` path to
  `skills/harness-setup/` and every "harness-planning" name to
  "agent-harness-kit" (the template-repo section keeps its link; GitHub
  redirects handle the old repo name).

- [ ] **Step 3: Update AGENTS.md**

- Line 1: `# AGENTS.md — agent-harness-kit`
- Line 7 (state): `## State: v1 complete; v2 in flight (M7 plugin, M8 audit, M9 PRD input)`
- Line 13 (deliverables): `5. Deliverables: `.claude-plugin/` (manifests), `skills/harness-setup/`, `skills/harness-audit/`, README.`
- Line 29 (rules): delete the line `- Local branches only for now — no remotes/PRs until the owner says so.` (obsolete since PRs #1–#2) and replace with `- Integrate via PR; the owner merges.`

- [ ] **Step 4: Run gate**

Run: `bash scripts/e2e.sh` — Expected: `GATE GREEN` (AGENTS.md still ≤100 lines)

- [ ] **Step 5: Commit**

```bash
git add scripts/e2e.sh README.md AGENTS.md
git commit -m "feat(M7): README + AGENTS.md for agent-harness-kit plugin identity"
```

### Task 6 (M7): Close out M7 — FEATURES.json + PROGRESS.md + PR

**Files:**
- Modify: `FEATURES.json` (add milestone 7 + two entries)
- Modify: `PROGRESS.md` (new top entry)

- [ ] **Step 1: Append to FEATURES.json**

Add to `milestones`: `"7": "Plugin packaging (agent-harness-kit)"`.
Append to `features`:

```json
{
  "id": "M7-001",
  "milestone": 7,
  "title": "Repo renamed to agent-harness-kit; skill/ -> skills/harness-setup restructure",
  "status": "passing",
  "verify": "gh repo view SedyBenoitPeace/agent-harness-kit --json name -q .name prints agent-harness-kit; bash scripts/e2e.sh exits 0 with skills/harness-setup paths and 'name: harness-setup' frontmatter check",
  "notes": "Local working directory intentionally NOT renamed (session history is keyed by path); only GitHub + origin changed."
},
{
  "id": "M7-002",
  "milestone": 7,
  "title": "Plugin packaging: plugin.json + marketplace.json + README install story",
  "status": "passing",
  "verify": "Gate: both manifests parse with name agent-harness-kit and source ./; README contains '/plugin marketplace add'. Manual (Task 10): local marketplace add + plugin install exposes harness-setup",
  "notes": ""
}
```

- [ ] **Step 2: Add PROGRESS.md entry at the top**

```markdown
## 2026-07-07 — session 4

- Branch: `m7-plugin` (PR); repo renamed on GitHub to agent-harness-kit
  (local dir intentionally unchanged).
- Done: M7-001 — skills/harness-setup restructure, gate re-pointed.
- Done: M7-002 — .claude-plugin manifests; README plugin quickstart.
- Gate: green.
- Next: M8-001 — harness-audit checker + fixture tests.
```

- [ ] **Step 3: Gate, commit, PR**

```bash
bash scripts/e2e.sh
git add FEATURES.json PROGRESS.md
git commit -m "feat(M7-001,M7-002): record plugin packaging milestone as passing"
git push -u origin m7-plugin
gh pr create --title "M7: agent-harness-kit plugin packaging" --body "Repo rename fallout, skills/harness-setup restructure, plugin + marketplace manifests, README install story. Gate green.

🤖 Generated with [Claude Code](https://claude.com/claude-code)"
```

- [ ] **Step 4: CHECKPOINT — owner merges; then `git checkout master && git pull`**

### Task 7 (M8): Fixture tests for the audit checker (RED)

**Files:**
- Create: `scripts/test-audit.sh` (executable)
- Modify: `scripts/e2e.sh` (append harness-audit section)

**Interfaces:**
- Consumes: templates at `skills/harness-setup/templates/` (Task 3).
- Produces: contract for `skills/harness-audit/scripts/check.sh` (Task 8): args `[--run-gate] [TARGET_DIR]`; one `PASS  `/`FAIL  `/`WARN  ` line per check; final verdict line `HARNESS READY` or `NOT HARNESS READY: N failing check(s)`; exit 0 iff no FAIL.

- [ ] **Step 1: Branch**

```bash
git checkout -b m8-audit master
```

- [ ] **Step 2: Write `scripts/test-audit.sh`**

```bash
#!/usr/bin/env bash
# Fixture tests for skills/harness-audit/scripts/check.sh.
# Builds a harnessed repo from the shipped templates, then breaks it one
# defect at a time and asserts the checker catches each one.
set -euo pipefail
cd "$(dirname "$0")/.."

CHECK="skills/harness-audit/scripts/check.sh"
TMPL="skills/harness-setup/templates"

fail() { echo "AUDIT-TEST FAIL: $*" >&2; exit 1; }

make_fixture() {  # $1 = destination dir
  local d="$1"
  mkdir -p "$d/scripts" "$d/docs/plans/active" "$d/docs/plans/completed" "$d/docs/agents"
  sed 's/{{[A-Za-z0-9_]*}}/X/g'    "$TMPL/AGENTS.md.tmpl"     > "$d/AGENTS.md"
  sed 's/{{[A-Za-z0-9_]*}}/X/g'    "$TMPL/FEATURES.json.tmpl" > "$d/FEATURES.json"
  sed 's/{{[A-Za-z0-9_]*}}/X/g'    "$TMPL/PROGRESS.md.tmpl"   > "$d/PROGRESS.md"
  sed 's/{{[A-Za-z0-9_]*}}/true/g' "$TMPL/e2e.sh.tmpl"        > "$d/scripts/e2e.sh"
  chmod +x "$d/scripts/e2e.sh"
  cp "$TMPL/harness-protocol.md" "$d/docs/agents/harness-protocol.md"
  cp "$TMPL/pointer.md.tmpl" "$d/CLAUDE.md"
}

expect_fail() {  # $1 = fixture dir, $2 = expected FAIL pattern, $3 = label
  local out
  if out="$(bash "$CHECK" "$1")"; then
    fail "$3: checker exited 0, expected failure"
  fi
  echo "$out" | grep -q "^FAIL.*$2" || fail "$3: missing expected FAIL line ($2)"
  echo "$out" | grep -q "NOT HARNESS READY" || fail "$3: missing NOT HARNESS READY verdict"
}

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# 1. good fixture: exit 0, READY verdict, zero FAIL lines
make_fixture "$WORK/good"
out="$(bash "$CHECK" "$WORK/good")" || fail "good fixture: checker exited non-zero"
echo "$out" | grep -q "HARNESS READY" || fail "good fixture: no HARNESS READY verdict"
if echo "$out" | grep -q "^FAIL"; then fail "good fixture: unexpected FAIL line"; fi

# 2. drifted protocol doc: WARN, still exit 0
make_fixture "$WORK/drift"
echo "local note" >> "$WORK/drift/docs/agents/harness-protocol.md"
out="$(bash "$CHECK" "$WORK/drift")" || fail "drifted protocol must not fail the audit"
echo "$out" | grep -q "^WARN.*differs" || fail "drifted protocol: expected WARN line"

# 3. defect fixtures: each must FAIL with its specific line
make_fixture "$WORK/big-agents"
for _ in $(seq 1 101); do echo "filler line" >> "$WORK/big-agents/AGENTS.md"; done
expect_fail "$WORK/big-agents" "AGENTS.md exceeds" "oversized AGENTS.md"

make_fixture "$WORK/empty-verify"
jq '.features[0].verify = ""' "$WORK/empty-verify/FEATURES.json" > "$WORK/empty-verify/F.tmp"
mv "$WORK/empty-verify/F.tmp" "$WORK/empty-verify/FEATURES.json"
expect_fail "$WORK/empty-verify" "id/milestone/verify" "empty verify"

make_fixture "$WORK/no-gate"
rm "$WORK/no-gate/scripts/e2e.sh"
expect_fail "$WORK/no-gate" "scripts/e2e.sh missing" "missing gate"

make_fixture "$WORK/no-plans"
rmdir "$WORK/no-plans/docs/plans/active"
expect_fail "$WORK/no-plans" "docs/plans" "missing plans dir"

make_fixture "$WORK/no-proto"
rm "$WORK/no-proto/docs/agents/harness-protocol.md"
expect_fail "$WORK/no-proto" "harness-protocol.md missing" "missing protocol doc"

echo "AUDIT TESTS GREEN"
```

```bash
chmod +x scripts/test-audit.sh
```

- [ ] **Step 3: Wire into the gate**

Append to `scripts/e2e.sh` (after the README section, before the final echo):

```bash
# --- harness-audit skill ----------------------------------------------------

AUDIT="skills/harness-audit"
[ -f "$AUDIT/scripts/check.sh" ] || fail "harness-audit check.sh missing"
shellcheck "$AUDIT/scripts/check.sh"
bash scripts/test-audit.sh
```

(SKILL.md gate checks are added in Task 9's own RED→GREEN cycle, so every commit stays green.)

- [ ] **Step 4: Run gate to verify it fails (RED)**

Run: `bash scripts/e2e.sh`
Expected: `GATE FAIL: harness-audit check.sh missing`

Do **not** commit yet — the gate is red. The test and the checker land together in Task 8's commit.

### Task 8 (M8): The deterministic checker (GREEN)

**Files:**
- Create: `skills/harness-audit/scripts/check.sh` (executable)

**Interfaces:**
- Consumes: shipped protocol at `../../harness-setup/templates/harness-protocol.md` relative to its own location.
- Produces: the exact CLI contract defined in Task 7.

- [ ] **Step 1: Write `skills/harness-audit/scripts/check.sh`**

```bash
#!/usr/bin/env bash
# harness-audit: deterministic harness-readiness checker.
# Usage: check.sh [--run-gate] [TARGET_DIR]     (default: current directory)
# One PASS/FAIL/WARN line per check; exits non-zero iff any FAIL.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHIPPED_PROTOCOL="$SCRIPT_DIR/../../harness-setup/templates/harness-protocol.md"

RUN_GATE=0
TARGET="."
for arg in "$@"; do
  case "$arg" in
    --run-gate) RUN_GATE=1 ;;
    *) TARGET="$arg" ;;
  esac
done
cd "$TARGET"

command -v jq >/dev/null || { echo "FAIL  jq is required to audit FEATURES.json" >&2; exit 2; }

fails=0
pass() { echo "PASS  $*"; }
failc() { echo "FAIL  $*"; fails=$((fails + 1)); }
warn() { echo "WARN  $*"; }

# AGENTS.md: exists and stays a map
if [ -f AGENTS.md ]; then
  pass "AGENTS.md exists"
  if [ "$(wc -l < AGENTS.md)" -le 100 ]; then
    pass "AGENTS.md is <= 100 lines"
  else
    failc "AGENTS.md exceeds 100 lines (it must stay a table of contents)"
  fi
else
  failc "AGENTS.md missing"
fi

# FEATURES.json: parses, entries complete, statuses legal
if [ -f FEATURES.json ] && jq -e . FEATURES.json >/dev/null 2>&1; then
  pass "FEATURES.json parses as JSON"
  if jq -e '[ .features[]?
              | select( ((.id? // "") == "") or ((.milestone? // null) == null)
                        or ((.verify? // "") == "")
                        or ((.status? // "") | IN("failing","passing","deferred","superseded") | not) )
            ] | length == 0' FEATURES.json >/dev/null; then
    pass "every feature has id/milestone/verify and a legal status"
  else
    failc "FEATURES.json: entry missing id/milestone/verify or has illegal status"
  fi
else
  failc "FEATURES.json missing or invalid JSON"
fi

# PROGRESS.md
if [ -f PROGRESS.md ]; then pass "PROGRESS.md exists"; else failc "PROGRESS.md missing"; fi

# The gate
if [ -x scripts/e2e.sh ]; then
  pass "scripts/e2e.sh exists and is executable"
elif [ -f scripts/e2e.sh ]; then
  failc "scripts/e2e.sh is not executable (chmod +x scripts/e2e.sh)"
else
  failc "scripts/e2e.sh missing (the gate)"
fi

# Plans directories
if [ -d docs/plans/active ] && [ -d docs/plans/completed ]; then
  pass "docs/plans/active/ and docs/plans/completed/ exist"
else
  failc "docs/plans/active/ and/or docs/plans/completed/ missing"
fi

# Protocol doc: present, and unmodified vs the shipped copy
if [ -f docs/agents/harness-protocol.md ]; then
  pass "docs/agents/harness-protocol.md exists"
  if [ -f "$SHIPPED_PROTOCOL" ]; then
    if cmp -s docs/agents/harness-protocol.md "$SHIPPED_PROTOCOL"; then
      pass "protocol doc matches the shipped copy"
    else
      warn "protocol doc differs from the shipped copy (drifted or older version)"
    fi
  else
    warn "shipped protocol copy not found next to this script; drift not checked"
  fi
else
  failc "docs/agents/harness-protocol.md missing"
fi

# Pointer file (WARN only: non-vendor repos may use a different entry file)
if [ -f CLAUDE.md ]; then pass "CLAUDE.md pointer exists"; else warn "CLAUDE.md pointer missing"; fi

# Optionally run the gate itself
if [ "$RUN_GATE" -eq 1 ]; then
  if bash scripts/e2e.sh; then failc_gate=0; else failc_gate=1; fi
  if [ "$failc_gate" -eq 0 ]; then pass "gate run: exit 0"; else failc "gate run: non-zero exit"; fi
fi

echo
if [ "$fails" -eq 0 ]; then
  echo "HARNESS READY"
else
  echo "NOT HARNESS READY: $fails failing check(s)"
  exit 1
fi
```

```bash
chmod +x skills/harness-audit/scripts/check.sh
```

- [ ] **Step 2: Run the fixture tests alone**

Run: `bash scripts/test-audit.sh`
Expected: `AUDIT TESTS GREEN`

- [ ] **Step 3: Full gate — GREEN**

Run: `bash scripts/e2e.sh`
Expected: `GATE GREEN`

- [ ] **Step 4: Commit (test + checker together, gate green)**

```bash
git add scripts/test-audit.sh scripts/e2e.sh skills/harness-audit/scripts/check.sh
git commit -m "feat(M8): deterministic harness-readiness checker + fixture tests"
```

### Task 9 (M8): Audit SKILL.md + close out M8

**Files:**
- Create: `skills/harness-audit/SKILL.md`
- Modify: `scripts/e2e.sh` (SKILL.md checks in the harness-audit section)
- Modify: `FEATURES.json` (milestone 8 + two entries), `PROGRESS.md`

- [ ] **Step 0 (RED): Add the SKILL.md gate checks**

In `scripts/e2e.sh`, inside the harness-audit section added in Task 7, after the `shellcheck` line insert:

```bash
[ -f "$AUDIT/SKILL.md" ] || fail "harness-audit SKILL.md missing"
[ "$(head -1 "$AUDIT/SKILL.md")" = "---" ] || fail "harness-audit SKILL.md: missing frontmatter"
grep -q '^name: harness-audit$' "$AUDIT/SKILL.md" || fail "harness-audit SKILL.md: frontmatter name wrong"
grep -q '^description: ' "$AUDIT/SKILL.md" || fail "harness-audit SKILL.md: description missing"
```

Run: `bash scripts/e2e.sh` — Expected: `GATE FAIL: harness-audit SKILL.md missing`

- [ ] **Step 1 (GREEN): Write `skills/harness-audit/SKILL.md`**

```markdown
---
name: harness-audit
description: Use when asked whether a repo is harness-ready, to audit or check a repository's long-running-agent harness (AGENTS.md, FEATURES.json, PROGRESS.md, plans, e2e gate), or before starting harnessed work in an unfamiliar repo — runs a deterministic checker and reports findings, offering fixes without applying them.
---

# Harness Audit

Check whether the current repository is harness-ready. The mechanical
checks live in `scripts/check.sh` — run it, never re-derive it by hand.

**Announce at start:** "Using harness-audit to check harness-readiness."

## Workflow

1. Run `bash scripts/check.sh` (path relative to this skill) from the
   target repo root. Add `--run-gate` only if the human agrees — gates can
   be slow.
2. Relay the PASS/FAIL/WARN report verbatim.
3. Do the one check the script can't: read every `verify` field in
   FEATURES.json and flag unfalsifiable ones ("works correctly"-style).
   The standard is §1.4 of `../harness-setup/templates/harness-protocol.md`
   (worked GOOD/BAD examples inside).
4. Give the verdict: harness-ready, or the ordered list of gaps.
5. **Offer — never auto-apply — fixes:**
   - Structural gaps (no FEATURES.json, no gate, no AGENTS.md): offer to
     run the harness-setup skill in retrofit mode.
   - Trivial gaps (missing plans dirs, drifted or missing protocol doc):
     offer the exact one-liner (mkdir -p / re-copy from harness-setup
     templates).
   - Unfalsifiable verify fields: propose a falsifiable rewrite for each;
     apply only on approval.

## Red flags

| Thought | Reality |
|---|---|
| "I'll eyeball the repo instead of running the script" | The script is the audit. Run it. |
| "I'll fix the gaps while I'm here" | Report + offer. Fixing is the human's call. |
| "verify says 'works correctly' — close enough" | That is the exact failure §1.4 exists to stop. Flag it. |
| "WARNs are fine to omit from the summary" | Relay everything; the human decides what matters. |
```

- [ ] **Step 2: Full gate green**

Run: `bash scripts/e2e.sh`
Expected: `GATE GREEN`

- [ ] **Step 3: Smoke-test on this very repo**

Run: `bash skills/harness-audit/scripts/check.sh`
Expected: exit 1 with `FAIL  docs/agents/harness-protocol.md missing` (this repo is the source; it deliberately has no installed copy) and PASS lines for AGENTS.md/FEATURES.json/PROGRESS.md/gate/plans dirs. This doubles as a live bad-fixture check.

- [ ] **Step 4: Close out M8 — FEATURES.json + PROGRESS.md**

Add to `milestones`: `"8": "harness-audit skill"`.
Append to `features`:

```json
{
  "id": "M8-001",
  "milestone": 8,
  "title": "harness-audit deterministic checker (check.sh) + fixture tests",
  "status": "passing",
  "verify": "bash scripts/test-audit.sh exits 0: good fixture READY, drifted protocol WARNs without failing, five defect fixtures each produce their expected FAIL line and non-zero exit; gate runs it",
  "notes": "Checker is plugin-only by design (not copied into target repos); statuses accept all four legal values, not the spec's two — see plan decision log."
},
{
  "id": "M8-002",
  "milestone": 8,
  "title": "harness-audit SKILL.md judgment layer (report + offer fix)",
  "status": "passing",
  "verify": "Gate: frontmatter checks pass. Manual: check.sh run against this repo exits 1 flagging only the expected gap (no installed protocol doc) — proven in plan Task 9 step 3",
  "notes": ""
}
```

PROGRESS.md top entry:

```markdown
## 2026-07-07 — session 5

- Branch: `m8-audit` (PR).
- Done: M8-001 — check.sh + scripts/test-audit.sh fixture suite, gate-wired.
- Done: M8-002 — harness-audit SKILL.md (report + offer fix, never auto-fix).
- Gate: green.
- Next: M9-001 — PRD/requirements input guidance.
```

- [ ] **Step 5: Gate, commit, PR, checkpoint**

```bash
bash scripts/e2e.sh
git add scripts/e2e.sh skills/harness-audit/SKILL.md FEATURES.json PROGRESS.md
git commit -m "feat(M8-001,M8-002): harness-audit skill (checker + judgment layer)"
git push -u origin m8-audit
gh pr create --title "M8: harness-audit skill" --body "Deterministic check.sh + fixture tests wired into the gate, plus the SKILL.md judgment layer (report + offer fix). Gate green.

🤖 Generated with [Claude Code](https://claude.com/claude-code)"
```

CHECKPOINT — owner merges; then `git checkout master && git pull`.

### Task 10 (M7 manual verify + template repo link): plugin install validation

**Files:** none in this repo; `README.md` in `SedyBenoitPeace/agent-harness-template` (one link)

- [ ] **Step 1: Install the plugin from the local path (manual, with the owner)**

In a Claude Code session: `/plugin marketplace add <local repo path>` then `/plugin install agent-harness-kit`. If the `claude plugin` CLI subcommand is available, the equivalent non-interactive form is fine.
Expected: install succeeds; `harness-setup` and `harness-audit` both appear as invocable skills. Record the result in M7-002's `notes`.

- [ ] **Step 2: Fix the template repo's back-link**

```bash
gh repo clone SedyBenoitPeace/agent-harness-template /tmp/aht-linkfix -- --depth 1
grep -rn "harness-planning-skill" /tmp/aht-linkfix --include='*.md'
```

Replace every `harness-planning-skill` occurrence with `agent-harness-kit` in those markdown files, then:

```bash
cd /tmp/aht-linkfix
git add -u
git commit -m "docs: canonical repo renamed to agent-harness-kit"
git push
```

(Direct push to that repo's default branch matches how it was built — single-commit, owner-instructed. Confirm with the owner first if in doubt.)

### Task 11 (M9): PRD-input guidance — gate-first

**Files:**
- Modify: `scripts/e2e.sh` (two new checks)
- Modify: `skills/harness-setup/templates/harness-protocol.md` (§1.1 addition)
- Modify: `README.md` (new section)
- Modify: `skills/harness-setup/SKILL.md` (one bullet)
- Modify: `FEATURES.json` (milestone 9 + one entry), `PROGRESS.md`

- [ ] **Step 1: Branch**

```bash
git checkout -b m9-prd-input master
```

- [ ] **Step 2 (RED): Add gate checks**

In `scripts/e2e.sh`, after the existing `## 1. Planning protocol` protocol checks (the block ending with the agent-neutrality grep), add:

```bash
grep -q 'Already have requirements' "$PROTO" || fail "protocol: PRD-input rule missing from section 1.1"
```

And in the README section add:

```bash
grep -q 'PRD' README.md || fail "README: PRD-input section missing"
```

Run: `bash scripts/e2e.sh` — Expected: `GATE FAIL: protocol: PRD-input rule missing...`

- [ ] **Step 3 (GREEN): Protocol §1.1 addition**

In `skills/harness-setup/templates/harness-protocol.md`, insert between the numbered question list and the "If an answer is vague..." paragraph (i.e. after line 59, before line 61):

```markdown
**Already have requirements?** If the human provides a requirements
document (a PRD, spec, or brief — markdown, PDF, or HTML all work), read
it first and extract answers to the questions above from it. Then
interview only the gaps and ambiguities, quoting the document when
confirming an interpretation. A provided document never waives §1.4:
every feature still needs a falsifiable `verify`, whoever authored the
requirement.
```

⚠️ Agent-neutral wording only — the gate rejects any `claude` string in this file.

- [ ] **Step 4: README section**

Insert after the "Quickstart — any other agent" section:

````markdown
## Already have requirements?

You don't have to start the planning interview from zero. Put your
existing requirements in the repo — markdown preferred (`docs/PRD.md` is a
good spot), but PDF or HTML work too, agents read those — and say:

```
Set up the harness using docs/PRD.md as the product requirements.
```

The interview extracts what it can from the document and only asks you
about the gaps.
````

- [ ] **Step 5: SKILL.md bullet**

In `skills/harness-setup/SKILL.md` step 2's bullet list, add:

```markdown
- If the human supplied a requirements document (markdown, PDF, or HTML),
  follow §1.1's rule: extract interview answers from it and ask only
  about the gaps.
```

- [ ] **Step 6: Gate green**

Run: `bash scripts/e2e.sh` — Expected: `GATE GREEN`

- [ ] **Step 7: Close out M9 — FEATURES.json + PROGRESS.md + PR**

Add to `milestones`: `"9": "PRD/requirements input guidance"`.
Append feature:

```json
{
  "id": "M9-001",
  "milestone": 9,
  "title": "PRD-input guidance: README section + protocol section 1.1 rule + SKILL.md bullet",
  "status": "passing",
  "verify": "Gate: protocol contains 'Already have requirements' in section 1.1 and stays agent-neutral; README contains a PRD section; all line budgets hold",
  "notes": ""
}
```

PROGRESS.md top entry:

```markdown
## 2026-07-07 — session 6

- Branch: `m9-prd-input` (PR).
- Done: M9-001 — PRD/requirements input documented in README, protocol
  §1.1, and harness-setup SKILL.md.
- Gate: green.
- Next: none failing. Plan moves to docs/plans/completed/. Pending owner
  decisions: repo public flip; plugin install field-test results.
```

```bash
bash scripts/e2e.sh
git add scripts/e2e.sh skills/harness-setup/templates/harness-protocol.md README.md skills/harness-setup/SKILL.md FEATURES.json PROGRESS.md
git commit -m "feat(M9-001): PRD-input guidance (README + protocol 1.1 + SKILL.md)"
git push -u origin m9-prd-input
gh pr create --title "M9: PRD/requirements input guidance" --body "Documents feeding an existing PRD (md/PDF/HTML) into the planning interview: README section, protocol §1.1 rule (agent-neutral), harness-setup SKILL.md bullet. Gate green.

🤖 Generated with [Claude Code](https://claude.com/claude-code)"
```

CHECKPOINT — owner merges; then `git checkout master && git pull`.

### Task 12: Plan close-out

- [ ] **Step 1: Move this plan to completed**

```bash
git checkout -b plan-closeout master
git mv docs/plans/active/2026-07-07-agent-harness-kit.md docs/plans/completed/
git commit -m "docs: move agent-harness-kit plan to completed"
git push -u origin plan-closeout
gh pr create --title "docs: close out agent-harness-kit plan" --body "M7–M9 all passing; plan moves to completed/.

🤖 Generated with [Claude Code](https://claude.com/claude-code)"
```

---

## Decision log

- **2026-07-07 — GitHub rename, not a new repo.** Owner confirmed. History,
  PRs, and redirects preserved. The **local directory is never renamed**
  (session history is keyed by path); `gh repo rename` updates `origin`.
- **2026-07-07 — skill renamed harness-planning → harness-setup.** Matches
  the "full harness tool" positioning; setup includes planning.
- **2026-07-07 — checker accepts all four statuses** (`failing`, `passing`,
  `deferred`, `superseded`), not the spec table's two — the spec table was
  shorthand; the repo schema and protocol §1.4 define four. Spec not
  re-edited; this log is the record.
- **2026-07-07 — protocol drift is WARN (exit 0), not FAIL.** Spec §3.1's
  severity table wins over §3.3's fixture list, which grouped drift with the
  hard defects: the copy-install path predates the plugin, so an older
  protocol copy must not flunk an otherwise healthy repo. The drift fixture
  asserts WARN + exit 0.
- **2026-07-07 — audit checker stays plugin-only** (not copied into target
  repos); CI reuse deferred per spec §5.
- **2026-07-07 — fixture tests generate fixtures at runtime** from the
  shipped templates (no stored fixture trees): zero drift between what
  harness-setup scaffolds and what harness-audit approves.
