#!/usr/bin/env bash
# can-merge.sh — may the agent merge its own PR? The script decides, not the
# model (M56, decisions 12-14). Run in the repo root.
#
#   can-merge.sh <pr> [--merge]   # MERGE (exit 0), HOLD (exit 1) or WAIT (exit 3)
#   can-merge.sh --list           # the protected path patterns in force
#
# MERGE needs every rule: automerge not switched off in FEATURES.json; the PR
# open, mergeable and labelled harness:agent (agent PRs only); every feature
# id it names in title or body exists with "automerge": true (at least one);
# CI checks all passed, or with no checks the gate (scripts/e2e.sh) green on
# the PR head checked out; no changed path matches a protected pattern; no
# test file deleted and no skip/only/fixme added to one. --merge merges only
# on MERGE, pinned to the head commit that was checked. Config: FEATURES.json
# "automerge": {"enabled", "protected": [regex]}. Grants and config are read
# from the base branch (origin/<base>), never from the PR: a PR cannot grant
# itself. The gate and the kit's QA scripts are always protected.
# shellcheck disable=SC2016 # single-quoted jq programs use jq variables
set -euo pipefail

DEFAULT_PROTECTED='^\.github/
(^|/)migrations?/
(^|/)[^/]*migration[^/]*$
(^|/)auth[^/]*(/|$)
(^|/)\.env
secret
\.(pem|key|p12|keystore|jks)$
(^|/)(package\.json|package-lock\.json|yarn\.lock|pnpm-lock\.yaml|bun\.lockb?|requirements[^/]*\.txt|pyproject\.toml|poetry\.lock|Pipfile(\.lock)?|Gemfile(\.lock)?|go\.(mod|sum)|Cargo\.(toml|lock)|pubspec\.(yaml|lock)|Podfile(\.lock)?|Package\.(swift|resolved)|composer\.(json|lock)|build\.gradle(\.kts)?)$
(^|/)(Dockerfile[^/]*|docker-compose[^/]*|fly\.toml|vercel\.json|netlify\.toml|railway\.(json|toml)|Procfile|app\.yaml|render\.yaml)$
\.tf$
(^|/)(deploy|infra|terraform|k8s|helm)/'
ALWAYS_PROTECTED='^\.github/
^scripts/e2e\.sh$
(^|/)(can-merge|check-coverage|read-checks|acceptance-verdict)\.sh$'
TEST_FILE='(^|/)(tests?|e2e|spec|__tests__)/|\.(spec|test)\.[A-Za-z]+$|_test\.[A-Za-z]+$|(^|/)test_[^/]*\.py$|Tests?\.swift$'
WEAKEN='\.(skip|only|fixme|todo)\(|(^|[^A-Za-z])(xit|xdescribe|xtest)\(|@pytest\.mark\.skip|t\.Skip\(|XCTSkip'

command -v jq >/dev/null || { echo "ERROR: jq is required" >&2; exit 2; }
[ -f FEATURES.json ] || { echo "ERROR: run in the repo root (no FEATURES.json)" >&2; exit 2; }
protected_from() {  # protected_from <FEATURES.json>: configured or default list, plus the always list
  local p; p="$(jq -r '.automerge.protected // empty | .[]' "$1")"
  printf '%s\n%s\n' "${p:-$DEFAULT_PROTECTED}" "$ALWAYS_PROTECTED"
}
if [ "${1:-}" = "--list" ]; then protected_from FEATURES.json; exit 0; fi

pr="${1:-}"; merge=0
case "$pr" in '' | *[!0-9]*) echo "usage: can-merge.sh <pr number> [--merge] | --list" >&2; exit 2 ;; esac
case "${2:-}" in '') ;; --merge) merge=1 ;; *) echo "usage: can-merge.sh <pr number> [--merge] | --list" >&2; exit 2 ;; esac
command -v gh >/dev/null || { echo "ERROR: gh is required" >&2; exit 2; }

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
gh pr view "$pr" --json number,state,mergeable,title,body,labels,baseRefName,headRefOid,statusCheckRollup > "$tmp/pr.json"
head="$(jq -r .headRefOid "$tmp/pr.json")"; baseref="$(jq -r .baseRefName "$tmp/pr.json")"
holds=()
hold() { holds+=("$1"); }

# the owner's policy: FEATURES.json as it is on the base branch, not in the PR
P="$tmp/base-features.json"
if ! git fetch -q origin "$baseref" 2>/dev/null || ! git show "origin/$baseref:FEATURES.json" > "$P" 2>/dev/null; then
  echo "HOLD"; echo "- cannot read FEATURES.json on origin/$baseref (the grants and protected list live there)"; exit 1
fi
protected="$(protected_from "$P")"

