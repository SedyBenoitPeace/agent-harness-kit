#!/usr/bin/env bash
# harness-retro: one deterministic page of facts about a finished run (M60-001).
# No model, no network: reads the newest docs/runs/*.md report, PROGRESS.md's
# Decisions lines, .harness-run/events.log and the quiet.sh logs in
# .harness-run/logs/. Prints at most 80 lines, each cut to 300 characters.
# Usage: retro-facts.sh [REPO_DIR]   Exit: 0 printed; 2 usage error.
set -euo pipefail
[ $# -le 1 ] || { echo "usage: retro-facts.sh [REPO_DIR]" >&2; exit 2; }
cd "${1:-.}" || exit 2
EV=.harness-run/events.log; [ -f "$EV" ] || EV=/dev/null
report="$(find docs/runs -maxdepth 1 -name '*.md' 2>/dev/null | sort | tail -n 1)"
R="${report:-/dev/null}"

# sec <heading>: the "- " lines under "## <heading>" in the report
sec() { awk -v h="## $1" '$0 == h { on = 1; next } /^## / { on = 0 } on && /^- / && $0 != "- none"' "$R"; }
# list <title> <lines>: a counted section, "- none" when empty
list() { local n=0; [ -z "$2" ] || n="$(printf '%s\n' "$2" | wc -l | tr -d ' ')"
  echo; echo "== $1 ($n) =="; if [ "$n" = 0 ]; then echo "- none"; else printf '%s\n' "$2"; fi; }

# Decisions per done feature: the report's line, else PROGRESS.md's entry
# whose Done: line names it (wrapped lines joined)
done_ids="$(sec Done | sed -n 's/^- \([^ ]*\) — .*/\1/p')"
decisions=""
for id in $done_ids; do
  d="$(awk -v id="$id" '/^- / { cur = $2 } cur == id && /^  - Decisions: / { sub(/^  - Decisions: /, ""); print; exit }' "$R")"
  if [ -z "$d" ] && [ -f PROGRESS.md ]; then
    d="$(awk -v id="$id" '
      /^## / { if (hit && dec != "") { print dec; exit } hit = 0; indone = 0; indec = 0; dec = ""; next }
      /^- Done:/ { indone = 1; if (index($0, id) > 0) hit = 1; next }
      indone && /^  [^ -]/ { if (index($0, id) > 0) hit = 1; next }
      /^- Decisions:/ { indone = 0; indec = 1; dec = $0; sub(/^- Decisions: */, "", dec); next }
      indec && /^  [^ -]/ { sub(/^ +/, ""); dec = dec " " $0; next }
      { indone = 0; indec = 0 }
      END { if (hit && dec != "") print dec }' PROGRESS.md | head -n 1)"
  fi
  [ -z "$d" ] || decisions="${decisions:+$decisions
}- $id: $d"
done

# TDD order: per check id, in log-time order (the stamp in quiet.sh's file
# name), did a logged run fail it before the first one that passed it? A
# check's block runs from the line naming it to the next line naming another
# check; a "fail" in the block is a failure.
# ponytail: text heuristic over raw output, a structured test log if it misjudges
logs="$(find .harness-run/logs -type f -name '*.log' 2>/dev/null \
  | sed -n 's/.*-\([0-9]\{8\}-[0-9]\{6\}\)-[^/]*\.log$/\1 &/p' | sort | cut -d' ' -f2-)"
tdd=""
if [ -n "$logs" ]; then
  # shellcheck disable=SC2086 # file names come from quiet.sh: no spaces
  tdd="$(awk '
    function shut() { if (cur == "") return
      if (bad) failed[cur] = 1
      else if (!(cur in passed)) passed[cur] = (cur in failed) ? 1 : 0
      cur = "" }
    FNR == 1 { shut() }
    { l = tolower($0)
      if (match($0, /M[0-9]+-[0-9]+\.[0-9]+/)) { id = substr($0, RSTART, RLENGTH)
        if (id == cur) { if (l ~ /fail/) bad = 1; next }
        shut(); cur = id; bad = 0; if (!(id in seen)) { seen[id] = 1; ord[++n] = id }; next }
      if (cur != "" && l ~ /fail/) bad = 1 }
    END { shut()
      for (i = 1; i <= n; i++) { id = ord[i]
        if (!(id in passed)) print "- " id " failed, never passed in a logged run"
        else if (passed[id]) print "- " id " failed, then passed"
        else print "- " id " NEVER FAILED before it passed" } }' $logs)"
fi

page="$({
  echo "RETRO FACTS — ${report:-no run report in docs/runs/}"
  awk '$0 == "## Summary" { on = 1; next } /^## / { on = 0 } on && /^- (Stop reason|Counts|Cost|Tokens)/' "$R"
  list "Failed gates" "$(awk '$2 == "gate" && $5 == "red" { print "- " $3 " " $4 " red" }' "$EV")"
  list "Retries" "$(awk '$2 == "dispatch" { c[$3]++; if (c[$3] == 1) o[++n] = $3 }
    END { for (i = 1; i <= n; i++) if (c[o[i]] > 1) print "- " o[i] " dispatched " c[o[i]] " times" }' "$EV")"
  list "Verdicts not PASS" "$(awk '$2 == "opinion" && $5 != "PASS" { print "- " $3 " " $4 " " $5 }' "$EV")"
  list "Budget stops" "$(sec Budget)"
  list "Blocked (skipped or waiting on a human)" "$(sec Skipped; sec 'Waiting on a human')"
  list "Done (minutes, dollars, model, tokens where known)" "$(sec Done)"
  list "Decisions" "$decisions"
  list "TDD order (did each check's test fail before it passed)" "$tdd"
} | cut -c1-300)"
total="$(printf '%s\n' "$page" | wc -l | tr -d ' ')"
if [ "$total" -le 80 ]; then printf '%s\n' "$page"
else printf '%s\n' "$page" | head -n 79; echo "... $((total - 79)) more lines cut (read the sources above for the rest)"; fi
