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
# Run in the repo root. Exit 1 when an issue was skipped; 2 = usage or tools.
# shellcheck disable=SC2016 # single-quoted jq programs use jq variables
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
cmd="${1:-}"; shift || true
dry=0; [ "${1:-}" = "--dry-run" ] && dry=1
case "$cmd" in sync | migrate) ;; *) echo "usage: issues.sh sync|migrate [--dry-run]" >&2; exit 2 ;; esac
for t in jq gh; do command -v "$t" >/dev/null || { echo "ERROR: $t is required" >&2; exit 2; }; done
[ -f FEATURES.json ] || { echo "ERROR: run in the repo root (no FEATURES.json)" >&2; exit 2; }

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
rc=0

if [ "$cmd" = sync ] && [ "$(jq -r '.source // "features"' FEATURES.json)" != issues ]; then
  echo "issues.sh: source is features (set \"source\": \"issues\" in FEATURES.json, or run migrate); nothing to sync"
  exit 0
fi

START='<!-- harness:details:start'
owner_text() {  # stdin: issue body -> the owner's part, generated block removed
  awk -v s="$START" 'index($0, s) == 1 { exit } { print }' | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}'
}

gh issue list --state all --limit 1000 --json number,title,body,state,labels,author > "$tmp/all.json"
# Only issues opened by someone with write access count: on a public repo
# anyone can open "[M9-001] …", and an unattended run would build it.
# (Only the author or a collaborator can edit an issue body afterwards.)
gh api 'repos/{owner}/{repo}/collaborators?per_page=100' --jq '.[] | select(.permissions.push) | .login' > "$tmp/writers"
jq -r --rawfile w "$tmp/writers" '.[] | select((.title | test("^\\[[^]]+\\] ")) and ((.author.login // "") | IN($w | split("\n")[]) | not))
  | "issue #\(.number): opened by \(.author.login // "unknown"), who has no write access; skipped"' "$tmp/all.json" >&2
jq --rawfile w "$tmp/writers" '[.[] | select((.author.login // "") | IN($w | split("\n")[]))]' "$tmp/all.json" > "$tmp/issues.json"

# --- pull: issues -> FEATURES.json (title and checks only) -------------------
pull() {
  : > "$tmp/pulled"
  jq -c '.[] | select(.title | test("^\\[[^]]+\\] "))' "$tmp/issues.json" | while IFS= read -r iss; do
    n="$(jq -r .number <<< "$iss")"
    jq -r '.body // ""' <<< "$iss" | owner_text > "$tmp/owner"
    jq --rawfile b "$tmp/owner" '{number, title, body: $b}' <<< "$iss" > "$tmp/one.json"
    if ! checks="$(bash "$here/read-checks.sh" --issue-json "$tmp/one.json" 2>"$tmp/err" | jq -s .)"; then
      sed "s/^/issue #$n: /" "$tmp/err" >&2; echo skip >> "$tmp/pulled"; continue
    fi
    jq -c --argjson c "$checks" '(.title | capture("^\\[(?<id>[^]]+)\\] (?<t>.*)$")) as $m
      | {id: $m.id, title: $m.t, checks: ($c | map(del(.feature)))}' <<< "$iss" >> "$tmp/pulled"
  done
  grep -q '^skip$' "$tmp/pulled" && rc=1
  grep -v '^skip$' "$tmp/pulled" | jq -s . > "$tmp/pulled.json" || echo '[]' > "$tmp/pulled.json"
  jq --slurpfile p "$tmp/pulled.json" '
    reduce $p[0][] as $i (.;
      if any(.features[]; .id == $i.id) then
        .features |= map(if .id == $i.id then .title = $i.title
          | (if ($i.checks | length) > 0 then .checks = $i.checks else del(.checks) end) else . end)
      else
        .features += [{id: $i.id, milestone: ($i.id | capture("^M(?<m>[0-9]+)-").m? | tonumber? // null),
                       title: $i.title, status: "failing"}
                      + (if ($i.checks | length) > 0 then {checks: $i.checks} else {} end)]
      end)' FEATURES.json > "$tmp/F.json"
  if ! cmp -s FEATURES.json "$tmp/F.json"; then
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
      (if $file != "" then "", "<details><summary>Plan section (\($file))</summary>", "", "```text", $sec, "```", "", "</details>" else empty end),
      "<!-- harness:details:end -->"' <<< "$1"
}
push() {
  local F="FEATURES.json"; [ "$dry" = 1 ] && [ -f "$tmp/F.json" ] && F="$tmp/F.json"
  jq -c '.features[]' "$F" | while IFS= read -r feat; do
    id="$(jq -r .id <<< "$feat")"
    iss="$(jq -c --arg id "$id" 'first(.[] | select(.title | startswith("[" + $id + "] "))) // empty' "$tmp/issues.json")"
    [ -n "$iss" ] || continue
    n="$(jq -r .number <<< "$iss")"; st="$(jq -r .status <<< "$feat")"
    { jq -r '.body // ""' <<< "$iss" | owner_text; printf '\n'; block "$feat"; } > "$tmp/body"
    jq -r '.body // ""' <<< "$iss" > "$tmp/cur"
    if [ "$(cat "$tmp/body")" != "$(cat "$tmp/cur")" ]; then write issue edit "$n" --body-file "$tmp/body"; fi
    want="harness:$st"
    stale="$(jq -r --arg w "$want" '[.labels[].name | select(startswith("harness:") and . != $w)] | join(",")' <<< "$iss")"
    if ! jq -e --arg w "$want" 'any(.labels[]; .name == $w)' <<< "$iss" >/dev/null; then
      write label create "$want" --force --color ededed; write issue edit "$n" --add-label "$want"
    fi
    [ -z "$stale" ] || write issue edit "$n" --remove-label "$stale"
    state="$(jq -r .state <<< "$iss")"
    if [ "$st" = passing ] && [ "$state" = OPEN ]; then write issue close "$n"
    elif [ "$st" != passing ] && [ "$st" != superseded ] && [ "$state" = CLOSED ]; then write issue reopen "$n"; fi
  done
}
write() {  # write <gh args...>: a gh write call, skipped on --dry-run
  if [ "$dry" = 1 ]; then echo "would: gh $*"; else gh "$@" >/dev/null; fi
}

if [ "$cmd" = sync ]; then pull; push; fi
exit "$rc"
