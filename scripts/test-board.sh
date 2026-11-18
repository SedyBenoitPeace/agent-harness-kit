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

# --- M48-001: feature context in the expanded row ------------------------------
mkdir -p "$R/docs/plans/active" "$R/docs/plans/completed" "$R/docs/briefs"
{
  echo "# Plan"; echo "## M1-004 and <b>x</b>"
  for i in $(seq 1 50); do echo "plan line $i <i>raw</i>"; done
  echo "see docs/briefs/real.md and docs/briefs/ghost.md"
  echo "## M1-005"; echo "short section"
} > "$R/docs/plans/active/p1.md"
printf '# Old\n## M1-006\nold plan text\n## M1-007\nother\n' > "$R/docs/plans/completed/old.md"
echo brief > "$R/docs/briefs/real.md"
jq '(.features[] | select(.id == "M1-004")) |= (.verify = "bash x.sh <u>ok</u>" | .depends_on = ["M1-001","M1-002"] | .paths = ["a/b.sh","c.md"] | .model = "medium" | .effort = "high")' "$R/FEATURES.json" > "$WORK/f" && mv "$WORK/f" "$R/FEATURES.json"
bash "$BOARD" "$R"
rowof() { awk -v id="$1" 'index($0, "data-id=\"" id "\"") {on=1} on{print} /<\/details>/{if(on)exit}' "$HTML"; }
r4="$(rowof M1-004)"
case "$r4" in *"Done when"*"bash x.sh &lt;u&gt;ok&lt;/u&gt;"*) ;; *) fail "verify (Done when, escaped) missing" ;; esac
case "$r4" in *"M1-001, M1-002"*) ;; *) fail "depends_on missing" ;; esac
case "$r4" in *"a/b.sh, c.md"*) ;; *) fail "paths missing" ;; esac
case "$r4" in *medium*high*|*high*medium*) ;; *) fail "model/effort missing" ;; esac
case "$r4" in *"plan line 39 "*) ;; *) fail "plan line 39 missing" ;; esac
case "$r4" in *"plan line 40 "*) fail "plan section must be cut at 40 lines (heading + 39)" ;; esac
case "$r4" in *"cut at 40 of 52"*) ;; *) fail "cut note missing (want 'cut at 40 of 52')" ;; esac
case "$r4" in *"&lt;i&gt;raw&lt;/i&gt;"*) ;; *) fail "HTML in a plan line must be escaped" ;; esac
case "$r4" in *"<i>raw"*|*"<b>x</b>"*) fail "plan HTML leaked unescaped" ;; esac
case "$r4" in *"href=\"file://$R/docs/plans/active/p1.md\""*) ;; *) fail "plan file link missing" ;; esac
r5="$(rowof M1-005)"
case "$r5" in *"short section"*) ;; *) fail "short plan section missing" ;; esac
case "$r5" in *"cut at"*|*"Done when"*) fail "no cut note or absent fields for M1-005" ;; esac
r6="$(rowof M1-006)"
case "$r6" in *"old plan text"*"completed/old.md"*) ;; *) fail "completed-plan fallback missing" ;; esac
case "$r6" in *other*) fail "plan section must stop at the next ##" ;; esac
case "$(rowof M1-001)" in *"no plan section"*) ;; *) fail "'no plan section' missing" ;; esac
# the brief mention sits in M1-004's section only when under 40 lines: put it in a short one
printf '## M1-008\nsee docs/briefs/real.md and docs/briefs/ghost.md\n' >> "$R/docs/plans/active/p1.md"
bash "$BOARD" "$R"; r8="$(rowof M1-008)"
case "$r8" in *"href=\"file://$R/docs/briefs/real.md\""*) ;; *) fail "existing brief link missing" ;; esac
case "$r8" in *'href="file://'*ghost.md*) fail "brief link only when the file exists" ;; esac
if ! { grep -q '\[open\]>summary' "$HTML" && grep -q '▾' "$HTML" && grep -q '▸' "$HTML"; }; then fail "row marker missing"; fi
grep -q 'summary{[^}]*cursor:pointer' "$HTML" || fail "summary pointer cursor missing"
rm -rf "$R/docs"

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
# archive-features.sh runs after the report: archived features keep their rows
aid="$(sed -n 's/.*data-id="\([^"]*\)".*/\1/p' "$HTML" | head -1)"
(cd "$R" && jq --arg i "$aid" '{features: ([.features[] | select(.id == $i)] + [{id: "M0-999", milestone: 0, title: "old", status: "passing"}])}' FEATURES.json > docs-arc.json \
  && mkdir -p docs && mv docs-arc.json docs/features-archive.json \
  && jq --arg i "$aid" '.features |= map(select(.id != $i))' FEATURES.json > f.json && mv f.json FEATURES.json)
(cd "$R" && bash "$BOARD" . >/dev/null) || fail "board.sh failed after archiving"
row "$aid" | grep -q . || fail "archived feature $aid lost its board row"
row M0-999 | grep -q . && fail "a feature archived before the run must not get a row"

# --- second opinion event -----------------------------------------------------
B="$WORK/bin"; mkdir -p "$B"; printf '#!/usr/bin/env bash\necho PASS\n' > "$B/claude"; chmod +x "$B/claude"
g add -A; g commit -qm "run work"
(cd "$R" && PATH="$B:$PATH" bash "$S/second-opinion.sh" claude M1-003 HEAD~1 . >/dev/null 2>"$WORK/so.err") || { cat "$WORK/so.err"; false; } || fail "second-opinion failed"
grep -q "^[0-9]* opinion M1-003 claude PASS$" "$H/events.log" || fail "opinion event missing"

# --- hints and STOP (M49-001) --------------------------------------------------
X="$WORK/hx"; mkdir -p "$X"; git -C "$X" init -q -b main
{ echo '{"features":['; feat H-001 failing 0; echo ,; feat H-002 failing 0; echo ,; feat H-003 failing 0; echo ']}'; } > "$X/FEATURES.json"
git -C "$X" add -A; git -C "$X" -c user.email=t@t -c user.name=t commit -qm seed
mkdir -p "$X/.harness-run/hints"; git -C "$X" rev-parse HEAD > "$X/.harness-run/start"
date +%s > "$X/.harness-run/run-id"; echo H-002 > "$X/.harness-run/skip"
jq '(.features[] | select(.id == "H-001") | .status) = "passing"' "$X/FEATURES.json" > "$X/f.json" && mv "$X/f.json" "$X/FEATURES.json"
printf '<b>x</b> & "q"\nsecond line\n' > "$X/.harness-run/hints/H-003.md"
XH="$X/.harness-run/board.html"
xrow() { awk -v id="data-id=\"$1\"" 'index($0, id){on=1} on{print} /<\/details>/{if(on) exit}' "$XH"; }
bash "$BOARD" "$X"
grep -q 'Stop after current feature' "$XH" || fail "board: STOP button missing"
! grep -q 'stop requested' "$XH" || fail "board: 'stop requested' without a STOP file"
xr="$(xrow H-003)"
echo "$xr" | grep -q '<textarea' || fail "board: non-passing row needs a hint box"
echo "$xr" | grep -q 'Copy hint command' || fail "board: hint button missing"
echo "$xr" | grep -qF '&lt;b&gt;x&lt;/b&gt; &amp;' || fail "board: existing hint must be escaped"
! echo "$xr" | grep -qF '<b>x</b>' || fail "board: existing hint injected as HTML"
echo "$xr" | grep -q 'class="tag">hint' || fail "board: row with a hint needs a 'hint' tag"
! xrow H-001 | grep -q '<textarea' || fail "board: passing row must have no hint box"
! xrow H-002 | grep -q '<textarea' || fail "board: skipped row must have no hint box"
grep -qF "data-root=\"$X\"" "$XH" || fail "board: copy commands need the absolute repo path"
touch "$X/.harness-run/STOP"; bash "$BOARD" "$X"
grep -q 'stop requested' "$XH" || fail "board: 'stop requested' missing with STOP present"
! grep -q 'Stop after current feature' "$XH" || fail "board: STOP button must go once STOP exists"
# the page's own quoting (built in JS): write the command through bash, text must arrive verbatim
txt="$(printf "it's \$(touch %s/pwn) \`touch %s/pwn2\` \"dq\"\nline2 ; rm -rf x" "$WORK" "$WORK")"
if [ -z "${BOARD_TEST_NO_NODE:-}" ] && command -v node >/dev/null; then
  fn="$(grep -E '^function (q|hintCmd)\(' "$XH")"; [ "$(echo "$fn" | wc -l)" -eq 2 ] || fail "board JS: q/hintCmd lines missing"
  cmd="$(node -e "$fn"'; process.stdout.write(hintCmd(process.argv[1], "H-003", process.argv[2]))' "$X" "$txt")"
  how="the page's JS run with node"
else
  qt="$(printf '%s' "$txt" | jq -Rsr --arg a "'" --arg b "'\\''" 'gsub($a; $b)')"
  cmd="mkdir -p '$X/.harness-run/hints' && printf '%s\\n' '$qt' >> '$X/.harness-run/hints/H-003.md'"
  how="a jq mirror of the quoting (no node)"
fi
rm -f "$X/.harness-run/hints/H-003.md"
bash -c "$cmd"
{ [ ! -e "$WORK/pwn" ] && [ ! -e "$WORK/pwn2" ]; } || fail "hint command executed its text"
[ "$(cat "$X/.harness-run/hints/H-003.md")" = "$txt" ] || fail "hint command must write the text verbatim ($how)"
echo "hint quoting proven with $how"

# --- 60 features: speed ----------------------------------------------------------
P="$WORK/perf"; mkdir -p "$P"; git -C "$P" init -q -b main
{ echo '{"features":['; for i in $(seq 1 60); do feat "M9-$i" failing 1; [ "$i" = 60 ] || echo ,; done; echo ']}'; } > "$P/FEATURES.json"
git -C "$P" add -A; git -C "$P" -c user.email=t@t -c user.name=t commit -qm seed
mkdir -p "$P/docs/plans/active" "$P/.harness-run/results"
for i in $(seq 1 60); do { echo "## M9-$i"; for j in $(seq 1 60); do echo "line $j"; done; } >> "$P/docs/plans/active/big.md"; done
git -C "$P" rev-parse HEAD > "$P/.harness-run/start"
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
[ "$(grep -c 'cut at 40 of 61' "$P/.harness-run/board.html")" -eq 60 ] || fail "60 plan sections expected"

echo "BOARD TESTS GREEN (60 features in ${secs}s)"
