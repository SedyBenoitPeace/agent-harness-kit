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

gh issue list --state all --limit 1000 --json number,title,body,state,labels > "$tmp/issues.json"

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

[ "$cmd" = sync ] && pull
exit "$rc"
