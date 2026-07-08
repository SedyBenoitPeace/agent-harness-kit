# M11: harness-status skill + lifecycle guidance — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a third skill, `harness-status` ("where does this project stand, what's next?"), guard `harness-setup` against already-harnessed repos, and give the README a lifecycle section with the slash-command forms users actually see — released as plugin 1.2.0.

**Architecture:** Same two-layer pattern as harness-audit: a deterministic script (`skills/harness-status/scripts/status.sh`, parses only FEATURES.json + PROGRESS.md, no git — so fixtures stay plain directories) plus a thin SKILL.md judgment layer that adds `git log` context and enforces read-only behavior. Every new invariant lands in `scripts/e2e.sh` RED→GREEN. Boundary kept sharp: **audit = "is the harness well-formed?", status = "how is the work going?"**.

**Tech Stack:** bash + jq + shellcheck (same as existing gate and audit checker).

## Global Constraints

- Protocol doc (`harness-protocol.md`) is **not touched** in this milestone.
- `AGENTS.md` ≤ 100 lines. No personal paths (`/Users/...`, `/home/...`) in tracked files.
- FEATURES.json: never delete/renumber entries; new entries land **in the same commit** that proves them passing (batched in the close-out task, matching M7–M10 practice). Legal statuses: `failing`, `passing`, `deferred`, `superseded`.
- Stage explicit paths (no `git add -A`). One branch `m11-status` off `master`; integrate via one PR; **the owner merges** — pause at the PR checkpoint.
- Plugin version everywhere: `1.2.0` (cache is keyed by version; without the bump `claude plugin update` no-ops).
- Gate must print `GATE GREEN` (exit 0) at every commit point.
- status.sh exit codes are contract: `0` report printed, `2` harness file broken, `3` harness not initialized.

---

### Task 1: Preflight + branch + commit this plan

**Files:**
- Create: `docs/plans/active/2026-07-08-m11-status-and-guidance.md` (this file)

- [ ] **Step 1: Confirm master is current (v1.1.0 merged)**

Run: `git fetch origin && git log --oneline origin/master -3`
Expected: `f24a4a8` (the 1.1.0 bump) or a merge containing it is present. If it is NOT on origin/master, STOP — ask the owner to merge/push the `v1.1.0` branch first; branching off a stale master would drop M9/M10 content.

- [ ] **Step 2: Branch off master**

```bash
git checkout master && git pull && git checkout -b m11-status master
```

- [ ] **Step 3: Commit the plan**

```bash
git add docs/plans/active/2026-07-08-m11-status-and-guidance.md
git commit -m "docs: implementation plan for M11 (harness-status + lifecycle guidance)"
```

### Task 2 (M11-001 RED): Fixture tests for status.sh + gate wiring

**Files:**
- Create: `scripts/test-status.sh` (executable)
- Modify: `scripts/e2e.sh` (append harness-status section after the harness-audit section, before the final `echo "GATE GREEN"`)

**Interfaces:**
- Produces: the CLI contract for Task 3's `skills/harness-status/scripts/status.sh` — args `[--run-gate] [TARGET_DIR]`; output contains `HARNESS NOT INITIALIZED` (exit 3, names harness-setup), a per-milestone rollup line `M<k>: <p>/<t> passing — <name>`, a `NEXT: <id> — <title>` line (or `NEXT: none`), the first `## ` block of PROGRESS.md only; broken FEATURES.json → exit 2 naming harness-audit.

- [ ] **Step 1: Write `scripts/test-status.sh`**

