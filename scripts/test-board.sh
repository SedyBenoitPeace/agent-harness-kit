#!/usr/bin/env bash
# Proves the run board core (M47-001): run identity and archives in
# run-start.sh, events.log writers, board.sh stages/columns and --open.
# Spec: docs/briefs/2026-11-18-run-board.md. Exit 0 = green.
# shellcheck disable=SC2016,SC2086 # literal $ in patterns; $c is a command line to split
set -euo pipefail
cd "$(dirname "$0")/.."
KIT="$PWD"
fail() { echo "BOARD TEST FAIL: $*" >&2; exit 1; }
S="$KIT/skills/harness-run/scripts"
BOARD="$S/board.sh"; START_SH="$S/run-start.sh"; DISPATCH="$S/dispatch.sh"
REPORT="$S/run-report.sh"; GATE="$KIT/skills/harness-session/scripts/run-gate.sh"
[ -f "$BOARD" ] || fail "board.sh missing"

WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
WORK="$(cd "$WORK" && pwd -P)"
R="$WORK/repo"; mkdir -p "$R"
g() { git -C "$R" "$@"; }
g init -q -b main; g config user.email t@t; g config user.name t
feat() { # id status eval_attempts
  printf '{"id":"%s","milestone":1,"title":"feature %s","status":"%s","eval_attempts":%s,"notes":"note of %s"}' "$1" "$1" "$2" "$3" "$1"
}
{
  echo '{"features":['
  feat M1-000 passing 0; echo ,
  for i in 1 2 3 4 5 6 7 8 9; do feat "M1-00$i" failing 0; [ "$i" = 9 ] || echo ,; done
  echo ']}'
} > "$R/FEATURES.json"
mkdir -p "$R/.claude/agents" "$R/scripts"
echo '---' > "$R/.claude/agents/harness-builder.md"
printf "# PROGRESS\n" > "$R/PROGRESS.md"
# the fixture's gate snapshots the board while it runs (proves "gate running")
cat > "$R/scripts/e2e.sh" <<'EOF'
[ -z "${SNAP:-}" ] || { bash "$BOARD" "$MAIN" && cp "$MAIN/.harness-run/board.html" "$SNAP"; }
exit 0
EOF
g add -A; g commit -qm seed

H="$R/.harness-run"; HTML="$H/board.html"
stage() { sed -n "s/.*data-id=\"$1\" data-stage=\"\([^\"]*\)\".*/\1/p" "${2:-$HTML}" | head -1; }
row() { grep "data-id=\"$1\"" "$HTML" | head -1; }
expect() { [ "$(stage "$1")" = "$2" ] || fail "$1: want stage '$2', got '$(stage "$1")'"; }

# --- no run: nothing is written -------------------------------------------
(cd "$R" && HARNESS_GATE_REUSE=0 bash "$GATE" baseline . >/dev/null) || fail "gate without run failed"
bash "$BOARD" "$R" >/dev/null || fail "board.sh without run must exit 0"
(cd "$R" && bash "$KIT/skills/harness-status/scripts/status.sh" . >/dev/null 2>&1; bash "$KIT/skills/harness-session/scripts/context.sh" . >/dev/null 2>&1) || true
[ ! -e "$H/events.log" ] || fail "no .harness-run/start (gate, status, context): no events.log"
[ ! -e "$HTML" ] || fail "no .harness-run/start (gate, status, context): no board.html"

# --- run-start: run-id, BOARD: line, opener once ---------------------------
COUNT="$WORK/opened"; OPENER="$WORK/opener.sh"
printf '#!/usr/bin/env bash\necho "$1" >> %q\necho opener-noise\n' "$COUNT" > "$OPENER"; chmod +x "$OPENER"
export HARNESS_BOARD_OPEN_CMD="$OPENER"
out="$(bash "$START_SH" "$R")" || fail "run-start failed"
[ "$out" = "BOARD: $HTML" ] || fail "run-start stdout must be only the BOARD: line, got: $out"
[ -f "$HTML" ] || fail "run-start: board.html missing"
[ "$(wc -l < "$COUNT")" -eq 1 ] || fail "opener must run once"
grep -qx "$HTML" "$COUNT" || fail "opener must get the absolute board path"
for c in "$KIT/skills/harness-status/scripts/status.sh ." "$KIT/skills/harness-session/scripts/context.sh ." "$KIT/skills/harness-session/scripts/run-gate.sh baseline ."; do
  rm -f "$HTML"; (cd "$R" && HARNESS_GATE_REUSE=0 bash $c >/dev/null 2>&1) || true
  [ -f "$HTML" ] || fail "${c%% *} must refresh the board during a run"