[ "$(jq -r '.automerge.enabled != false' "$P")" = true ] || hold "automerge is off for this repo (FEATURES.json automerge.enabled)"
[ "$(jq -r .state "$tmp/pr.json")" = OPEN ] || hold "PR is not open"
m="$(jq -r '.mergeable // "UNKNOWN"' "$tmp/pr.json")"
[ "$m" = MERGEABLE ] || hold "not mergeable ($m)"
jq -e 'any(.labels[]?; .name == "harness:agent")' "$tmp/pr.json" >/dev/null || hold "not labelled harness:agent (only agent PRs merge themselves)"

# features the PR names: all must exist and be granted
ids="$(jq -r '"\(.title) \(.body // "")"' "$tmp/pr.json" | grep -oE 'M[0-9]+-[0-9]+' | sort -u || true)"
if [ -z "$ids" ]; then hold "names no feature (M<n>-<nnn>) in title or body"; fi
for id in $ids; do
  g="$(jq -r --arg id "$id" 'first(.features[] | select(.id == $id) | (.automerge == true | tostring)) // "missing"' "$P")"
  case "$g" in true) ;; missing) hold "$id: no such feature in FEATURES.json on $baseref (a grant counts once it is there)" ;; *) hold "$id: not granted automerge on $baseref" ;; esac
done

# changed files from GitHub (exact names, rename sources, deletions), then
# added lines per file from the diff for the weakened-test check
gh api "repos/{owner}/{repo}/pulls/$pr/files?per_page=100" --paginate > "$tmp/files.json"
while IFS=$'\t' read -r status file prev; do
  for path in "$file" ${prev:+"$prev"}; do
    while IFS= read -r re; do
      [ -n "$re" ] && printf '%s\n' "$path" | grep -qE -- "$re" && { hold "protected path: $path (matches $re)"; break; }
    done <<< "$protected"
  done
  if [ "$status" = removed ] && printf '%s\n' "$file" | grep -qE -- "$TEST_FILE"; then hold "test deleted: $file"; fi
  if [ -n "$prev" ] && printf '%s\n' "$prev" | grep -qE -- "$TEST_FILE" && ! printf '%s\n' "$file" | grep -qE -- "$TEST_FILE"; then
    hold "test deleted: $prev (renamed to $file)"
  fi
done < <(jq -r '.[] | "\(.status)\t\(.filename)\t\(.previous_filename // "")"' "$tmp/files.json")
gh pr diff "$pr" > "$tmp/pr.diff"
awk '
  /^diff --git / { cur = ""; if (match($0, / b\/.*$/)) cur = substr($0, RSTART + 3); next }
  /^\+\+\+ / { p = substr($0, 5); gsub(/^"|"$/, "", p); if (p != "/dev/null") { sub(/^b\//, "", p); cur = p }; next }
  /^--- / { next }
  /^\+/ { print cur "\t" substr($0, 2) }
' "$tmp/pr.diff" > "$tmp/added"
while IFS=$'\t' read -r path line; do
  printf '%s\n' "$path" | grep -qE -- "$TEST_FILE" && printf '%s\n' "$line" | grep -qE -- "$WEAKEN" \
    && hold "test weakened in $path: $line"
done < "$tmp/added"

# checks: failed ones hold, running ones wait; none at all -> the local gate
checks="$(jq -c '[.statusCheckRollup[]? | {name: (.name // .context // "check"),
  state: (if has("status") then (if .status != "COMPLETED" then "PENDING" else (.conclusion // "PENDING") end) else (.state // "PENDING") end)}]' "$tmp/pr.json")"
pending=0
while IFS=$'\t' read -r name st; do
  case "$st" in
    SUCCESS | NEUTRAL | SKIPPED) ;;
    PENDING | EXPECTED | QUEUED | IN_PROGRESS | WAITING) pending=1 ;;
    *) hold "check $name: $st" ;;
  esac
done < <(jq -r '.[] | "\(.name)\t\(.state)"' <<< "$checks")
if [ "$(jq length <<< "$checks")" = 0 ] && [ "${#holds[@]}" = 0 ]; then
  if [ "$(git rev-parse HEAD 2>/dev/null)" != "$head" ]; then
    hold "no CI checks: check out the PR head to run the local gate"
  elif ! bash scripts/e2e.sh > "$tmp/gate.log" 2>&1; then
    hold "no CI checks and the local gate (scripts/e2e.sh) failed"
  fi
fi

if [ "${#holds[@]}" -gt 0 ]; then printf 'HOLD\n'; printf -- '- %s\n' "${holds[@]}"; exit 1; fi
if [ "$pending" = 1 ]; then echo "WAIT"; echo "- checks still running; run again when they finish"; exit 3; fi
echo "MERGE"
echo "- $(echo "$ids" | tr '\n' ' ')granted, checks green, no protected path or test touched"
# pinned: GitHub refuses the merge if the PR moved since it was checked
if [ "$merge" = 1 ]; then gh pr merge "$pr" --merge --delete-branch --match-head-commit "$head" >/dev/null && echo "- merged #$pr at $head"; fi