```bash
#!/usr/bin/env bash
# Fixture tests for skills/harness-status/scripts/status.sh.
# Fixtures are plain directories (status.sh reads only FEATURES.json/PROGRESS.md).
set -euo pipefail
cd "$(dirname "$0")/.."

STATUS="skills/harness-status/scripts/status.sh"

fail() { echo "STATUS-TEST FAIL: $*" >&2; exit 1; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# 1. uninitialized dir: exit 3, points at harness-setup
mkdir "$WORK/bare"
rc=0; out="$(bash "$STATUS" "$WORK/bare")" || rc=$?
[ "$rc" -eq 3 ] || fail "bare dir: expected exit 3, got $rc"
echo "$out" | grep -q "HARNESS NOT INITIALIZED" || fail "bare dir: missing NOT INITIALIZED line"
echo "$out" | grep -q "harness-setup" || fail "bare dir: must point at harness-setup"

# 2. harnessed fixture: rollup + protocol-2 next-feature selection + last session only
mkdir "$WORK/repo"
cat > "$WORK/repo/FEATURES.json" <<'JSON'
{
  "milestones": { "0": "Skeleton", "1": "Core" },
  "features": [
    { "id": "M0-001", "milestone": 0, "title": "boot", "status": "passing", "verify": "x" },
    { "id": "M1-001", "milestone": 1, "title": "core A", "status": "failing", "verify": "test A passes" },
    { "id": "M1-002", "milestone": 1, "title": "core B", "status": "failing", "verify": "test B passes" }
  ]
}
JSON
printf '## 2026-01-02 -- session 2\n- Done: M0-001.\n\n## 2026-01-01 -- session 1\n- Setup.\n' > "$WORK/repo/PROGRESS.md"
out="$(bash "$STATUS" "$WORK/repo")" || fail "harnessed fixture: expected exit 0"
echo "$out" | grep -q "M0: 1/1 passing" || fail "milestone rollup wrong (M0)"
echo "$out" | grep -q "M1: 0/2 passing" || fail "milestone rollup wrong (M1)"
echo "$out" | grep -q "NEXT: M1-001" || fail "next-feature selection wrong (want M1-001)"
echo "$out" | grep -q "session 2" || fail "last-session extract missing"
if echo "$out" | grep -q "session 1"; then fail "last-session extract leaked older entries"; fi

# 3. nothing failing: explicit NEXT: none message
jq '.features[].status = "passing"' "$WORK/repo/FEATURES.json" > "$WORK/repo/F.tmp"
mv "$WORK/repo/F.tmp" "$WORK/repo/FEATURES.json"
out="$(bash "$STATUS" "$WORK/repo")" || fail "all-passing fixture: expected exit 0"
echo "$out" | grep -q "NEXT: none" || fail "all-passing: missing NEXT: none message"

# 4. broken FEATURES.json: exit 2, points at harness-audit
echo '{ nope' > "$WORK/repo/FEATURES.json"
rc=0; bash "$STATUS" "$WORK/repo" > "$WORK/broken.out" || rc=$?
[ "$rc" -eq 2 ] || fail "broken JSON: expected exit 2, got $rc"
grep -q "harness-audit" "$WORK/broken.out" || fail "broken JSON: must point at harness-audit"

echo "STATUS TESTS GREEN"
```

```bash
chmod +x scripts/test-status.sh
```

- [ ] **Step 2: Wire into the gate**

Append to `scripts/e2e.sh` after the harness-audit section (after the `bash scripts/test-audit.sh` line), before the final `echo "GATE GREEN"`:

```bash
# --- harness-status skill -----------------------------------------------------

STATUS_SKILL="skills/harness-status"
[ -f "$STATUS_SKILL/scripts/status.sh" ] || fail "harness-status status.sh missing"
shellcheck "$STATUS_SKILL/scripts/status.sh"
[ -f "$STATUS_SKILL/SKILL.md" ] || fail "harness-status SKILL.md missing"
[ "$(head -1 "$STATUS_SKILL/SKILL.md")" = "---" ] || fail "harness-status SKILL.md: missing frontmatter"
grep -q '^name: harness-status$' "$STATUS_SKILL/SKILL.md" || fail "harness-status SKILL.md: frontmatter name wrong"
grep -q '^description: ' "$STATUS_SKILL/SKILL.md" || fail "harness-status SKILL.md: description missing"
bash scripts/test-status.sh
```

- [ ] **Step 3: Run gate to verify it fails (RED)**

Run: `bash scripts/e2e.sh`
Expected: `GATE FAIL: harness-status status.sh missing`

Do **not** commit yet — tests, script, gate wiring, and SKILL.md all land together as one green commit at the end of Task 4.

### Task 3 (M11-001 GREEN): The deterministic status script

**Files:**
- Create: `skills/harness-status/scripts/status.sh` (executable)

**Interfaces:**
- Consumes: the CLI contract from Task 2.
- Produces: `status.sh` used verbatim by Task 4's SKILL.md.

- [ ] **Step 1: Write `skills/harness-status/scripts/status.sh`**