done
[ "$(wc -l < "$COUNT")" -eq 1 ] || fail "later calls must not reopen the board"
rid1="$(cat "$H/run-id")"
[[ "$rid1" =~ ^[0-9]+-[0-9]+$ ]] || fail "run-id must be <epoch>-<pid>, got $rid1"
grep -q "^[0-9]* run-start - $(g rev-parse HEAD)$" "$H/events.log" || fail "run-start event missing"
out="$(bash "$BOARD" "$R" --open)"; [ "$out" = "BOARD: $HTML" ] || fail "--open must print BOARD:"
[ "$(wc -l < "$COUNT")" -eq 1 ] || fail "--open twice in one run must not reopen"
[ -z "$(bash "$BOARD" "$R")" ] || fail "board.sh without --open prints nothing"

# --- dispatch writes an event; the row is building -------------------------
d_out="$(bash "$DISPATCH" "$R" claude M1-001)" || fail "dispatch failed"
[ "$d_out" = "$(printf 'AGENT: harness-builder\nSIZE: -')" ] || fail "dispatch stdout changed: $d_out"
grep -q "^[0-9]* dispatch M1-001 claude harness-builder -$" "$H/events.log" || fail "dispatch event (claude) missing"
[ "$(wc -l < "$COUNT")" -eq 1 ] || fail "dispatch must not reopen the board"
bash "$BOARD" "$R"; expect M1-001 building; expect M1-002 queued
row M1-001 | grep -q 'claude harness-builder' || fail "agent column missing"
# exit 3 (no agent file) writes no event
set +e; (bash "$DISPATCH" "$R" codex M1-002 >/dev/null 2>&1); rc=$?; set -e
[ "$rc" -eq 3 ] || fail "dispatch without codex agents must still exit 3"
! grep -q 'dispatch M1-002' "$H/events.log" || fail "a refused dispatch writes no event"

# --- gate in a lane worktree: event in the main log, row gate running ------
bash "$DISPATCH" "$R" claude M1-002 >/dev/null
L="$WORK/repo-M1-002"; g worktree add -q -b lane/M1-002 "$L"
(cd "$L" && SNAP="$WORK/snap.html" BOARD="$BOARD" MAIN="$R" HARNESS_GATE_REUSE=0 bash "$GATE" final . >/dev/null) || fail "lane gate failed"
grep -q "^[0-9]* gate M1-002 final start$" "$H/events.log" || fail "lane gate start event missing in main events.log"
grep -q "^[0-9]* gate M1-002 final green$" "$H/events.log" || fail "lane gate green event missing"
[ ! -e "$L/.harness-run" ] || fail "lane gate must not write run state in the lane"
[ "$(stage M1-002 "$WORK/snap.html")" = "gate running" ] || fail "M1-002: want 'gate running' during the gate, got '$(stage M1-002 "$WORK/snap.html")'"
bash "$BOARD" "$R"; expect M1-002 building; row M1-002 | grep -q 'lane' || fail "lane tag missing"
row M1-002 | grep -q 'final green' || fail "gate column while building missing"

# --- results: review, same-second tie, rework, redispatch, skip, passing ---
now=$(date +%s); mkdir -p "$H/results"
res() { echo "SESSION: $1 · $2 · gate $3 · abc1234" > "$H/results/$1.txt"; }
res M1-003 review green; expect_after() { bash "$BOARD" "$R"; expect "$@"; }
expect_after M1-003 review
row M1-003 | grep -q 'gate green' || fail "gate column from the result missing"
# same second: dispatch event and result share the timestamp -> current
echo "$now dispatch M1-004 claude harness-builder -" >> "$H/events.log"
res M1-004 review green; touch -t "$(date -r "$now" +%Y%m%d%H%M.%S 2>/dev/null || date -d "@$now" +%Y%m%d%H%M.%S)" "$H/results/M1-004.txt"
expect_after M1-004 review
# stale: a result older than its latest dispatch is ignored
res M1-005 review green; echo "$((now + 100)) dispatch M1-005 claude harness-builder -" >> "$H/events.log"
expect_after M1-005 building
row M1-005 | grep -q 'gate green' && fail "a stale result must not fill the gate column"
# rework: evaluator sent it back (failing, eval_attempts 1); its old review result no longer counts
jq '(.features[] | select(.id == "M1-006")) |= (.eval_attempts = 1)' "$R/FEATURES.json" > "$WORK/f" && mv "$WORK/f" "$R/FEATURES.json"
echo "$((now - 50)) dispatch M1-006 claude harness-builder -" >> "$H/events.log"; res M1-006 review green
expect_after M1-006 "rework (1/2)"
echo "$((now + 100)) dispatch M1-006 claude harness-builder -" >> "$H/events.log"
expect_after M1-006 building
res M1-007 blocked red; expect_after M1-007 blocked
# merge pending: the result says passing, FEATURES.json not yet
res M1-007 passing green; expect_after M1-007 merging; res M1-007 blocked red
echo M1-008 >> "$H/skip"; expect_after M1-008 skipped
jq '(.features[] | select(.id == "M1-009")) |= (.status = "passing")' "$R/FEATURES.json" > "$WORK/f" && mv "$WORK/f" "$R/FEATURES.json"
expect_after M1-009 passing
grep -q 'data-id="M1-000"' "$HTML" && fail "a feature passing at run start must not be shown"

