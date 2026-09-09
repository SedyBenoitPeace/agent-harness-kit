# M15 Efficient Coding Sessions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a plugin-owned `harness-session` workflow that executes one harness feature with bounded recovery, safe interrupted-work handling, optional project preflight, and concise full-gate reporting.

**Architecture:** A new two-layer skill keeps deterministic mechanics in `context.sh` and `run-gate.sh`, with workflow judgment in `SKILL.md`. `context.sh` delegates feature selection to the existing `harness-status` script; `run-gate.sh` wraps, but never replaces, a target repository's gate.

**Tech Stack:** Bash 3.2-compatible shell, jq, git, shellcheck, Markdown plugin skills, fixture-based shell tests.

**Spec:** `docs/specs/2026-09-09-efficient-coding-sessions-design.md`

## Global Constraints

- Preserve one feature per implementation session and the mandatory final full gate.
- Keep `harness-status` read-only and reuse it as the sole feature selector.
- Keep scripts deterministic and non-interactive; judgment belongs in `SKILL.md`.
- Keep the protocol agent-neutral and free of vendor names.
- Do not add stack-specific service knowledge to the plugin.
- Do not modify target repositories' existing `scripts/e2e.sh` files.
- Scripts must run under macOS Bash 3.2 and pass shellcheck.
- Do not bump plugin manifests before M15-004.

---

### Task 1: M15-001 — Harness-session bounded context and safe session start

**Files:**
- Create: `skills/harness-session/SKILL.md`
- Create: `skills/harness-session/scripts/context.sh`
- Create: `scripts/test-session.sh`
- Modify: `scripts/e2e.sh`
- Modify: `ARCHITECTURE.md`
- Modify: `FEATURES.json`
- Modify: `PROGRESS.md`

**Interfaces:**
- Consumes: `skills/harness-status/scripts/status.sh [TARGET_DIR]`, target `FEATURES.json`, `PROGRESS.md`, git metadata, optional executable `scripts/preflight.sh`.
- Produces: `context.sh [TARGET_DIR]` with exit `0`, `2`, or `3`; `harness-session` skill workflow for exactly one feature.

- [ ] **Step 1: Write the failing fixture tests**

Create `scripts/test-session.sh` with temporary fixtures covering:

```bash
# bare directory delegates to status and exits 3
rc=0
bash "$CONTEXT" "$WORK/bare" >"$WORK/bare.out" || rc=$?
[ "$rc" -eq 3 ]
grep -q 'HARNESS NOT INITIALIZED' "$WORK/bare.out"

# clean harness reports selected feature, branch, clean tree, matching plan, no preflight
out="$(bash "$CONTEXT" "$WORK/repo")"
echo "$out" | grep -q 'NEXT: M2-001'
echo "$out" | grep -q 'WORKTREE: clean'
echo "$out" | grep -q 'PLAN: docs/plans/active/m2.md'
echo "$out" | grep -q 'PREFLIGHT: absent'

# dirty harness reports facts without classifying ownership
printf 'change\n' >> "$WORK/repo/tracked.txt"
out="$(bash "$CONTEXT" "$WORK/repo")"
echo "$out" | grep -q 'WORKTREE: dirty'
echo "$out" | grep -q ' M tracked.txt'

# executable target preflight is discovered, not executed by context.sh
mkdir -p "$WORK/repo/scripts"
printf '#!/usr/bin/env bash\nexit 0\n' > "$WORK/repo/scripts/preflight.sh"
chmod +x "$WORK/repo/scripts/preflight.sh"
out="$(bash "$CONTEXT" "$WORK/repo")"
echo "$out" | grep -q 'PREFLIGHT: scripts/preflight.sh'
```

Also assert that only five commit subjects appear and only the newest `PROGRESS.md` session is emitted through delegated status output.

- [ ] **Step 2: Run the fixture test to verify RED**

Run:

```bash
bash scripts/test-session.sh
```

Expected: non-zero because `skills/harness-session/scripts/context.sh` does not exist.

- [ ] **Step 3: Implement deterministic bounded context**

