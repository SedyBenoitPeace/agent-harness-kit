#!/usr/bin/env bash
# read-checks.sh — the one reader for acceptance checks (M53). Every other
# piece reads checks through it and never cares where they live.
#
#   read-checks.sh [--status s1,s2] [FEATURES.json]   (default ./FEATURES.json)
#   read-checks.sh --issue-json FILE    # output of: gh issue view N --json number,title,body
#   read-checks.sh --issue N            # calls gh for issue N
#   read-checks.sh --md FILE            # markdown checks (a brief's ## Checks; ids C<n>)
#
# Prints one JSON line per check:
#   {"feature","id","title","critical","steps","pass_if","evidence"}
# Problems go to stderr, one per line; exit 1. Exit 2 = usage or missing tool.
# shellcheck disable=SC2016 # single-quoted jq programs: $f, $l, $m are jq variables
set -euo pipefail
command -v jq >/dev/null || { echo "ERROR: jq is required (brew install jq)" >&2; exit 2; }

mode=features src="FEATURES.json" status=""
while [ $# -gt 0 ]; do
  case "$1" in
    --status) status="${2:?--status needs a list}"; shift 2 ;;
    --issue-json) mode=issue src="${2:?--issue-json needs a file}"; shift 2 ;;
    --issue) mode=issue src="-"
             command -v gh >/dev/null || { echo "ERROR: gh is required for --issue" >&2; exit 2; }
             issue="$(gh issue view "${2:?--issue needs a number}" --json number,title,body)"; shift 2 ;;
    --md) mode=md src="${2:?--md needs a file}"; shift 2 ;;
    -*) echo "usage: read-checks.sh [--status list] [FEATURES.json] | --issue-json FILE | --issue N | --md FILE" >&2; exit 2 ;;
    *) src="$1"; shift ;;
  esac
done
[ "$src" = "-" ] || [ -f "$src" ] || { echo "ERROR: $src not found" >&2; exit 2; }

LIB='
def md($f):
  def flush: if .cur then .checks += [.cur] | .cur = null else . end;
  split("\n")
  | reduce .[] as $l ({checks: [], cur: null, field: null};
      if ($l | test("^### ")) then
        flush
        | ($l | capture("^### (?<id>\\S+) — (?<title>.*)$") // {id: ($l | ltrimstr("### ")), title: ""}) as $h
        | .cur = {feature: $f, id: $h.id, title: $h.title, critical: null, steps: [], pass_if: null, evidence: null}
        | .field = null
      elif ($l | test("^#{1,2} ")) then flush
      elif .cur == null then .
      elif ($l | test("^- \\*\\*[^*]+:\\*\\*")) then
        ($l | capture("^- \\*\\*(?<k>[^*]+):\\*\\*\\s*(?<v>.*)$")) as $m
        | ($m.v | ascii_downcase | gsub("\\s+$"; "")) as $v
        | .field = $m.k
        | if $m.k == "Critical" then .cur.critical = (if $v == "yes" then true elif $v == "no" then false else $m.v end)
          elif $m.k == "Pass if" then .cur.pass_if = $m.v
          elif $m.k == "Evidence" then .cur.evidence = $v
          else . end
      elif .field == "Steps" and ($l | test("^\\s+[0-9]+\\.\\s+\\S")) then
        .cur.steps += [$l | sub("^\\s+[0-9]+\\.\\s+"; "")]
      else . end)
  | flush | .checks;

def problems:
  (group_by(.id) | map(select(length > 1) | "\(.[0].id): listed twice")[]),
  (.[] | . as $c | (.id // "?") as $i |
    (if ($c.feature == null and (($c.id // "") | test("^C[0-9]+$") | not))
        or ($c.feature != null and ((($c.id // "") | startswith($c.feature + ".")) and (($c.id // "")[($c.feature | length) + 1:] | test("^[0-9]+$")) | not))
     then "\($i): id must be \(if $c.feature then $c.feature + ".<n>" else "C<n>" end)" else empty end),
    (if (($c.title // "") | type) != "string" or ($c.title // "") == "" then "\($i): title is empty" else empty end),
    (if ($c.critical | type) != "boolean" then "\($i): critical must be true/false (yes/no in markdown)" else empty end),
    (if ($c.steps | type) != "array" or ($c.steps | length) == 0 or any($c.steps[]; type != "string" or . == "") then "\($i): steps must be a non-empty list" else empty end),
    (if (($c.pass_if // "") | type) != "string" or ($c.pass_if // "") == "" then "\($i): pass_if is empty" else empty end),
    (if ($c.evidence | IN("test", "screenshot", "human")) | not then "\($i): evidence must be test, screenshot or human, not \($c.evidence)" else empty end));

def row: {feature, id, title, critical, steps, pass_if, evidence};
'

case "$mode" in
  features)
    prog="$LIB"'
      [.features[] | select($st == "" or (.status | IN($st | split(",")[]))) | .id as $f
       | (.checks // [])[] | . + {feature: $f}]'
    all="$(jq --arg st "$status" "$prog" "$src")" ;;
  issue)
    prog="$LIB"'
      ((.title | capture("^\\[(?<id>[^\\]]+)\\]")? | .id) // null) as $f
      | if $f == null then error("issue #\(.number): title must start with [<feature id>], got: \(.title)")
        else .body | md($f) end'
    if [ "$src" = "-" ]; then
      all="$(printf '%s' "$issue" | jq "$prog" 2>&1)" || { printf '%s\n' "$all" | sed -E 's/^jq: error \(at [^)]*\): //' >&2; exit 1; }
    else
      all="$(jq "$prog" "$src" 2>&1)" || { printf '%s\n' "$all" | sed -E 's/^jq: error \(at [^)]*\): //' >&2; exit 1; }
    fi ;;
  md)
    all="$(jq -Rs "$LIB"'md(null)' "$src")" ;;
esac

probs="$(printf '%s' "$all" | jq -r "$LIB"'problems')"
if [ -n "$probs" ]; then printf '%s\n' "$probs" >&2; exit 1; fi
printf '%s' "$all" | jq -c "$LIB"'.[] | row'