```bash
#!/usr/bin/env bash
# harness-status: read-only "where am I?" report for a harnessed repo.
# Usage: status.sh [--run-gate] [TARGET_DIR]    (default: current directory)
# Exit codes: 0 report printed; 2 harness file broken; 3 harness not initialized.
set -euo pipefail

RUN_GATE=0
TARGET="."
for arg in "$@"; do
  case "$arg" in
    --run-gate) RUN_GATE=1 ;;
    *) TARGET="$arg" ;;
  esac
done
cd "$TARGET"

if [ ! -f FEATURES.json ] || [ ! -f PROGRESS.md ]; then
  echo "HARNESS NOT INITIALIZED: FEATURES.json and/or PROGRESS.md missing."
  echo "Scaffold it with the harness-setup skill (or harness-protocol.md section 1)."
  exit 3
fi

command -v jq >/dev/null || { echo "ERROR: jq is required (brew install jq)" >&2; exit 2; }
jq -e . FEATURES.json >/dev/null 2>&1 \
  || { echo "BROKEN HARNESS: FEATURES.json is not valid JSON — run the harness-audit skill."; exit 2; }

echo "HARNESS STATUS"
echo
echo "== Milestones =="
jq -r '
  .milestones as $m
  | (.features | group_by(.milestone))[]
  | (.[0].milestone | tostring) as $k
  | ([.[] | select(.status == "passing")] | length) as $p
  | "M\($k): \($p)/\(length) passing — \($m[$k] // "?")"
' FEATURES.json

echo
echo "== Totals =="
jq -r '
  .features
  | "passing \([.[] | select(.status == "passing")] | length), failing \([.[] | select(.status == "failing")] | length), deferred \([.[] | select(.status == "deferred")] | length), superseded \([.[] | select(.status == "superseded")] | length)"
' FEATURES.json

echo
echo "== Next feature (lowest milestone, then lowest id, among failing) =="
jq -r '
  [.features[] | select(.status == "failing")] | sort_by(.milestone, .id)
  | if length == 0
    then "NEXT: none — nothing failing; plan new work (protocol section 1) or run a maintenance pass (section 3)"
    else "NEXT: \(.[0].id) — \(.[0].title)\n  verify: \(.[0].verify)"
    end
' FEATURES.json

echo
echo "== Last session (PROGRESS.md) =="
if grep -q '^## ' PROGRESS.md; then
  awk '/^## /{n++} n==1' PROGRESS.md
else
  echo "(no session entries yet)"
fi

if [ "$RUN_GATE" -eq 1 ]; then
  echo
  echo "== Gate =="
  if [ -f scripts/e2e.sh ] && bash scripts/e2e.sh >/dev/null 2>&1; then
    echo "GATE: green (scripts/e2e.sh exit 0)"
  else
    echo "GATE: red or missing — run: bash scripts/e2e.sh"
  fi
fi
```

```bash
chmod +x skills/harness-status/scripts/status.sh
```

- [ ] **Step 2: Run the fixture tests alone**

Run: `bash scripts/test-status.sh`
Expected: `STATUS TESTS GREEN`

- [ ] **Step 3: Full gate — still RED (SKILL.md missing)**

Run: `bash scripts/e2e.sh`
Expected: `GATE FAIL: harness-status SKILL.md missing` — correct; Task 4 turns it green.

- [ ] **Step 4: No commit yet**

Script, tests, gate wiring, and SKILL.md land as one green commit at the end of Task 4.

### Task 4 (M11-001): harness-status SKILL.md + smoke test + commit

**Files:**
- Create: `skills/harness-status/SKILL.md`

**Interfaces:**
- Consumes: `scripts/status.sh` contract (exit 0/2/3) from Task 2.

- [ ] **Step 1: Write `skills/harness-status/SKILL.md`**