Create `context.sh` with this control flow:

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
STATUS="$SCRIPT_DIR/../../harness-status/scripts/status.sh"
TARGET="${1:-.}"

bash "$STATUS" "$TARGET"
cd "$TARGET"

echo
echo '== Recent commits =='
git log -5 --oneline

echo
echo '== Worktree =='
branch="$(git branch --show-current)"
echo "BRANCH: ${branch:-detached}"
if [ -z "$(git status --short)" ]; then
  echo 'WORKTREE: clean'
else
  echo 'WORKTREE: dirty'
  git status --short
fi

next_id="$(jq -r '[.features[] | select(.status == "failing")] | sort_by(.milestone, .id) | .[0].id // empty' FEATURES.json)"
echo
echo '== Active plan references =='
if [ -n "$next_id" ]; then
  matches="$(grep -ril --include='*.md' "$next_id" docs/plans/active 2>/dev/null || true)"
  if [ -n "$matches" ]; then
    printf '%s\n' "$matches" | sed 's/^/PLAN: /'
  else
    echo "PLAN: none mentioning $next_id"
  fi
else
  echo 'PLAN: none — no failing feature'
fi

if [ -x scripts/preflight.sh ]; then
  echo 'PREFLIGHT: scripts/preflight.sh'
else
  echo 'PREFLIGHT: absent'
fi
```

Keep the script read-only and do not reimplement status rollups or next-feature formatting.

- [ ] **Step 4: Write `harness-session/SKILL.md`**

The frontmatter name is `harness-session`. Its description explicitly triggers for “implement”, “continue”, “carry on”, and “execute” a harness feature.

The workflow must state:

```text
1. Run context.sh from the target root.
2. If scripts/preflight.sh is reported, execute it; non-zero blocks.
3. Clean worktree: run the baseline full gate.
4. Dirty worktree clearly matching the selected feature and plan:
   announce CONTINUING INTERRUPTED FEATURE, inspect its diff, run focused verify first,
   and never claim a clean baseline.
5. Dirty unrelated or ambiguous worktree: stop and ask the human.
6. Follow red-green-refactor for only the selected feature.
7. Do not investigate an exit-zero warning already tracked by another feature unless
   the selected verify requires it.
8. Run the final full gate, close out exactly one feature, and commit explicit paths.
```

Reference `run-gate.sh` as arriving in M15-002; until then the skill invokes `bash scripts/e2e.sh` directly so M15-001 is independently usable.

- [ ] **Step 5: Wire the gate and architecture**

Add shellcheck and `bash scripts/test-session.sh` to the root gate. Add `harness-session` to the system diagram/module map and an M15 subsystem note explaining bounded context plus script/judgment separation.

- [ ] **Step 6: Verify GREEN**

Run:

```bash
bash scripts/test-session.sh
bash scripts/e2e.sh
```

Expected: `SESSION TESTS GREEN` and `GATE GREEN`.

- [ ] **Step 7: Close the feature**

Flip only M15-001 to `passing`, prepend the session entry to `PROGRESS.md`, and commit:

```bash
git add skills/harness-session/SKILL.md skills/harness-session/scripts/context.sh scripts/test-session.sh scripts/e2e.sh ARCHITECTURE.md FEATURES.json PROGRESS.md

git commit -m "feat(M15-001): add efficient harness session startup"
```

---

### Task 2: M15-002 — Concise full-gate runner with retained evidence

**Files:**
- Create: `skills/harness-session/scripts/run-gate.sh`
- Modify: `scripts/test-session.sh`
- Modify: `skills/harness-session/SKILL.md`
- Modify: `scripts/e2e.sh`
- Modify: `FEATURES.json`
- Modify: `PROGRESS.md`

**Interfaces:**
- Consumes: phase `baseline|final`, optional target directory, target `scripts/e2e.sh`, `${TMPDIR:-/tmp}`.
- Produces: `run-gate.sh <baseline|final> [TARGET_DIR]`; full combined log; concise success/failure report; original gate exit code.

- [ ] **Step 1: Add failing gate-wrapper fixtures**

Extend `scripts/test-session.sh` with fake target gates:

```bash
# success: 300 noisy lines remain in the log, terminal report stays bounded
success_out="$(bash "$RUN_GATE" baseline "$WORK/green")"
echo "$success_out" | grep -q 'GATE: green (baseline)'
log="$(echo "$success_out" | sed -n 's/^FULL_LOG: //p')"
[ "$(wc -l < "$log")" -ge 301 ]
[ "$(printf '%s\n' "$success_out" | wc -l)" -le 25 ]

