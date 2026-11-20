#!/usr/bin/env bash
# issues.sh — GitHub issues as the place to write features (M55). The only
# kit script that talks to GitHub; everything else reads FEATURES.json, the
# committed mirror, so agents without GitHub access keep working and no
# model tokens are spent on sync.
#
#   issues.sh sync    [--dry-run]   # issues -> FEATURES.json, then status back
#   issues.sh migrate [--dry-run]   # open features -> new issues; source: issues
#
# An issue is a feature when its title is "[<feature id>] <title>". The issue
# owns title and checks; the repo owns every other field (decisions 5-7, 10).
# Issues opened by someone without write access to the repo are skipped.
# Titles must match [M<n>-<nnn>]; other issues are ignored. Run in the repo
# root. Exit 1 when an issue was skipped as broken or as a duplicate id
# (issues from non-writers are reported, exit 0); 2 = usage or tools.
# shellcheck disable=SC2016 # single-quoted jq programs use jq variables
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
cmd="${1:-}"; shift || true
dry=0
for a in "$@"; do
  case "$a" in --dry-run) dry=1 ;; *) echo "usage: issues.sh sync|migrate [--dry-run] (unknown: $a)" >&2; exit 2 ;; esac
done
case "$cmd" in sync | migrate) ;; *) echo "usage: issues.sh sync|migrate [--dry-run]" >&2; exit 2 ;; esac
for t in jq gh; do command -v "$t" >/dev/null || { echo "ERROR: $t is required" >&2; exit 2; }; done
[ -f FEATURES.json ] || { echo "ERROR: run in the repo root (no FEATURES.json)" >&2; exit 2; }

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
rc=0

if [ "$cmd" = sync ] && [ "$(jq -r '.source // "features"' FEATURES.json)" != issues ]; then
  echo "issues.sh: source is features (set \"source\": \"issues\" in FEATURES.json, or run migrate); nothing to sync"
  exit 0
fi

TRIM_END() { sed -e :a -e '/^\n*$/{$d;N;ba' -e '}'; }
# stdin: issue body -> the owner's text above (before) or below (after) the
# generated block; the block itself is the only part sync ever rewrites
before() { awk 'index($0, "<!-- harness:details:start") == 1 { exit } { print }' | TRIM_END; }
after() { awk 'on { print } index($0, "<!-- harness:details:end") == 1 { on = 1 }' | sed -e '/./,$!d' | TRIM_END; }
FEAT='^\\[M[0-9]+-[0-9]+\\] '

gh issue list --state all --limit 1000 --json number,title,body,state,labels,author > "$tmp/all.json"
# Only issues opened by someone with write access count: on a public repo
# anyone can open "[M9-001] …", and an unattended run would build it.
# (Only the author or a collaborator can edit an issue body afterwards.)
gh api 'repos/{owner}/{repo}/collaborators?per_page=100' --jq '.[] | select(.permissions.push) | .login' > "$tmp/writers"
[ -s "$tmp/writers" ] || { echo "ERROR: could not list collaborators with write access; nothing synced" >&2; exit 2; }
# shellcheck disable=SC2016
WRITER='($w | split("\n") | map(select(length > 0))) as $ws | (.author.login // "") as $a | $a != "" and ($ws | index([$a]) != null)'
jq -r --rawfile w "$tmp/writers" '.[] | select((.title | test("'"$FEAT"'")) and ('"$WRITER"' | not))
  | "issue #\(.number): opened by \(.author.login // "unknown"), who has no write access; skipped"' "$tmp/all.json" >&2
jq --rawfile w "$tmp/writers" '[.[] | select((.title | test("'"$FEAT"'")) and '"$WRITER"')
  | . + {id: (.title | capture("^\\[(?<id>[^]]+)\\]").id)}]' "$tmp/all.json" > "$tmp/feat.json"
# one feature id in two issues: report both numbers, skip the id both ways
dups="$(jq -r 'group_by(.id)[] | select(length > 1) | "\(.[0].id): in issues \(map("#\(.number)") | join(" and ")); give one a new id or close it as a duplicate; skipped"' "$tmp/feat.json")"
if [ -n "$dups" ]; then printf '%s\n' "$dups" >&2; rc=1; fi
jq '[group_by(.id)[] | select(length == 1)[]]' "$tmp/feat.json" > "$tmp/issues.json"