# --- cost and tokens; header --------------------------------------------------
echo "M1-003 1.25" >> "$H/cost.log"; echo "M1-003 0.50" >> "$H/cost.log"
echo "M1-004 codex gpt-x 1000000 10 500000" >> "$H/usage.log"
echo "M1-004/second-opinion codex - 2000 0 1000" >> "$H/usage.log"
bash "$BOARD" "$R"
row M1-003 | grep -q '\$1\.75' || fail "cost.log dollars missing"
row M1-004 | grep -q '1\.5M tok' || fail "usage.log tokens missing"
row M1-004 | grep -q 'gpt-x' || fail "model from usage.log missing"
grep -q '<h1>repo <small>main</small>' "$HTML" || fail "header repo/branch missing"
grep -q 'http-equiv\|location.reload' "$HTML" || fail "page must reload itself"
grep -q 'sessionStorage' "$HTML" || fail "expanded rows must survive reloads"
grep -q 'prefers-color-scheme' "$HTML" || fail "dark mode missing"
! grep -qE '(src|href)="https?:' "$HTML" || fail "page must be self-contained"
grep -q 'note of M1-003' "$HTML" || fail "expanded row must show notes"
grep -q 'SESSION: M1-003' "$HTML" || fail "expanded row must show the result"
echo "$now opinion M1-003 codex PASS" >> "$H/events.log"; bash "$BOARD" "$R"
grep -q 'codex PASS' "$HTML" || fail "expanded row must show opinions"
jq '(.features[] | select(.id == "M1-007")) |= (.notes = "<script>alert(1)</script>")' "$R/FEATURES.json" > "$WORK/f" && mv "$WORK/f" "$R/FEATURES.json"
bash "$BOARD" "$R"; grep -q '<script>alert' "$HTML" && fail "html must be escaped"
grep -q '&lt;script&gt;alert' "$HTML" || fail "escaped notes missing"

# --- archives per run-id on one HEAD; HARNESS_BOARD_OPEN=0 -------------------
out="$(bash "$START_SH" "$R")"; [ "$out" = "BOARD: $HTML" ] || fail "second run-start BOARD line"
[ "$(wc -l < "$COUNT")" -eq 2 ] || fail "second run must open once more"
rid2="$(cat "$H/run-id")"; [ "$rid2" != "$rid1" ] || fail "run-id must change per run"
[ -f "$H/previous/$rid1/events.log" ] || fail "events.log not archived under previous/<first run-id>"
[ -f "$H/previous/$rid1/results/M1-003.txt" ] || fail "results not archived under previous/<first run-id>"
[ ! -e "$H/board-opened" ] || [ "$(cat "$H/board-opened")" = "$rid2" ] || fail "board-opened must be reset"
sum1="$(find "$H/previous/$rid1" -type f -exec cat {} + | cksum)"
echo "$(date +%s) dispatch M1-001 claude harness-builder -" >> "$H/events.log"
out="$(HARNESS_BOARD_OPEN=0 bash "$START_SH" "$R")"; [ "$out" = "BOARD: $HTML" ] || fail "HARNESS_BOARD_OPEN=0 must still print BOARD:"
[ "$(wc -l < "$COUNT")" -eq 2 ] || fail "HARNESS_BOARD_OPEN=0 must not open"
[ -f "$H/previous/$rid2/events.log" ] || fail "third run must archive under previous/<second run-id>"
[ "$(find "$H/previous/$rid1" -type f -exec cat {} + | cksum)" = "$sum1" ] || fail "first archive changed"