# failure: wrapper preserves exit 7 and exposes the failure tail
rc=0
bash "$RUN_GATE" final "$WORK/red" >"$WORK/red.out" 2>&1 || rc=$?
[ "$rc" -eq 7 ]
grep -q 'GATE: red (final)' "$WORK/red.out"
grep -q 'intentional failure sentinel' "$WORK/red.out"

# invalid phase is usage error 2
rc=0
bash "$RUN_GATE" middle "$WORK/green" >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 2 ]
```

- [ ] **Step 2: Run the fixture test to verify RED**

Run `bash scripts/test-session.sh`.

Expected: non-zero because `run-gate.sh` does not exist.

- [ ] **Step 3: Implement `run-gate.sh`**

Implement Bash 3.2-compatible phase validation, timestamped log creation, duration measurement with `date +%s`, and `set +e` around the target gate so its status can be captured. Success prints at most the final 20 non-empty log lines; failure prints the final 80 lines. Always print the absolute full-log path and return the target status.

Do not parse framework-specific Jest, pytest, npm, or Gradle output. The cap is the generic token-control mechanism.

- [ ] **Step 4: Switch the skill to the wrapper**

Update `SKILL.md` so clean starts use:

```bash
bash <plugin>/skills/harness-session/scripts/run-gate.sh baseline <target>
```

and every completion uses:

```bash
bash <plugin>/skills/harness-session/scripts/run-gate.sh final <target>
```

On red, inspect more of `FULL_LOG` only if the printed tail is insufficient. State explicitly that concise output does not permit ignoring a non-zero gate.

- [ ] **Step 5: Verify and close**

Run `bash scripts/test-session.sh` and `bash scripts/e2e.sh`; flip only M15-002, update `PROGRESS.md`, and commit:

```bash
git add skills/harness-session/scripts/run-gate.sh skills/harness-session/SKILL.md scripts/test-session.sh scripts/e2e.sh FEATURES.json PROGRESS.md

git commit -m "feat(M15-002): summarize full gate output"
```

---

### Task 3: M15-003 — Protocol, setup template, lifecycle documentation, and dogfood architecture

**Files:**
- Modify: `skills/harness-setup/templates/harness-protocol.md`
- Modify: `skills/harness-setup/templates/AGENTS.md.tmpl`
- Modify: `README.md`
- Modify: `ARCHITECTURE.md`
- Modify: `scripts/e2e.sh`
- Modify: `FEATURES.json`
- Modify: `PROGRESS.md`

**Interfaces:**
- Consumes: the shipped `harness-session` skill and scripts from M15-001/M15-002.
- Produces: agent-neutral session rules inherited by new repositories, plugin usage documentation, updated architectural map.

- [ ] **Step 1: Add failing documentation checks to the root gate**

Require these stable single-line phrases:

```bash
grep -q 'CONTINUING INTERRUPTED FEATURE' "$PROTO"
grep -q 'scripts/preflight.sh' "$PROTO"
grep -q 'tracked by another failing or deferred feature' "$PROTO"
grep -q 'harness-session' "$TMPL_DIR/AGENTS.md.tmpl"
grep -q 'harness-session' README.md
grep -q 'run-gate.sh' README.md
grep -q 'harness-session' ARCHITECTURE.md
```

Run `bash scripts/e2e.sh` and expect failure on the first missing phrase.

- [ ] **Step 2: Update protocol section 2 without renumbering later sections**

Revise §2.1–§2.5 to require bounded deterministic recovery when the session skill is available, check git status before claiming a clean baseline, define the three-way clean/continuation/ambiguous branch, run optional target `scripts/preflight.sh`, use concise gate presentation with a retained full log, and prohibit expanding an exit-zero tracked warning into another feature.

Retain the portable manual commands as the fallback for agents that do not have the plugin. Preserve the mandatory final gate and one-feature discipline.

- [ ] **Step 3: Update the setup map and README**

Add `harness-session` to `AGENTS.md.tmpl` as an optional installed-plugin accelerator, not as a repository file dependency. Add lifecycle and usage examples to README:

```text
Implement M1-004 following the harness.
Continue the current harness feature.
```

Document that orchestration and log compression live in the plugin; project-specific readiness may optionally live in `scripts/preflight.sh`.

- [ ] **Step 4: Complete architecture dogfood**

Update the system diagram, module map, key data flow, and M15 subsystem note. Record invariants: status remains the sole deterministic feature selector; session scripts are read-only except executing the target's own commands; complete gate logs are retained; dirty ownership is never inferred mechanically.

- [ ] **Step 5: Verify and close**

Run `bash scripts/e2e.sh`; flip only M15-003, update `PROGRESS.md`, and commit:

```bash
git add skills/harness-setup/templates/harness-protocol.md skills/harness-setup/templates/AGENTS.md.tmpl README.md ARCHITECTURE.md scripts/e2e.sh FEATURES.json PROGRESS.md

