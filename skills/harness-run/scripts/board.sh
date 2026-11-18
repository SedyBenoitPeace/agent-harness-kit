#!/usr/bin/env bash
# harness-run: the live run board (M47-001). No model calls, bash + jq only.
# Writes <main repo>/.harness-run/board.html (temp file + mv) from the run
# state on disk: FEATURES.json now and at .harness-run/start, events.log,
# results/, skip, cost.log, usage.log and lane worktrees ../<repo>-<id>.
# Does nothing outside a run (no .harness-run/start in the main repo).
# Spec: docs/briefs/2026-11-18-run-board.md.
# Usage: board.sh <target> [--open]
# --open prints `BOARD: <abs path>` and opens the page once per run-id
# ($HARNESS_BOARD_OPEN_CMD, else open on macOS, xdg-open on Linux), recorded
# in .harness-run/board-opened; HARNESS_BOARD_OPEN=0 never opens.
set -euo pipefail
t="${1:-}"; [ -d "$t" ] || { echo "usage: board.sh <target> [--open]" >&2; exit 2; }
opn=0; [ "${2:-}" = --open ] && opn=1
command -v jq >/dev/null || { echo "board: jq is required" >&2; exit 2; }
cd "$t"
root="$(cd "$(git rev-parse --git-common-dir 2>/dev/null)/.." 2>/dev/null && pwd -P)" || exit 0
d="$root/.harness-run"
[ -s "$d/start" ] || exit 0
cd "$root"
repo="$(basename "$root")"
branch="$(git branch --show-current 2>/dev/null || true)"
startf="$(git show "$(cat "$d/start"):FEATURES.json" 2>/dev/null || cat FEATURES.json)"
rf() { if [ -f "$1" ]; then echo "$1"; else echo /dev/null; fi; }

# results: "<mtime> <id>" and "<id>.txt:<line>", one process each
mt="" rl=""
if [ -d "$d/results" ]; then
  shopt -s nullglob; files=("$d"/results/*.txt); shopt -u nullglob
  if [ "${#files[@]}" -gt 0 ]; then
    names=("${files[@]##*/}")
    mt="$(cd "$d/results" && { stat -c '%Y %n' "${names[@]}" 2>/dev/null || stat -f '%m %N' "${names[@]}"; })"
    rl="$(cd "$d/results" && { grep -H '' "${names[@]}" || true; })"
  fi
fi
lanes=""
for l in ../"$repo"-*; do [ -d "$l" ] && lanes="$lanes${l#../"$repo"-}"$'\n'; done