```markdown
---
name: harness-status
description: Use when asked where a harnessed project stands, what was done so far, what to do next, or for a progress/status report on a repo using the long-running-agent harness — reads FEATURES.json and PROGRESS.md via a deterministic script and reports milestone progress, the exact next feature, and last-session notes; tells the user if the harness is not initialized.
---

# Harness Status

Read-only "where am I?" report for a harnessed repo. The mechanical
parsing lives in `scripts/status.sh` — run it, never re-derive it by hand.

**Announce at start:** "Using harness-status to report where this project stands."

## Workflow

1. Run `bash scripts/status.sh` (path relative to this skill) from the
   target repo root.
   - Exit 3 → harness not initialized: tell the human plainly, offer the
     harness-setup skill, STOP.
   - Exit 2 → a harness file is broken: relay the message, suggest the
     harness-audit skill, STOP.
2. Add the one thing the script can't see: `git log -5 --oneline` for
   recent commit context.
3. Relay the report: milestone rollup, totals, last session, and the
   NEXT feature — this is the same pick a coding session (protocol §2)
   would make, so "what to do next" is deterministic.
4. Offer `--run-gate` only if the human wants health confirmed — gates
   can be slow.
5. Status is read-only. Change nothing, flip no statuses. To do the
   work, start a coding session (protocol §2).

## Red flags

| Thought | Reality |
|---|---|
| "I'll parse FEATURES.json myself" | The script is the parser. Run it. |
| "While I'm here I'll flip that stale status" | Status is read-only. Report; a session changes state. |
| "Not initialized — I'll just scaffold it now" | Offer harness-setup; the human decides. |
| "Status and audit are basically the same" | Audit = is the harness well-formed. Status = how is the work going. |
```

- [ ] **Step 2: Full gate — GREEN**

Run: `bash scripts/e2e.sh`
Expected: `GATE GREEN`

- [ ] **Step 3: Smoke-test on this very repo**

Run: `bash skills/harness-status/scripts/status.sh`
Expected: exit 0; rollup shows every milestone fully passing; `NEXT: none — nothing failing...`; last-session block matches the top of PROGRESS.md.

- [ ] **Step 4: Commit (tests + script + gate wiring + SKILL.md together, gate green)**

```bash
git add scripts/test-status.sh scripts/e2e.sh skills/harness-status
git commit -m "feat(M11): harness-status skill (deterministic status.sh + fixtures + SKILL.md)"
```

### Task 5 (M11-002): already-initialized guard in harness-setup — gate-first

**Files:**
- Modify: `scripts/e2e.sh` (one line in the harness-setup SKILL.md section)
- Modify: `skills/harness-setup/SKILL.md` (§1 "Detect the mode")

- [ ] **Step 1 (RED): Add gate check**

In `scripts/e2e.sh`, after the existing `grep -q '^description: ' "$SKILL"` line, add:

```bash
grep -q 'Already harnessed' "$SKILL" || fail "SKILL.md: already-initialized guard missing"
```

Run: `bash scripts/e2e.sh` — Expected: `GATE FAIL: SKILL.md: already-initialized guard missing`

- [ ] **Step 2 (GREEN): Add the guard to `skills/harness-setup/SKILL.md`**

In section "### 1. Detect the mode", after the two existing bullets (Greenfield / Retrofit), add:

```markdown
- **Already harnessed**: if `FEATURES.json`, `PROGRESS.md`, and
  `docs/agents/harness-protocol.md` all exist, STOP — the harness is
  already set up. Tell the human and point them to **harness-status**
  ("where am I?") or **harness-audit** ("is it well-formed?").
  Re-scaffold only if they explicitly confirm they want that.
```

- [ ] **Step 3: Gate green**

Run: `bash scripts/e2e.sh` — Expected: `GATE GREEN`

- [ ] **Step 4: Commit**

```bash
git add scripts/e2e.sh skills/harness-setup/SKILL.md
git commit -m "feat(M11): harness-setup guard for already-harnessed repos"
```

### Task 6 (M11-003): README lifecycle + slash commands — gate-first

**Files:**
- Modify: `scripts/e2e.sh` (three lines in the README section)
- Modify: `README.md`

- [ ] **Step 1 (RED): Add gate checks**

In `scripts/e2e.sh`, README section, after the `grep -q 'Using the skills'` line, add:

```bash
grep -q 'harness-status' README.md || fail "README: harness-status skill missing"
grep -q '/agent-harness-kit:harness-setup' README.md || fail "README: slash-command forms missing"
grep -q '## Lifecycle' README.md || fail "README: lifecycle section missing"
```

Run: `bash scripts/e2e.sh` — Expected: `GATE FAIL: README: harness-status skill missing`

- [ ] **Step 2 (GREEN): Update the quickstart skill list**

Replace the "Two skills come with it:" block with:

```markdown
Three skills come with it — invoke each as a slash command or in plain
English:

- **harness-setup** — interview → PRODUCT.md + FEATURES.json → scaffold the
  whole harness. `/agent-harness-kit:harness-setup` or *"set up the agent
  harness in this repo"*.
- **harness-status** — where the project stands: progress per milestone,
  last session, exact next feature. `/agent-harness-kit:harness-status` or
  *"what's the harness status?"*.
- **harness-audit** — check any repo's harness-readiness.
  `/agent-harness-kit:harness-audit` or *"audit this repo's harness"*.
```