git commit -m "docs(M15-003): integrate efficient coding sessions"
```

---

### Task 4: M15-004 — Release 1.6.0 and close the milestone

**Files:**
- Modify: `.claude-plugin/plugin.json`
- Modify: `.claude-plugin/marketplace.json`
- Modify: `package.json`
- Modify: `scripts/e2e.sh`
- Modify: `FEATURES.json`
- Modify: `PROGRESS.md`
- Move: `docs/plans/active/2026-09-09-m15-efficient-coding-sessions.md` to `docs/plans/completed/2026-09-09-m15-efficient-coding-sessions.md`

**Interfaces:**
- Consumes: completed M15-001 through M15-003.
- Produces: installable plugin version `1.6.0` with all manifest/package versions synchronized.

- [ ] **Step 1: Add the failing version check**

Extend `scripts/e2e.sh` so jq asserts all three versions are identical. The existing gate already checks the two plugin manifests; this closes the uncovered `package.json` leg. Version files are configuration, so this task uses the existing synchronization gate rather than manufacturing a production-code RED failure.

- [ ] **Step 2: Bump synchronized versions**

Set:

```json
"version": "1.6.0"
```

in `plugin.json`, `marketplace.json`'s first plugin entry, and `package.json`. Do not change dependency or package metadata.

- [ ] **Step 3: Run final verification**

Run:

```bash
bash scripts/e2e.sh
bash skills/harness-session/scripts/context.sh .
```

Expected: gate green; context reports M15 4/4 passing and no next failing feature after the status flip.

- [ ] **Step 4: Close the milestone**

Flip only M15-004 to passing, move the plan to completed, prepend the final progress entry, re-run `bash scripts/e2e.sh`, and commit:

```bash
git add .claude-plugin/plugin.json .claude-plugin/marketplace.json package.json FEATURES.json PROGRESS.md docs/plans/active/2026-09-09-m15-efficient-coding-sessions.md docs/plans/completed/2026-09-09-m15-efficient-coding-sessions.md scripts/e2e.sh

git commit -m "feat(M15-004): release efficient sessions in 1.6.0"
```

The owner opens and merges the pull request; implementation agents do not merge it locally.

## Self-review

- Spec coverage: every approved behavior maps to M15-001, M15-002, or M15-003; M15-004 handles release mechanics only.
- Scope: generic orchestration stays in the plugin; target service checks remain optional and project-owned.
- Selection consistency: `context.sh` delegates to `harness-status`; it does not create a second jq selector for user-facing output.
- Safety: ambiguous dirty trees stop for human input; final verification remains mandatory.
- Evidence: fixture tests assert exit codes, bounded output, retained logs, and non-mutating context recovery.
- Placeholders: none; paths, commands, output phrases, and expected failures are explicit.
