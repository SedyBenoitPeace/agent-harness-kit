#!/usr/bin/env bash
# Fixture tests for skills/harness-handoff/scripts/handoff.sh.
# Fixtures are tiny git repos: a clean tree is the core ritual check.
set -euo pipefail
cd "$(dirname "$0")/.."

HANDOFF="skills/harness-handoff/scripts/handoff.sh"

fail() { echo "HANDOFF-TEST FAIL: $*" >&2; exit 1; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# builds a harnessed git repo fixture at $1 with a gate that exits $2
make_repo() {
  local dir="$1" gate_exit="$2"
  mkdir -p "$dir/scripts"
  cat > "$dir/FEATURES.json" <<'JSON'
{
  "milestones": { "0": "Skeleton", "1": "Core" },
  "features": [
    { "id": "M0-001", "milestone": 0, "title": "boot", "status": "passing", "verify": "x" },
    { "id": "M1-001", "milestone": 1, "title": "core A", "status": "failing", "verify": "test A passes" },
    { "id": "M1-002", "milestone": 1, "title": "core B", "status": "failing", "verify": "test B passes" }
  ]
}
JSON
  printf '## 2026-01-02 -- session 2\n- Done: M0-001.\n' > "$dir/PROGRESS.md"
  printf '# AGENTS.md\nSession loop lives here.\n' > "$dir/AGENTS.md"
  # shellcheck disable=SC2016  # the stub must keep the literal ${GATE_LOG}
  printf '#!/usr/bin/env bash\necho call >> "${GATE_LOG:-/dev/null}"\nexit %s\n' "$gate_exit" > "$dir/scripts/e2e.sh"
  git -C "$dir" init -q
  git -C "$dir" -c user.email=t@t -c user.name=t add -A
  git -C "$dir" -c user.email=t@t -c user.name=t commit -qm fixture
}

# 1. uninitialized dir: exit 3, points at harness-initial-setup
mkdir "$WORK/bare"
rc=0; out="$(bash "$HANDOFF" "$WORK/bare")" || rc=$?
[ "$rc" -eq 3 ] || fail "bare dir: expected exit 3, got $rc"
echo "$out" | grep -q "harness-initial-setup" || fail "bare dir: must point at harness-initial-setup"

# 2. broken FEATURES.json: exit 2, points at harness-audit
make_repo "$WORK/broken" 0
echo '{ nope' > "$WORK/broken/FEATURES.json"
rc=0; out="$(bash "$HANDOFF" "$WORK/broken")" || rc=$?
[ "$rc" -eq 2 ] || fail "broken JSON: expected exit 2, got $rc"
echo "$out" | grep -q "harness-audit" || fail "broken JSON: must point at harness-audit"

# 3. missing AGENTS.md: exit 2 (prompt's entry point is gone)
make_repo "$WORK/noagents" 0
rm "$WORK/noagents/AGENTS.md"
rc=0; out="$(bash "$HANDOFF" "$WORK/noagents")" || rc=$?
[ "$rc" -eq 2 ] || fail "missing AGENTS.md: expected exit 2, got $rc"

# 4. ready repo: exit 0, READY, prompt names next feature + one-session rules
make_repo "$WORK/ready" 0
out="$(bash "$HANDOFF" "$WORK/ready")" || fail "ready repo: expected exit 0"
echo "$out" | grep -q "HANDOFF READY" || fail "ready repo: missing HANDOFF READY"
echo "$out" | grep -q "M1-001" || fail "ready repo: prompt must name next feature M1-001"
echo "$out" | grep -q "test A passes" || fail "ready repo: prompt must carry the verify criterion"
echo "$out" | grep -q "ONE coding session" || fail "ready repo: prompt missing one-session rule"
echo "$out" | grep -q "scripts/e2e.sh" || fail "ready repo: prompt must name the gate"
echo "$out" | grep -qi "STOP" || fail "ready repo: prompt must end with a stop rule"

# 5. dirty tree: exit 1, BLOCKED names uncommitted changes
make_repo "$WORK/dirty" 0
echo change >> "$WORK/dirty/AGENTS.md"
rc=0; out="$(bash "$HANDOFF" "$WORK/dirty")" || rc=$?
[ "$rc" -eq 1 ] || fail "dirty tree: expected exit 1, got $rc"
echo "$out" | grep -q "HANDOFF BLOCKED" || fail "dirty tree: missing HANDOFF BLOCKED"
echo "$out" | grep -qi "uncommitted" || fail "dirty tree: BLOCKED line must say uncommitted"

# 6. gate handling (M34-001): handoff never runs the gate by default.
# GATE_LOG records every call the stub gate receives.
export GATE_LOG="$WORK/gate-calls"; : > "$GATE_LOG"
calls() { wc -l < "$GATE_LOG" | tr -d ' '; }
GATE_SH="skills/harness-session/scripts/run-gate.sh"

# 6a. changed tree since no green run: READY, NOTE, no gate call
make_repo "$WORK/unproven" 0
out="$(bash "$HANDOFF" "$WORK/unproven")" || fail "unproven: expected exit 0"
echo "$out" | grep -q "HANDOFF READY" || fail "unproven: missing HANDOFF READY"
echo "$out" | grep -q "NOTE: gate not confirmed" || fail "unproven: missing the not-confirmed NOTE"
[ "$(calls)" -eq 0 ] || fail "unproven: handoff must not call the gate"
echo "$out" | grep -q "Confirm bash scripts/e2e.sh is green" || fail "unproven: prompt must keep the baseline step"

# 6b. unchanged since the last green gate: GATE line, no gate call
make_repo "$WORK/proven" 0
bash "$GATE_SH" final "$WORK/proven" >/dev/null || fail "proven: setup gate run failed"
[ "$(calls)" -eq 1 ] || fail "proven: setup should call the gate once"
echo '## 2026-01-03 -- session 3' >> "$WORK/proven/PROGRESS.md"   # bookkeeping is ignored
git -C "$WORK/proven" -c user.email=t@t -c user.name=t commit -qam progress
out="$(bash "$HANDOFF" "$WORK/proven")" || fail "proven: expected exit 0"
echo "$out" | grep -qF "GATE: green (last green run, unchanged)" || fail "proven: missing the GATE green line"
if echo "$out" | grep -q "NOTE: gate not confirmed"; then fail "proven: no NOTE expected"; fi
[ "$(calls)" -eq 1 ] || fail "proven: handoff must not call the gate"

# 6c. a code change after the green run: NOTE again, still no gate call
echo '# changed' >> "$WORK/proven/scripts/e2e.sh"
git -C "$WORK/proven" -c user.email=t@t -c user.name=t commit -qam change
out="$(bash "$HANDOFF" "$WORK/proven")" || fail "changed: expected exit 0"
echo "$out" | grep -q "NOTE: gate not confirmed" || fail "changed: missing the NOTE"
[ "$(calls)" -eq 1 ] || fail "changed: handoff must not call the gate"

# 6d. --run-gate: green is READY after one call; red is BLOCKED
before="$(calls)"
out="$(bash "$HANDOFF" --run-gate "$WORK/unproven")" || fail "--run-gate green: expected exit 0"
[ "$(calls)" -eq $((before + 1)) ] || fail "--run-gate green: must call the gate once"
make_repo "$WORK/redgate" 1
rc=0; out="$(bash "$HANDOFF" --run-gate "$WORK/redgate")" || rc=$?
[ "$rc" -eq 1 ] || fail "red gate: expected exit 1, got $rc"
echo "$out" | grep -q "HANDOFF BLOCKED" || fail "red gate: missing HANDOFF BLOCKED"
echo "$out" | grep -qi "gate is red" || fail "red gate: BLOCKED line must mention the gate"
make_repo "$WORK/nogate" 0; git -C "$WORK/nogate" rm -q scripts/e2e.sh
git -C "$WORK/nogate" -c user.email=t@t -c user.name=t commit -qm nogate
rc=0; out="$(bash "$HANDOFF" --run-gate "$WORK/nogate")" || rc=$?
[ "$rc" -eq 1 ] || fail "--run-gate without a gate: expected exit 1, got $rc"

# 6e. --skip-gate still works: READY, no gate call, a WARNING
before="$(calls)"
out="$(bash "$HANDOFF" --skip-gate "$WORK/redgate")" || fail "--skip-gate: expected exit 0"
echo "$out" | grep -q "WARNING" || fail "--skip-gate: must print a WARNING line"
[ "$(calls)" -eq "$before" ] || fail "--skip-gate: must not call the gate"

# 7. nothing failing: exit 0, planning prompt instead of a feature prompt
make_repo "$WORK/done" 0
jq '.features[].status = "passing"' "$WORK/done/FEATURES.json" > "$WORK/done/F.tmp"
mv "$WORK/done/F.tmp" "$WORK/done/FEATURES.json"
git -C "$WORK/done" -c user.email=t@t -c user.name=t commit -qam all-passing
out="$(bash "$HANDOFF" "$WORK/done")" || fail "all-passing: expected exit 0"
echo "$out" | grep -qi "plan" || fail "all-passing: prompt must direct to planning"
if echo "$out" | grep -q "M1-00"; then fail "all-passing: no feature ids should appear"; fi

echo "HANDOFF TESTS GREEN"