# --- junk board.sh: callers' stdout and exit codes stay unchanged -------------
JK="$WORK/junk"; mkdir -p "$JK"; cp -R "$KIT/skills" "$JK/skills"
callers() { # kit-root: stdout of the three callers, then their exit codes
  local k="$1" c rc
  for c in "$k/skills/harness-run/scripts/dispatch.sh $R claude M1-001" "$k/skills/harness-status/scripts/status.sh $R" "$k/skills/harness-session/scripts/context.sh $R"; do
    rc=0; (cd "$R" && bash $c 2>/dev/null) || rc=$?
    echo "rc=$rc"
  done
}
rm "$JK/skills/harness-run/scripts/board.sh"
nob="$(callers "$JK")"
printf '#!/usr/bin/env bash\necho JUNK-OUT\necho JUNK-ERR >&2\nexit 1\n' > "$JK/skills/harness-run/scripts/board.sh"
junk="$(callers "$JK")"
[ "$nob" = "$junk" ] || fail "a junk board.sh changed a caller's stdout or exit code"
case "$junk" in *JUNK*) fail "board.sh output leaked to a caller" ;; esac

# --- run-end ------------------------------------------------------------------
(cd "$R" && bash "$REPORT" "$(cat "$H/start")" --stop-reason "cap reached" >/dev/null 2>"$WORK/rep.err") || { cat "$WORK/rep.err"; false; } || fail "run-report failed"
tail -1 "$H/events.log" | grep -q "^[0-9]* run-end - cap reached$" || fail "run-end event missing"
grep -q 'run ended: cap reached' "$HTML" || fail "run-report must leave the final snapshot saying run ended"
touch -t 200001010000 "$HTML"; m0="$(stat -c %Y "$HTML" 2>/dev/null || stat -f %m "$HTML")"
(cd "$R" && { bash "$KIT/skills/harness-status/scripts/status.sh" . >/dev/null 2>&1; true; })
[ "$(stat -c %Y "$HTML" 2>/dev/null || stat -f %m "$HTML")" = "$m0" ] || fail "status.sh must not rewrite the board after run-end"

# --- second opinion event -----------------------------------------------------
B="$WORK/bin"; mkdir -p "$B"; printf '#!/usr/bin/env bash\necho PASS\n' > "$B/claude"; chmod +x "$B/claude"
g add -A; g commit -qm "run work"
(cd "$R" && PATH="$B:$PATH" bash "$S/second-opinion.sh" claude M1-003 HEAD~1 . >/dev/null 2>"$WORK/so.err") || { cat "$WORK/so.err"; false; } || fail "second-opinion failed"
grep -q "^[0-9]* opinion M1-003 claude PASS$" "$H/events.log" || fail "opinion event missing"

# --- 60 features: speed ----------------------------------------------------------
P="$WORK/perf"; mkdir -p "$P"; git -C "$P" init -q -b main
{ echo '{"features":['; for i in $(seq 1 60); do feat "M9-$i" failing 1; [ "$i" = 60 ] || echo ,; done; echo ']}'; } > "$P/FEATURES.json"
git -C "$P" add -A; git -C "$P" -c user.email=t@t -c user.name=t commit -qm seed
mkdir -p "$P/.harness-run/results"; git -C "$P" rev-parse HEAD > "$P/.harness-run/start"
for i in $(seq 1 60); do
  echo "$now dispatch M9-$i claude harness-builder -" >> "$P/.harness-run/events.log"
  echo "$now gate M9-$i final start" >> "$P/.harness-run/events.log"
  echo "M9-$i 0.10" >> "$P/.harness-run/cost.log"
  [ $((i % 2)) = 0 ] && echo "SESSION: M9-$i · review · gate green · abc" > "$P/.harness-run/results/M9-$i.txt"
done
limit=1.0; [ -z "${CI:-}" ] || limit=3.0
secs="$( { TIMEFORMAT=%R; time bash "$BOARD" "$P" >/dev/null; } 2>&1 )"
awk -v s="$secs" -v l="$limit" 'BEGIN { exit !(s < l) }' || fail "board.sh on 60 features took ${secs}s (limit ${limit}s)"
[ "$(grep -c 'data-stage=' "$P/.harness-run/board.html")" -eq 60 ] || fail "60 rows expected"

echo "BOARD TESTS GREEN (60 features in ${secs}s)"
