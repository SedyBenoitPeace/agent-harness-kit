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
# on MERGE. Config: FEATURES.json "automerge": {"enabled", "protected": [regex]}.
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
TEST_FILE='(^|/)(tests?|e2e|spec|__tests__)/|\.(spec|test)\.[A-Za-z]+$|_test\.[A-Za-z]+$|(^|/)test_[^/]*\.py$|Tests?\.swift$'
WEAKEN='\.(skip|only|fixme|todo)\(|(^|[^A-Za-z])(xit|xdescribe|xtest)\(|@pytest\.mark\.skip|t\.Skip\(|XCTSkip'

command -v jq >/dev/null || { echo "ERROR: jq is required" >&2; exit 2; }
[ -f FEATURES.json ] || { echo "ERROR: run in the repo root (no FEATURES.json)" >&2; exit 2; }
protected="$(jq -r '.automerge.protected // empty | .[]' FEATURES.json)"
[ -n "$protected" ] || protected="$DEFAULT_PROTECTED"
if [ "${1:-}" = "--list" ]; then printf '%s\n' "$protected"; exit 0; fi

pr="${1:-}"; merge=0
case "$pr" in '' | *[!0-9]*) echo "usage: can-merge.sh <pr number> [--merge] | --list" >&2; exit 2 ;; esac
case "${2:-}" in '') ;; --merge) merge=1 ;; *) echo "usage: can-merge.sh <pr number> [--merge] | --list" >&2; exit 2 ;; esac
command -v gh >/dev/null || { echo "ERROR: gh is required" >&2; exit 2; }

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
gh pr view "$pr" --json number,state,mergeable,title,body,labels,headRefOid,statusCheckRollup > "$tmp/pr.json"
gh pr diff "$pr" > "$tmp/pr.diff"
holds=()
hold() { holds+=("$1"); }

[ "$(jq -r '.automerge.enabled != false' FEATURES.json)" = true ] || hold "automerge is off for this repo (FEATURES.json automerge.enabled)"
[ "$(jq -r .state "$tmp/pr.json")" = OPEN ] || hold "PR is not open"
m="$(jq -r '.mergeable // "UNKNOWN"' "$tmp/pr.json")"
[ "$m" = MERGEABLE ] || hold "not mergeable ($m)"
jq -e 'any(.labels[]?; .name == "harness:agent")' "$tmp/pr.json" >/dev/null || hold "not labelled harness:agent (only agent PRs merge themselves)"

# features the PR names: all must exist and be granted
ids="$(jq -r '"\(.title) \(.body // "")"' "$tmp/pr.json" | grep -oE 'M[0-9]+-[0-9]+' | sort -u || true)"
if [ -z "$ids" ]; then hold "names no feature (M<n>-<nnn>) in title or body"; fi
for id in $ids; do
  g="$(jq -r --arg id "$id" 'first(.features[] | select(.id == $id) | (.automerge == true | tostring)) // "missing"' FEATURES.json)"
  case "$g" in true) ;; missing) hold "$id: no such feature in FEATURES.json" ;; *) hold "$id: not granted automerge" ;; esac
done

# changed paths, deleted files and added lines, from the unified diff
awk '
  /^diff --git / { a = $3; b = $4; sub(/^a\//, "", a); sub(/^b\//, "", b); print "F\t" b; if (a != b) print "F\t" a; cur = b; next }
  /^deleted file mode/ { print "D\t" a; next }
  /^\+\+\+ / || /^--- / { next }
  /^\+/ { print "+\t" cur "\t" substr($0, 2) }
' "$tmp/pr.diff" > "$tmp/changes"
while IFS=$'\t' read -r kind path line; do
  case "$kind" in
    F) while IFS= read -r re; do
         [ -n "$re" ] && printf '%s\n' "$path" | grep -qE -- "$re" && { hold "protected path: $path (matches $re)"; break; }
       done <<< "$protected" ;;
    D) printf '%s\n' "$path" | grep -qE -- "$TEST_FILE" && hold "test deleted: $path" ;;
    +) printf '%s\n' "$path" | grep -qE -- "$TEST_FILE" && printf '%s\n' "$line" | grep -qE -- "$WEAKEN" \
         && hold "test weakened in $path: $line" ;;
  esac
done < "$tmp/changes"

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
  if [ "$(git rev-parse HEAD 2>/dev/null)" != "$(jq -r .headRefOid "$tmp/pr.json")" ]; then
    hold "no CI checks: check out the PR head to run the local gate"
  elif ! bash scripts/e2e.sh > "$tmp/gate.log" 2>&1; then
    hold "no CI checks and the local gate (scripts/e2e.sh) failed"
  fi
fi

if [ "${#holds[@]}" -gt 0 ]; then printf 'HOLD\n'; printf -- '- %s\n' "${holds[@]}"; exit 1; fi
if [ "$pending" = 1 ]; then echo "WAIT"; echo "- checks still running; run again when they finish"; exit 3; fi
echo "MERGE"
echo "- $(echo "$ids" | tr '\n' ' ')granted, checks green, no protected path or test touched"
if [ "$merge" = 1 ]; then gh pr merge "$pr" --merge --delete-branch >/dev/null && echo "- merged #$pr"; fi