# plan files (active first, then completed) in one awk, existing briefs in one glob
shopt -s nullglob
pf=(docs/plans/active/*.md docs/plans/completed/*.md); bf=(docs/briefs/*.md)
shopt -u nullglob
plans=""; [ "${#pf[@]}" -eq 0 ] || plans="$(awk 'FNR == 1 { printf "\001%s\n", FILENAME } 1' "${pf[@]}")"
briefs=""; [ "${#bf[@]}" -eq 0 ] || briefs="$(printf '%s\n' "${bf[@]}")"

tmp="$(mktemp "$d/.board.XXXXXX")"
trap 'rm -f "$tmp" "$tmp.body"' EXIT
jq -nr --argjson now "$(date +%s)" --arg repo "$repo" --arg branch "$branch" \
  --arg runid "$(cat "$d/run-id" 2>/dev/null || true)" --arg st "$(stat -c %Y "$d/start" 2>/dev/null || stat -f %m "$d/start")" --arg mt "$mt" --arg rl "$rl" --arg lanes "$lanes" --arg root "$root" --arg plans "$plans" --arg briefs "$briefs" \
  --argjson s0 "$startf" --slurpfile cur FEATURES.json --slurpfile arc "$(rf docs/features-archive.json)" \
  --rawfile ev "$(rf "$d/events.log")" --rawfile skip "$(rf "$d/skip")" \
  --rawfile cost "$(rf "$d/cost.log")" --rawfile usage "$(rf "$d/usage.log")" '
def lines: split("\n") | map(select(length > 0));
def h: tostring | @html;
def dur: if . == null then "—" else (. | floor) as $s
  | if $s < 60 then "\($s)s" elif $s < 3600 then "\($s / 60 | floor)m \($s % 60)s"
    else "\($s / 3600 | floor)h \($s % 3600 / 60 | floor)m" end end;
def usd: "$" + (. * 100 | round / 100 | tostring | if test("\\.[0-9]$") then . + "0" elif test("\\.") then . else . + ".00" end);
def tok: if . >= 1000000 then "\(. / 100000 | floor / 10)M tok" elif . >= 1000 then "\(. / 100 | floor / 10)k tok" else "\(.) tok" end;
($ev | lines | to_entries | map(.key as $n | .value | split(" ")
  | {n: $n, ts: (.[0] | tonumber? // 0), e: .[1], id: .[2], f: .[3:]})) as $E
| ($skip | lines) as $SK | ($lanes | lines) as $LN
| ($mt | lines | map(capture("^(?<m>[0-9]+) (?<id>.*)\\.txt$")) | map({key: .id, value: (.m | tonumber)}) | from_entries) as $RM
| ($rl | lines | map(capture("^(?<id>[^:]*)\\.txt:(?<l>.*)$")) | group_by(.id) | map({key: .[0].id, value: map(.l)}) | from_entries) as $RL
| ($cost | lines | map(split(" ") | {id: .[0], usd: (.[1] | tonumber? // 0)})) as $C
| ($usage | lines | map(split(" ") | {s: .[0], id: (.[0] | split("/")[0]), m: .[2], t: ((.[3] | tonumber? // 0) + (.[5] | tonumber? // 0))})) as $U
| ($briefs | lines) as $BX
| [$plans | split("\u0001")[] | select(length > 0) | index("\n") as $i | {f: .[:$i], t: ("\n" + .[$i + 1:])}] as $PF
| [$PF[] | .f as $f | .t | split("\n## ")[1:][] | {f: $f, l: ("## " + .) | split("\n") | until(length == 0 or .[-1] != ""; .[:-1])}] as $SEC
| (reduce $PF[] as $p ({}; .[$p.f] = ([$p.t | scan("docs/briefs/[A-Za-z0-9._/-]+\\.md")] | unique | map(select(. as $b | $BX | index([$b]) != null))))) as $BR
| (($cur[0].features // []) + ($arc[0].features // [])) as $CF  # archived features keep their rows (archive-features.sh runs after the report)
| (($s0.features // []) | map({key: .id, value: .status}) | from_entries) as $S0
| [$CF[] | .id as $i | select(($S0[$i] // "absent") != "passing" and (($S0 | has($i)) or .status == "passing"))] as $rows0
# per feature facts, then the one non-lane building feature that owns "-" gate events
| [$rows0[] | .id as $i
   | ([$E[] | select(.e == "dispatch" and .id == $i)] | last) as $dp
   | ($RM[$i]) as $rm
   | ([$SEC[] | select(.l[0] | index($i))] | first) as $sec
   | . + {fm: .model, sec: $sec, dp: $dp, lane: ($LN | index([$i]) != null),
          res: (if $rm != null and ($dp == null or $rm >= $dp.ts) then {m: $rm, l: ($RL[$i] // [])} else null end)}
   | .rs = ((.res.l[0] // "") | [capture("· (?<s>passing|review|blocked) ·")][0].s)
   | .rg = ((.res.l[0] // "") | [capture("gate (?<g>green|red)")][0].g)] as $rows1
| ([$rows1[] | select(.dp != null and .res == null and (.lane | not)) | .id]) as $own
| [$rows1[] | .id as $i | . as $r
   | ([$E[] | select(.e == "gate" and (.id == $i or (.id == "-" and $own == [$i] and .ts >= $r.dp.ts)))] | last) as $g
   | (.eval_attempts // 0) as $ea
   | . + {g: $g} + (
       if $SK | index([$i]) then {st: "skipped", since: null}
       elif .status == "passing" then {st: "passing", since: .res.m}
       elif $g != null and $g.f[1] == "start" and .res == null then {st: "gate running", since: $g.ts}
       elif .dp != null and .res == null then {st: "building", since: .dp.ts}
       elif .rs == "blocked" then {st: "blocked", since: .res.m}
       elif .rs == "passing" then {st: "merging", since: .res.m}
       elif .status == "review" then {st: "review", since: .res.m}
       elif .status == "failing" and $ea > 0 then {st: "rework (\($ea)/2)", since: null}
       elif .rs == "review" then {st: "review", since: .res.m}
       else {st: "queued", since: null} end)
   | .gate = (if .st == "building" or .st == "gate running" then (if $g then "\($g.f[0]) \($g.f[1])" else "—" end)
              elif .rg then "gate \(.rg)" else "—" end)
   | ([$C[] | select(.id == $i) | .usd]) as $cs
   | ([$U[] | select(.id == $i)]) as $us
   | .cost = (if $cs != [] then ($cs | add | usd)
              elif $us != [] then ($us | map(.t) | add | tok) else "—" end)
   | .model = ([$us[] | select(.m != "-" and .m != null) | .m] | last)
   | .agent = (if .dp then (.dp.f | join(" ")) else "—" end) + (if .model then " · \(.model)" else "" end)
   | .ops = [$E[] | select(.e == "opinion" and .id == $i) | .f | join(" ")]] as $rows
| ([$E[] | select(.e == "run-start")] | first.ts // ($runid | split("-")[0] | tonumber? // ($st | tonumber? // $now))) as $t0
| ([$E[] | select(.e == "run-end")] | last) as $end
| ($rows | length) as $n | ([$rows[] | select(.st == "passing")] | length) as $np
| ($rows | group_by(.st | split(" ")[0]) | map("\(.[0].st | split(" ")[0]) \(length)") | join(" · ")) as $counts
| (if $C != [] then ($C | map(.usd) | add | usd)
   elif $U != [] then ($U | map(.t) | add | tok) else "—" end) as $total
| "<header><h1>\($repo | h) <small>\($branch | h)</small></h1>"
  + "<p>run started <span class=\"local\" data-ts=\"\($t0)\">\($t0 | todate | h)</span> · \($counts | h) · cost \($total | h) · updated <span class=\"tick\" data-since=\"\($now)\">0s</span> ago"
  + (if $end then " · <b>run ended: \($end.f | join(" ") | h)</b>" else "" end) + "</p>"
  + "<div class=\"bar\"><i style=\"width:\(if $n > 0 then ($np * 100 / $n | floor) else 0 end)%\"></i></div>"
  + "<p class=\"muted\">\($np)/\($n) passing</p></header>"
  + "<div class=\"row head\"><span>feature</span><span>stage</span><span>agent</span><span>gate</span><span>time</span><span>cost</span></div>"
  + ([$rows[] | "<details class=\"row-d\" data-id=\"\(.id | h)\" data-stage=\"\(.st | h)\"><summary class=\"row\">"
      + "<span><b>\(.id | h)</b> \(.title // "" | h)</span>"
      + "<span class=\"st st-\(.st | split(" ")[0])\">\(.st | h)\(if .lane and (.st == "building" or .st == "gate running") then " <em>lane</em>" else "" end)</span>"
      + "<span>\(.agent | h)</span><span>\(.gate | h)</span>"
      + (if .since then "<span class=\"tick\" data-since=\"\(.since)\">\($now - .since | dur)</span>" else "<span>—</span>" end)
      + "<span>\(.cost | h)</span></summary><div class=\"more\">"
      + (if .verify then "<p><b>Done when</b> \(.verify | h)</p>" else "" end)
      + (if (.depends_on // []) != [] then "<p>depends on: \(.depends_on | join(", ") | h)</p>" else "" end)
      + (if (.paths // []) != [] then "<p>paths: \(.paths | join(", ") | h)</p>" else "" end)
      + (if .effort or .fm then "<p>\([(if .effort then "effort \(.effort)" else empty end), (if .fm then "model \(.fm)" else empty end)] | join(" · ") | h)</p>" else "" end)
      + (if .sec then "<pre class=\"plan\">\(.sec.l[:40] | join("\n") | h)</pre>"
          + (if (.sec.l | length) > 40 then "<p>cut at 40 of \(.sec.l | length) lines</p>" else "" end)
          + "<p>plan: <a href=\"file://\($root | h)/\(.sec.f | h)\">\(.sec.f | h)</a>"
          + ([($BR[.sec.f] // [])[] | " · brief: <a href=\"file://\($root | h)/\(. | h)\">\(. | h)</a>"] | join(""))
          + "</p>"
        else "<p>no plan section</p>" end)
      + "<p>\(.notes // "no notes" | h)</p>"
      + (if .res then "<pre>\(.res.l | join("\n") | h)</pre>" else "" end)
      + (if .ops != [] then "<p>second opinions: \(.ops | join(", ") | h)</p>" else "" end)
      + "</div></details>"] | join("\n"))
' > "$tmp.body"
{
  cat <<'EOF'
<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Run board</title><style>
:root{--bg:#fff;--fg:#1a1a1a;--mut:#666;--line:#e4e4e4;--acc:#2a7;--warn:#c80;--bad:#c33;--run:#36c}
@media (prefers-color-scheme:dark){:root{--bg:#141414;--fg:#e8e8e8;--mut:#999;--line:#333;--acc:#4c9;--warn:#ea4;--bad:#e66;--run:#69f}}
body{background:var(--bg);color:var(--fg);font:14px/1.4 system-ui,sans-serif;margin:0 auto;padding:16px;max-width:1100px}
h1{font-size:20px;margin:0}small,.muted{color:var(--mut)}
.bar{height:6px;background:var(--line);border-radius:3px;overflow:hidden}.bar i{display:block;height:100%;background:var(--acc)}
.row{display:grid;grid-template-columns:3fr 1.3fr 2fr 1.2fr .8fr .8fr;gap:8px;padding:6px 4px;border-bottom:1px solid var(--line);cursor:pointer}
.head{font-weight:600;color:var(--mut);cursor:default}summary{list-style:none}summary::-webkit-details-marker{display:none}
summary{cursor:pointer}.row-d>summary>span:first-child::before{content:"▸ "}.row-d[open]>summary>span:first-child::before{content:"▾ "}
.more{padding:6px 12px;color:var(--mut)}pre{white-space:pre-wrap;margin:4px 0}
.st-passing{color:var(--acc)}.st-building,.st-gate{color:var(--run)}.st-merging,.st-review,.st-rework{color:var(--warn)}.st-blocked{color:var(--bad)}
@media (max-width:700px){.row{grid-template-columns:1fr 1fr}}
</style></head><body>
EOF
  cat "$tmp.body"
  cat <<'EOF'
<script>
(function(){
  var k='harness-board-open',o={};
  try{o=JSON.parse(sessionStorage.getItem(k)||'{}')}catch(e){}
  document.querySelectorAll('details[data-id]').forEach(function(d){
    if(o[d.dataset.id])d.open=true;
    d.addEventListener('toggle',function(){o[d.dataset.id]=d.open;try{sessionStorage.setItem(k,JSON.stringify(o))}catch(e){}});
  });
  function dur(s){s=Math.max(0,Math.floor(s));return s<60?s+'s':s<3600?Math.floor(s/60)+'m '+s%60+'s':Math.floor(s/3600)+'h '+Math.floor(s%3600/60)+'m'}
  function tick(){var n=Date.now()/1000;document.querySelectorAll('.tick').forEach(function(e){e.textContent=dur(n-e.dataset.since)})}
  document.querySelectorAll('.local').forEach(function(e){e.textContent=new Date(e.dataset.ts*1000).toLocaleString([], {dateStyle:'medium',timeStyle:'short'})});tick();setInterval(tick,1000);setTimeout(function(){location.reload()},5000);
})();
</script></body></html>
EOF
} > "$tmp"
rm -f "$tmp.body"
mv "$tmp" "$d/board.html"
trap - EXIT
html="$d/board.html"

[ "$opn" = 1 ] || exit 0
echo "BOARD: $html"
[ "${HARNESS_BOARD_OPEN:-1}" != 0 ] || exit 0
rid="$(cat "$d/run-id" 2>/dev/null || cat "$d/start")"
[ "$(cat "$d/board-opened" 2>/dev/null || true)" != "$rid" ] || exit 0
if [ -n "${HARNESS_BOARD_OPEN_CMD:-}" ]; then
  # shellcheck disable=SC2086 # the command may carry its own arguments
  $HARNESS_BOARD_OPEN_CMD "$html" >/dev/null 2>&1 || true
elif [ "$(uname)" = Darwin ]; then open "$html" >/dev/null 2>&1 || true
elif command -v xdg-open >/dev/null; then xdg-open "$html" >/dev/null 2>&1 || true
fi
echo "$rid" > "$d/board-opened"
