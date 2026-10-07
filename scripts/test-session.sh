#!/usr/bin/env bash
# Fixture tests for the harness-session skill's scripts:
# context.sh (bounded read-only context) and run-gate.sh (concise gate wrapper).
set -euo pipefail
cd "$(dirname "$0")/.."

CONTEXT="skills/harness-session/scripts/context.sh"
RUN_GATE="skills/harness-session/scripts/run-gate.sh"

fail() { echo "SESSION-TEST FAIL: $*" >&2; exit 1; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# builds a harnessed git repo fixture at $1 with a failing feature, a
# matching active plan, and six commits (proves the five-commit cap)
make_repo() {
  local dir="$1"
  mkdir -p "$dir/docs/plans/active"
  cat > "$dir/FEATURES.json" <<'JSON'
{
  "milestones": { "0": "Skeleton", "2": "Widgets" },
  "features": [
    { "id": "M0-001", "milestone": 0, "title": "boot", "status": "passing", "verify": "x" },
    { "id": "M2-001", "milestone": 2, "title": "widget core", "status": "failing", "verify": "test widget passes" }
  ]
}
JSON
  printf '## 2026-01-02 -- session 2\n- Done: M0-001.\n\n## 2026-01-01 -- session 1\n- Setup.\n' > "$dir/PROGRESS.md"
  printf '# Plan\nCovers M2-001.\n' > "$dir/docs/plans/active/m2.md"
  git -C "$dir" init -q -b main
  git -C "$dir" -c user.email=t@t -c user.name=t add -A
  git -C "$dir" -c user.email=t@t -c user.name=t commit -qm "seed 1"
  local i
  for i in 2 3 4 5 6; do
    printf 'v%s\n' "$i" >> "$dir/tracked.txt"
    git -C "$dir" -c user.email=t@t -c user.name=t add tracked.txt
    git -C "$dir" -c user.email=t@t -c user.name=t commit -qm "seed $i"
  done
}

# 1. bare directory: delegates to status.sh and exits 3
mkdir "$WORK/bare"
rc=0; out="$(bash "$CONTEXT" "$WORK/bare")" || rc=$?
[ "$rc" -eq 3 ] || fail "bare dir: expected exit 3, got $rc"
echo "$out" | grep -q 'HARNESS NOT INITIALIZED' || fail "bare dir: missing NOT INITIALIZED line"

# 2. broken FEATURES.json: delegates to status.sh and exits 2
mkdir "$WORK/broken"
echo '{ nope' > "$WORK/broken/FEATURES.json"
: > "$WORK/broken/PROGRESS.md"
rc=0; out="$(bash "$CONTEXT" "$WORK/broken")" || rc=$?
[ "$rc" -eq 2 ] || fail "broken JSON: expected exit 2, got $rc"
echo "$out" | grep -q 'harness-audit' || fail "broken JSON: must point at harness-audit"

# 3. clean harnessed repo: selected feature, five commits only, matching
#    plan, no preflight, and only the newest PROGRESS entry
make_repo "$WORK/repo"
out="$(bash "$CONTEXT" "$WORK/repo")" || fail "clean repo: expected exit 0"
echo "$out" | grep -q 'NEXT: M2-001' || fail "clean repo: wrong next feature"
echo "$out" | grep -q 'WORKTREE: clean' || fail "clean repo: worktree should be clean"
echo "$out" | grep -q 'PLAN: docs/plans/active/m2.md' || fail "clean repo: missing plan match"
echo "$out" | grep -q 'PREFLIGHT: absent' || fail "clean repo: preflight should be absent"
echo "$out" | grep -q 'seed 6' || fail "clean repo: newest commit missing"
echo "$out" | grep -q 'seed 2' || fail "clean repo: five commits should reach seed 2"
if echo "$out" | grep -q 'seed 1'; then fail "clean repo: commit log leaked beyond five"; fi
echo "$out" | grep -q 'session 2' || fail "clean repo: last-session extract missing"
if echo "$out" | grep -q 'session 1'; then fail "clean repo: last-session extract leaked older entries"; fi

# 4. dirty worktree: reports facts, not ownership
printf 'change\n' >> "$WORK/repo/tracked.txt"
out="$(bash "$CONTEXT" "$WORK/repo")" || fail "dirty repo: expected exit 0"
echo "$out" | grep -q 'WORKTREE: dirty' || fail "dirty repo: worktree should be dirty"
echo "$out" | grep -q ' M tracked.txt' || fail "dirty repo: missing git status line"

# 5. executable target preflight is discovered, not executed
mkdir -p "$WORK/repo/scripts"
printf '#!/usr/bin/env bash\nexit 0\n' > "$WORK/repo/scripts/preflight.sh"
chmod +x "$WORK/repo/scripts/preflight.sh"
out="$(bash "$CONTEXT" "$WORK/repo")" || fail "preflight repo: expected exit 0"
echo "$out" | grep -q 'PREFLIGHT: scripts/preflight.sh' || fail "preflight repo: not discovered"

# 5b. harness-upgrade notices: legacy gate and drifted/missing protocol copy
#     are reported as facts; the current shapes report as fine
out="$(bash "$CONTEXT" "$WORK/repo")" || fail "upgrade repo: expected exit 0"
echo "$out" | grep -q 'GATE_OUTPUT: no scripts/e2e.sh' || fail "upgrade repo: missing-gate line absent"
echo "$out" | grep -q 'PROTOCOL: missing' || fail "upgrade repo: missing-protocol line absent"
printf '#!/usr/bin/env bash\ntrue\n' > "$WORK/repo/scripts/e2e.sh"
mkdir -p "$WORK/repo/docs/agents"
cp skills/harness-initial-setup/templates/harness-protocol.md "$WORK/repo/docs/agents/harness-protocol.md"
echo "local note" >> "$WORK/repo/docs/agents/harness-protocol.md"
out="$(bash "$CONTEXT" "$WORK/repo")" || fail "legacy repo: expected exit 0"
echo "$out" | grep -q 'GATE_OUTPUT: unbounded' || fail "legacy repo: unbounded gate not noticed"
echo "$out" | grep -q 'PROTOCOL: outdated' || fail "legacy repo: drifted protocol not noticed"
cp skills/harness-initial-setup/templates/harness-protocol.md "$WORK/repo/docs/agents/harness-protocol.md"
out="$(bash "$CONTEXT" "$WORK/repo")" || fail "pre-split repo: expected exit 0"
echo "$out" | grep -q 'PROTOCOL: outdated.*harness-protocol-planning.md' || fail "pre-split repo: missing protocol parts not noticed (M28-002)"
echo "$out" | grep -q 'UPGRADE: offer' || fail "legacy repo: no upgrade offer line"
printf '#!/usr/bin/env bash\necho "FULL_LOG: x"\n' > "$WORK/repo/scripts/e2e.sh"
cp skills/harness-initial-setup/templates/harness-protocol*.md "$WORK/repo/docs/agents/"
out="$(bash "$CONTEXT" "$WORK/repo")" || fail "current repo: expected exit 0"
echo "$out" | grep -q 'GATE_OUTPUT: bounded' || fail "current repo: bounded gate not recognized"
echo "$out" | grep -q 'PROTOCOL: current' || fail "current repo: matching protocol not recognized"
echo "$out" | grep -q 'UPGRADE: none' || fail "current repo: expected no upgrade offer"

# 5c. parallel lanes: computed from declared depends_on/paths, never inferred
# builds a repo at $1 whose FEATURES.json has feature entries $2 (JSON array)
make_lanes_repo() {
  local dir="$1"
  mkdir -p "$dir"
  printf '{"milestones":{"1":"A","2":"B"},"features":%s}\n' "$2" > "$dir/FEATURES.json"
  printf '## s1\n' > "$dir/PROGRESS.md"
  git -C "$dir" init -q -b main
  git -C "$dir" -c user.email=t@t -c user.name=t add -A
  git -C "$dir" -c user.email=t@t -c user.name=t commit -qm seed
}
lanes() { bash "$CONTEXT" "$1" | grep '^PARALLEL:'; }
f() { # id milestone status depends_on paths
  printf '{"id":"%s","milestone":%s,"title":"t","status":"%s","verify":"v"%s%s}' \
    "$1" "$2" "$3" "${4:+,\"depends_on\":$4}" "${5:+,\"paths\":$5}"
}
make_lanes_repo "$WORK/l-disjoint" "[$(f M1-000 1 passing '[]' '["x/"]'),$(f M1-001 1 failing '["M1-000"]' '["src/a/**"]'),$(f M1-002 1 failing '[]' '["src/b/*.js"]'),$(f M2-001 2 failing '[]' '["src/c/"]')]"
[ "$(lanes "$WORK/l-disjoint")" = 'PARALLEL: M1-001 M1-002' ] || fail "lanes: disjoint same-milestone features not listed"
make_lanes_repo "$WORK/l-dep" "[$(f M1-001 1 failing '[]' '["src/a/"]'),$(f M1-002 1 failing '["M1-001"]' '["src/b/"]')]"
[ "$(lanes "$WORK/l-dep")" = 'PARALLEL: none' ] || fail "lanes: dependency on a failing feature must be sequential"
make_lanes_repo "$WORK/l-overlap" "[$(f M1-001 1 failing '[]' '["src/"]'),$(f M1-002 1 failing '[]' '["src/b/**"]')]"
[ "$(lanes "$WORK/l-overlap")" = 'PARALLEL: none' ] || fail "lanes: overlapping path prefixes must be sequential"
make_lanes_repo "$WORK/l-missing" "[$(f M1-001 1 failing '' '["src/a/"]'),$(f M1-002 1 failing '[]' '["src/b/"]')]"
[ "$(lanes "$WORK/l-missing")" = 'PARALLEL: none' ] || fail "lanes: missing fields on NEXT must be sequential"
make_lanes_repo "$WORK/l-cap" "[$(f M1-001 1 failing '[]' '["a/"]'),$(f M1-002 1 failing '[]' '["b/"]'),$(f M1-003 1 failing '[]' '["c/"]'),$(f M1-004 1 failing '[]' '["d/"]')]"
[ "$(lanes "$WORK/l-cap")" = 'PARALLEL: M1-001 M1-002 M1-003' ] || fail "lanes: cap of 3 not applied"

# 5d. evaluator fields (M18): review is not-done and never NEXT; fields accepted;
#     features without them behave exactly as before
make_lanes_repo "$WORK/rv" "[$(f M1-001 1 review '[]' '["a/"]' | sed 's/}$/,"evaluate":"ui","bar":"matches the mockup","eval_attempts":1}/'),$(f M1-002 1 failing '["M1-001"]' '["b/"]'),$(f M1-003 1 failing '[]' '["c/"]')]"
out="$(bash "$CONTEXT" "$WORK/rv")" || fail "review repo: expected exit 0"
echo "$out" | grep -q 'NEXT: M1-001' && fail "review repo: a review feature must never be NEXT"
echo "$out" | grep -q 'NEXT: M1-002' || fail "review repo: NEXT ignores depends_on as before; expected M1-002"
echo "$out" | grep -q 'M1: 0/3 passing' || fail "review repo: review must not count as passing"
echo "$out" | grep -q 'review 1' || fail "review repo: totals must show review count"
echo "$out" | grep -q 'REVIEW: M1-001' || fail "review repo: awaiting-evaluator line missing"
echo "$out" | grep -q 'PARALLEL: none' || fail "review repo: dependency on review must stay sequential"
out="$(bash "$CONTEXT" "$WORK/l-disjoint")"
echo "$out" | grep -Eq 'review|REVIEW' && fail "no review features: output must be unchanged"
echo "$out" | grep -q 'superseded 0$' || fail "no review features: totals line must end at superseded"

# builds a target fixture at $1 whose scripts/e2e.sh prints $2 noisy lines
# then exits $3, with $4 appended right before exiting (failure sentinel)
make_gate_target() {
  local dir="$1" lines="$2" exit_code="$3" sentinel="${4:-}"
  mkdir -p "$dir/scripts"
  {
    echo '#!/usr/bin/env bash'
    echo "i=1; while [ \"\$i\" -le $lines ]; do echo \"noisy line \$i\"; i=\$((i+1)); done"
    [ -n "$sentinel" ] && echo "echo '$sentinel'"
    echo "exit $exit_code"
  } > "$dir/scripts/e2e.sh"
  chmod +x "$dir/scripts/e2e.sh"
}

# 6. success gate: full log retains everything, terminal report stays bounded
make_gate_target "$WORK/green" 300 0
success_out="$(bash "$RUN_GATE" baseline "$WORK/green")" || fail "green gate: expected exit 0"
echo "$success_out" | grep -q 'GATE: green (baseline)' || fail "green gate: missing status line"
log="$(echo "$success_out" | sed -n 's/^FULL_LOG: //p')"
[ -n "$log" ] || fail "green gate: missing FULL_LOG line"
[ "$(wc -l < "$log")" -ge 301 ] || fail "green gate: full log lost lines"
[ "$(printf '%s\n' "$success_out" | wc -l)" -le 25 ] || fail "green gate: terminal report exceeded 25 lines"

# 7. failure gate: wrapper preserves the target's exit code and exposes the tail
make_gate_target "$WORK/red" 3 7 'intentional failure sentinel'
rc=0
bash "$RUN_GATE" final "$WORK/red" >"$WORK/red.out" 2>&1 || rc=$?
[ "$rc" -eq 7 ] || fail "red gate: expected exit 7, got $rc"
grep -q 'GATE: red (final)' "$WORK/red.out" || fail "red gate: missing status line"
grep -q 'intentional failure sentinel' "$WORK/red.out" || fail "red gate: failure tail not exposed"

# 7b. baseline reuse (M29-001): a green run fingerprints the tree; a later
#     baseline on an identical clean tree (bookkeeping aside) skips the gate
R="$WORK/reuse"; mkdir -p "$R/scripts" "$R/docs/plans/active" "$R/src"
# shellcheck disable=SC2016 # the e2e.sh being written expands $(...) itself
printf 'echo ran >> "%s/runs"\nexit "$(cat "%s/code" 2>/dev/null || echo 0)"\n' "$WORK" "$WORK" > "$R/scripts/e2e.sh"
printf '{"features":[]}\n' > "$R/FEATURES.json"; printf '# P\n' > "$R/PROGRESS.md"; printf 'a\n' > "$R/src/a.txt"
printf '# plan\n' > "$R/docs/plans/active/p.md"
rg() { git -C "$R" -c user.email=t@t -c user.name=t "$@"; }
rg init -q -b main; rg add -A; rg commit -qm seed
runs() { wc -l < "$WORK/runs" 2>/dev/null | tr -d ' ' || echo 0; }
base() { bash "$RUN_GATE" baseline "$R"; }
bash "$RUN_GATE" final "$R" >/dev/null || fail "reuse: first final gate should be green"
[ "$(runs)" = 1 ] || fail "reuse: final gate did not run"
[ -z "$(git -C "$R" status --porcelain)" ] || fail "reuse: run-gate wrote inside the worktree"
printf -- '- session\n' >> "$R/PROGRESS.md"; printf 'done\n' >> "$R/docs/plans/active/p.md"; rg add -A; rg commit -qm bookkeeping
out="$(base)" || fail "reuse: baseline should be green"
grep -q '^GATE: green (baseline reused' <<< "$out" || fail "reuse: bookkeeping-only commit must reuse the green run"
[ "$(runs)" = 1 ] || fail "reuse: the gate ran although the tree was proven"
expect_run() { # $1 label: the next baseline must run the gate
  local before; before="$(runs)"
  base >/dev/null 2>&1 || true
  [ "$(runs)" -gt "$before" ] || fail "reuse: $1 must run the gate"
}
printf 'b\n' >> "$R/src/a.txt"; rg commit -qam code; expect_run "a changed code file"
base >/dev/null; printf '{"features":[1]}\n' > "$R/FEATURES.json"; rg commit -qam feat; expect_run "a changed FEATURES.json"
base >/dev/null; printf 'new\n' > "$R/src/new.txt"; rg add -A; rg commit -qm new; expect_run "a new file"
base >/dev/null; printf 'dirty\n' >> "$R/src/a.txt"; expect_run "a dirty tree"; rg checkout -q -- src/a.txt
base >/dev/null; HARNESS_GATE_REUSE=0 expect_run "HARNESS_GATE_REUSE=0"
echo 3 > "$WORK/code"; bash "$RUN_GATE" final "$R" >/dev/null 2>&1 || true; rm -f "$WORK/code"
expect_run "a red last run"

# 8. invalid phase: usage error, exit 2
rc=0
bash "$RUN_GATE" middle "$WORK/green" >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 2 ] || fail "invalid phase: expected exit 2, got $rc"

# 9. status.sh --skip / context.sh --skip (M20-001)
STATUS="skills/harness-status/scripts/status.sh"
mkdir -p "$WORK/skip"
cat > "$WORK/skip/FEATURES.json" <<'JSON'
{
  "milestones": { "0": "Skeleton", "2": "Widgets", "3": "Gadgets" },
  "features": [
    { "id": "M0-001", "milestone": 0, "title": "boot", "status": "passing", "verify": "x" },
    { "id": "M2-001", "milestone": 2, "title": "widget core", "status": "failing", "verify": "v1" },
    { "id": "M2-002", "milestone": 2, "title": "widget ui", "status": "failing", "depends_on": ["M2-001"], "verify": "v2" },
    { "id": "M2-003", "milestone": 2, "title": "widget docs", "status": "failing", "verify": "v3" },
    { "id": "M2-004", "milestone": 2, "title": "widget polish", "status": "failing", "depends_on": ["M2-002"], "verify": "v4" },
    { "id": "M3-001", "milestone": 3, "title": "gadget", "status": "failing", "depends_on": ["M0-001"], "verify": "v5" }
  ]
}
JSON
printf '## 2026-01-02 -- session 2\n- Done: M0-001.\n\n## 2026-01-01 -- session 1\n- Setup.\n' > "$WORK/skip/PROGRESS.md"

# 9a. without --skip: byte-identical to the pre-M20 output
cat > "$WORK/skip.golden" <<'EOF'
HARNESS STATUS

== Milestones ==
M0: 1/1 passing — Skeleton
M2: 0/4 passing — Widgets
M3: 0/1 passing — Gadgets

== Totals ==
passing 1, failing 5, deferred 0, superseded 0

== Next feature (lowest milestone, then lowest id, among failing) ==
NEXT: M2-001 — widget core
  verify: v1

== Last session (PROGRESS.md) ==
## 2026-01-02 -- session 2
- Done: M0-001.

EOF
bash "$STATUS" "$WORK/skip" > "$WORK/skip.out"
cmp -s "$WORK/skip.out" "$WORK/skip.golden" || fail "--skip: output without --skip changed"
: > "$WORK/skip.none"
bash "$STATUS" --skip "$WORK/skip.none" "$WORK/skip" | cmp -s - "$WORK/skip.golden" \
  || fail "--skip: an empty skip file must not change the output"

# 9b. skipping M2-001 excludes it, its transitive dependents, and the
#     dependency-less M2-003 after it; the explicit-deps M3-001 stays eligible
echo M2-001 > "$WORK/skip.ids"
out="$(bash "$STATUS" --skip "$WORK/skip.ids" "$WORK/skip")" || fail "--skip: expected exit 0"
echo "$out" | grep -q '^SKIPPED: M2-001 — listed' || fail "--skip: listed id not reported"
echo "$out" | grep -q '^SKIPPED: M2-002 — depends on M2-001' || fail "--skip: direct dependent not skipped"
echo "$out" | grep -q '^SKIPPED: M2-003 — depends on M2-001' || fail "--skip: dependency-less successor not skipped"
echo "$out" | grep -q '^SKIPPED: M2-004 — depends on M2-002' || fail "--skip: transitive dependent not skipped"
[ "$(echo "$out" | grep -c '^SKIPPED: ')" -eq 4 ] || fail "--skip: expected exactly four SKIPPED lines"
echo "$out" | grep -q '^NEXT: M3-001 — gadget' || fail "--skip: NEXT should be M3-001"

# 9c. everything left excluded → NEXT: none
printf 'M2-001\nM3-001\n' > "$WORK/skip.all"
out="$(bash "$STATUS" --skip "$WORK/skip.all" "$WORK/skip")" || fail "--skip all: expected exit 0"
echo "$out" | grep -q '^NEXT: none' || fail "--skip all: expected NEXT: none"
if echo "$out" | grep -q '^NEXT: M'; then fail "--skip all: a feature was still selected"; fi

# 9d. context.sh passes --skip through (NEXT, PLAN follow the eligible feature)
git -C "$WORK/skip" init -q -b main
git -C "$WORK/skip" -c user.email=t@t -c user.name=t add -A
git -C "$WORK/skip" -c user.email=t@t -c user.name=t commit -qm seed
out="$(bash "$CONTEXT" --skip "$WORK/skip.ids" "$WORK/skip")" || fail "context --skip: expected exit 0"
echo "$out" | grep -q '^NEXT: M3-001' || fail "context --skip: NEXT not passed through"
echo "$out" | grep -q 'PLAN: none mentioning M3-001' || fail "context --skip: PLAN should follow the eligible feature"
echo "$out" | grep -q '^PARALLEL: none' || fail "context --skip: PARALLEL should be none"

echo "SESSION TESTS GREEN"