# --- pull: issues -> FEATURES.json (title and checks only) -------------------
pull() {
  : > "$tmp/pulled"
  jq -c '.[]' "$tmp/issues.json" | while IFS= read -r iss; do
    n="$(jq -r .number <<< "$iss")"
    { jq -r '.body // ""' <<< "$iss" | before; printf '\n'; jq -r '.body // ""' <<< "$iss" | after; } > "$tmp/owner"
    jq --rawfile b "$tmp/owner" '{number, title, body: $b}' <<< "$iss" > "$tmp/one.json"
    if ! checks="$(bash "$here/read-checks.sh" --issue-json "$tmp/one.json" 2>"$tmp/err" | jq -s .)"; then
      sed "s/^/issue #$n: /" "$tmp/err" >&2; echo skip >> "$tmp/pulled"; continue
    fi
    jq -c --argjson c "$checks" '(.title | capture("^\\[(?<id>[^]]+)\\] (?<t>.*)$")) as $m
      | {id: $m.id, title: $m.t, number, has: ($b | test("(^|\\n)## Checks\\s*(\\n|$)")), checks: ($c | map(del(.feature)))}' --rawfile b "$tmp/owner" <<< "$iss" >> "$tmp/pulled"
  done
  grep -q '^skip$' "$tmp/pulled" && rc=1
  grep -v '^skip$' "$tmp/pulled" | jq -s . > "$tmp/pulled.json" || echo '[]' > "$tmp/pulled.json"
  jq --slurpfile p "$tmp/pulled.json" '
    reduce $p[0][] as $i (.;
      if any(.features[]; .id == $i.id) then
        .features |= map(if .id == $i.id then .title = $i.title
          | (if ($i.has | not) then . elif ($i.checks | length) > 0 then .checks = $i.checks else del(.checks) end) else . end)
      else
        .features += [{id: $i.id, milestone: ($i.id | capture("^M(?<m>[0-9]+)-").m? | tonumber? // null),
                       title: $i.title, status: "failing",
                       verify: (if ($i.checks | length) > 0 then "Every check passes: each has its test and scripts/e2e.sh is green"
                                else "TODO: plan this feature (from issue #\($i.number))" end)}
                      + (if ($i.checks | length) > 0 then {checks: $i.checks} else {} end)]
      end)' FEATURES.json > "$tmp/F.json"
  if [ "$(jq -S . FEATURES.json)" != "$(jq -S . "$tmp/F.json")" ]; then
    if [ "$dry" = 1 ]; then echo "would update FEATURES.json"; else cp "$tmp/F.json" FEATURES.json; fi
  fi
  echo "issues.sh: pulled $(jq length "$tmp/pulled.json") issues"
}

# --- push: FEATURES.json -> issues (generated block, status label, state) ----
plan_section() {  # plan_section <id>: "<file>\n<up to 40 lines>" of its ## <id> section
  local f
  for f in docs/plans/active/*.md docs/plans/completed/*.md; do
    [ -f "$f" ] || continue
    if grep -qE "^## $1([ :]|\$)" "$f"; then
      echo "$f"
      awk -v id="$1" '$0 ~ "^## " { if (on) exit; on = ($0 ~ "^## " id "([ :]|$)"); next } on' "$f" \
        | sed -e '/./,$!d' | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}' | head -40
      return
    fi
  done
}
block() {  # block <feature json>: the generated details block
  local id sec file
  id="$(jq -r .id <<< "$1")"
  sec="$(plan_section "$id")"; file="$(head -1 <<< "$sec")"
  jq -r --arg file "$file" --arg sec "$(tail -n +2 <<< "$sec")" '
    (.notes // "") as $n
    | "<!-- harness:details:start: generated by issues.sh sync from FEATURES.json; edits inside are overwritten -->",
      "<!-- harness-feature: \(.id) -->",
      "## Harness details", "",
      "- **Status:** \(.status)",
      (if .verify then "- **Done when:** \(.verify)" else empty end),
      (if (.depends_on // []) != [] then "- **Depends on:** \(.depends_on | join(", "))" else empty end),
      (if (.paths // []) != [] then "- **Paths:** \(.paths | map("`\(.)`") | join(", "))" else empty end),
      (if .model or .effort then "- **Model / effort:** \([.model, .effort] | map(select(.)) | join(" · "))" else empty end),
      (if $n != "" and ($n | startswith("Needs a human:") | not) then "- **Notes:** \($n)" else empty end),
      (if $n | startswith("Needs a human:") then "- **Needs a human:** \($n | ltrimstr("Needs a human:") | sub("^\\s+"; ""))" else empty end),
      (if $file != "" then "", "<details><summary>Plan section (\($file))</summary>", "", "````text", $sec, "````", "", "</details>" else empty end),
      "<!-- harness:details:end -->"' <<< "$1"
}
push() {
  local F="FEATURES.json"; [ "$dry" = 1 ] && [ -f "$tmp/F.json" ] && F="$tmp/F.json"
  jq -c '.features[]' "$F" | while IFS= read -r feat; do
    id="$(jq -r .id <<< "$feat")"
    iss="$(jq -c --arg id "$id" 'first(.[] | select(.title | startswith("[" + $id + "] "))) // empty' "$tmp/issues.json")"
    [ -n "$iss" ] || continue
    n="$(jq -r .number <<< "$iss")"; st="$(jq -r .status <<< "$feat")"
    jq -r '.body // ""' <<< "$iss" | after > "$tmp/after"
    { jq -r '.body // ""' <<< "$iss" | before; printf '\n'; block "$feat"
      if [ -s "$tmp/after" ]; then printf '\n'; cat "$tmp/after"; fi; } > "$tmp/body"
    jq -r '.body // ""' <<< "$iss" > "$tmp/cur"
    if [ "$(cat "$tmp/body")" != "$(cat "$tmp/cur")" ]; then write issue edit "$n" --body-file "$tmp/body"; fi
    want="harness:$st"
    stale="$(jq -r --arg w "$want" '[.labels[].name | select(startswith("harness:") and . != $w)] | join(",")' <<< "$iss")"
    if ! jq -e --arg w "$want" 'any(.labels[]; .name == $w)' <<< "$iss" >/dev/null; then
      ensure_label "$want"; write issue edit "$n" --add-label "$want"
    fi
    [ -z "$stale" ] || write issue edit "$n" --remove-label "$stale"
    state="$(jq -r .state <<< "$iss")"
    if [ "$st" = passing ] && [ "$state" = OPEN ]; then write issue close "$n"
    elif [ "$st" != passing ] && [ "$st" != superseded ] && [ "$state" = CLOSED ]; then write issue reopen "$n"; fi
  done
}
ensure_label() {  # create a label only when the repo lacks it (keeps its colour)
  [ -f "$tmp/labels" ] || gh label list --limit 1000 --json name --jq '.[].name' > "$tmp/labels"
  grep -qxF "$1" "$tmp/labels" && return 0
  write label create "$1" --color ededed; echo "$1" >> "$tmp/labels"
}
write() {  # write <gh args...>: a gh write call, skipped on --dry-run
  if [ "$dry" = 1 ]; then echo "would: gh $*"; else gh "$@" >/dev/null; fi
}

# --- migrate: open features -> new issues; history stays in git --------------
migrate() {
  gh api 'repos/{owner}/{repo}/milestones?state=all&per_page=100' | jq -r '.[].title' > "$tmp/milestones"
  jq -c '.milestones as $ms | .features[] | select(.status == "failing" or .status == "deferred")
         | . + {ms: (if .milestone == null then "" else "M\(.milestone)" + (if $ms[(.milestone | tostring)] then " " + $ms[(.milestone | tostring)] else "" end) end)}' FEATURES.json \
  | while IFS= read -r feat; do
    id="$(jq -r .id <<< "$feat")"
    jq -e --arg id "$id" 'any(.[]; .title | startswith("[" + $id + "] "))' "$tmp/issues.json" >/dev/null && continue
    title="[$id] $(jq -r .title <<< "$feat")"; st="$(jq -r .status <<< "$feat")"; ms="$(jq -r .ms <<< "$feat")"
    {
      jq -r '.title, "",
        (if (.checks // []) != [] then "## Checks", "",
          (.checks[] | "### \(.id) — \(.title)", "- **Critical:** \(if .critical then "yes" else "no" end)", "- **Steps:**",
            (.steps | to_entries[] | "  \(.key + 1). \(.value)"), "- **Pass if:** \(.pass_if)", "- **Evidence:** \(.evidence)", "")
         else empty end)' <<< "$feat" | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}'
      printf '\n'; block "$feat"
    } > "$tmp/body.$id"
    if [ -n "$ms" ] && ! grep -qxF "$ms" "$tmp/milestones"; then
      write api --method POST 'repos/{owner}/{repo}/milestones' -f "title=$ms"; echo "$ms" >> "$tmp/milestones"
    fi
    ensure_label "harness:$st"
    write issue create --title "$title" --body-file "$tmp/body.$id" --label "harness:$st" ${ms:+--milestone "$ms"}
    if [ "$dry" = 1 ]; then echo "issues.sh: would create $title ($ms)"; else echo "issues.sh: created $title ($ms)"; fi
  done
  if [ "$dry" = 1 ]; then echo "would set \"source\": \"issues\" in FEATURES.json"
  else jq '{source: "issues"} + del(.source)' FEATURES.json > "$tmp/F.json" && cp "$tmp/F.json" FEATURES.json; fi
}

if [ "$cmd" = sync ]; then pull; push; else migrate; fi
exit "$rc"