- [ ] **Step 3: Insert the Lifecycle section**

Insert directly after the quickstart section (before "## Using the skills"):

```markdown
## Lifecycle — how the pieces fit

1. **Set up once** — `/agent-harness-kit:harness-setup`. Expect an
   interview about the product before anything is written; it ends with
   the full scaffold (AGENTS.md, FEATURES.json, PROGRESS.md, docs/plans/,
   docs/agents/harness-protocol.md, scripts/e2e.sh). Repos that are
   already harnessed are detected and left alone.
2. **Build one feature per session** — say *"Read AGENTS.md, then
   docs/agents/harness-protocol.md section 2, and perform exactly one
   coding session."* Repeat until the milestone is done.
3. **Check where you are** — `/agent-harness-kit:harness-status` any
   time: progress per milestone, what the last session did, and exactly
   which feature the next session will pick. If the harness isn't set up
   yet, it says so and points you to setup.
4. **Keep it honest** — `/agent-harness-kit:harness-audit` when a repo
   drifts or before working in an unfamiliar one, plus a periodic
   maintenance pass (protocol section 3).
```

- [ ] **Step 4: Add the status row to the "Using the skills" table**

After the "Check a repo is harness-ready" row:

```markdown
| See progress + what's next | *"What's the harness status?"* |
```

- [ ] **Step 5: Update the repository layout diagram**

In the layout code block, after the `harness-audit` entry, add:

```
└── harness-status/
    ├── SKILL.md        status orchestration: read-only report
    └── scripts/status.sh         deterministic progress/next-feature report
```

(adjust the tree characters so `harness-audit` becomes `├──` and `harness-status` is the final `└──`).

- [ ] **Step 6: Gate green**

Run: `bash scripts/e2e.sh` — Expected: `GATE GREEN`

- [ ] **Step 7: Commit**

```bash
git add scripts/e2e.sh README.md
git commit -m "docs(M11): README lifecycle section, slash-command forms, harness-status coverage"
```

### Task 7 (M11-004): Release 1.2.0 + manifest version-sync gate check

**Files:**
- Modify: `scripts/e2e.sh` (plugin packaging section)
- Modify: `.claude-plugin/plugin.json` (version)
- Modify: `.claude-plugin/marketplace.json` (plugins[0].version)

- [ ] **Step 1: Add the version-sync invariant to the gate**

In `scripts/e2e.sh`, plugin packaging section, after the marketplace.json check, add:

```bash
[ "$(jq -r .version .claude-plugin/plugin.json)" = "$(jq -r '.plugins[0].version' .claude-plugin/marketplace.json)" ] \
  || fail "plugin.json / marketplace.json version mismatch"
```

Run: `bash scripts/e2e.sh` — Expected: `GATE GREEN` (both currently 1.1.0 — the invariant holds).

- [ ] **Step 2 (RED): Bump plugin.json only**

Set `"version": "1.2.0"` in `.claude-plugin/plugin.json`.
Run: `bash scripts/e2e.sh` — Expected: `GATE FAIL: plugin.json / marketplace.json version mismatch` (proves the new check bites).

- [ ] **Step 3 (GREEN): Bump marketplace.json**

Set `"version": "1.2.0"` in `.claude-plugin/marketplace.json` `plugins[0]`.
Run: `bash scripts/e2e.sh` — Expected: `GATE GREEN`

- [ ] **Step 4: Commit**

```bash
git add scripts/e2e.sh .claude-plugin/plugin.json .claude-plugin/marketplace.json
git commit -m "chore(M11): bump plugin to 1.2.0 + enforce manifest version sync in gate"
```

### Task 8: Close out M11 — FEATURES.json + PROGRESS.md + PR

**Files:**
- Modify: `FEATURES.json` (milestone 11 + four entries)
- Modify: `PROGRESS.md` (new top entry)

- [ ] **Step 1: Append to FEATURES.json**

Add to `milestones`: `"11": "harness-status skill + lifecycle guidance"`.
Append to `features`:

```json
{
  "id": "M11-001",
  "milestone": 11,
  "title": "harness-status skill: deterministic status.sh + fixture tests + SKILL.md",
  "status": "passing",
  "verify": "bash scripts/test-status.sh exits 0: bare dir exits 3 naming harness-setup; harnessed fixture reports per-milestone rollup, NEXT: M1-001 selection, and only the newest PROGRESS.md entry; all-passing prints NEXT: none; broken JSON exits 2 naming harness-audit. Gate runs it and checks SKILL.md frontmatter",
  "notes": "Read-only by design. status.sh parses only FEATURES.json/PROGRESS.md (no git) so fixtures stay plain dirs; git context is added by the SKILL.md layer."
},
{
  "id": "M11-002",
  "milestone": 11,
  "title": "harness-setup already-initialized guard (STOP + point to status/audit)",
  "status": "passing",
  "verify": "Gate: harness-setup SKILL.md contains the 'Already harnessed' mode in section 1 with STOP and pointers to harness-status/harness-audit",
  "notes": ""
},
{
  "id": "M11-003",
  "milestone": 11,
  "title": "README lifecycle section + slash-command forms + harness-status coverage",
  "status": "passing",
  "verify": "Gate: README contains '## Lifecycle', '/agent-harness-kit:harness-setup', and 'harness-status'; all pre-existing README checks still pass",
  "notes": ""
},
{
  "id": "M11-004",
  "milestone": 11,
  "title": "Release 1.2.0 + manifest version-sync gate check",
  "status": "passing",
  "verify": "Gate: jq reads identical version from plugin.json and marketplace.json plugins[0]; both say 1.2.0",
  "notes": "Bump required for plugin cache refresh (cache keyed by version; update compares version strings only)."
}
```

- [ ] **Step 2: Add PROGRESS.md entry at the top**

Use the next session number after the current top entry:

```markdown
## 2026-07-08 — session N

- Branch: `m11-status` (PR).
- Done: M11-001 — harness-status skill (status.sh + fixtures + SKILL.md).
- Done: M11-002 — harness-setup already-initialized guard.
- Done: M11-003 — README lifecycle section + slash-command forms.
- Done: M11-004 — 1.2.0 bump + manifest version-sync gate check.
- Gate: green.
- Next: none failing. Plan moves to docs/plans/completed/ after merge.
```

- [ ] **Step 3: Gate, commit, push, PR**

```bash
bash scripts/e2e.sh
git add FEATURES.json PROGRESS.md
git commit -m "feat(M11-001..004): record harness-status milestone as passing"
git push -u origin m11-status
gh pr create --title "M11: harness-status skill + lifecycle guidance" --body "New harness-status skill (deterministic status.sh + fixture tests + read-only SKILL.md), already-initialized guard in harness-setup, README lifecycle/slash-command guidance, 1.2.0 bump with manifest version-sync enforced in the gate. Gate green.

🤖 Generated with [Claude Code](https://claude.com/claude-code)"
```

- [ ] **Step 4: CHECKPOINT — owner merges; then `git checkout master && git pull`**

### Task 9: Plan close-out (after merge)

- [ ] **Step 1: Move this plan to completed**

```bash
git checkout -b m11-closeout master
git mv docs/plans/active/2026-07-08-m11-status-and-guidance.md docs/plans/completed/
git commit -m "docs: move M11 plan to completed"
git push -u origin m11-closeout
gh pr create --title "docs: close out M11 plan" --body "M11 all passing; plan moves to completed/.

🤖 Generated with [Claude Code](https://claude.com/claude-code)"
```

---

## Decision log

- **2026-07-08 — status does NOT reuse audit's check.sh for detection.**
  Earlier idea was to call check.sh; rejected because it emits FAIL lines
  and audit verdicts that blur the status/audit boundary. Detection is a
  two-file presence test (FEATURES.json + PROGRESS.md) — not meaningful
  duplication.
- **2026-07-08 — status.sh is git-free.** It parses only FEATURES.json and
  PROGRESS.md, so fixtures are plain directories (no git init in tests);
  the SKILL.md layer adds `git log -5` context at runtime.
- **2026-07-08 — distinct exit codes are contract:** 0 report, 2 broken
  harness file (→ audit), 3 not initialized (→ setup). The SKILL.md
  branches on them.
- **2026-07-08 — setup guard lives in SKILL.md only, not the protocol doc.**
  The guard is skill-front-end orchestration; the agent-neutral protocol
  stays untouched this milestone.
- **2026-07-08 — one branch/PR for all of M11** (matches owner's preference
  from M9/M10: "pack everything into one PR").
