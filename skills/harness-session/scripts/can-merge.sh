#!/usr/bin/env bash
# can-merge.sh — may the agent merge its own PR? The script decides, not the
# model (M56, decisions 12-14). Run in the repo root, on the PR head.
#
#   can-merge.sh <pr> [--merge]   # MERGE (exit 0), HOLD (exit 1) or WAIT (exit 3)
#   can-merge.sh --list           # the protected path patterns in force
#
# MERGE needs every rule: the PR open, not a draft, mergeable, into the
# default branch, labelled harness:agent (agent PRs only); automerge not
# switched off; every feature id it names granted "automerge": true; the PR
# not changing any automerge setting; checks green (or, with no passing
# check, the gate scripts/e2e.sh green on the PR head in a clean tree); no
# changed path matching a protected pattern; no test deleted, renamed away,
# shrunk or skipped. Grants and config come from FEATURES.json on the base
# branch, never from the PR. --merge merges pinned to the checked head and
# prints MERGE only when GitHub accepted it. Any failure to read is a HOLD.
# Config: FEATURES.json "automerge": {"enabled": false, "protected": [regex]}.
# Patterns are extended regexes, matched case-insensitively.
# shellcheck disable=SC2016 # single-quoted jq programs use jq variables
set -euo pipefail

DEFAULT_PROTECTED='(^|/)migrations?/
(^|/)[^/]*migration[^/]*$
(^|/)db/(migrate/|schema\.(rb|sql|prisma))
(^|/)alembic/
(^|/)auth[^/]*(/|$)
(oauth|login|jwt|passport)
(^|/)\.env
secret
\.(pem|key|p12|keystore|jks)$
(^|/)(package\.json|package-lock\.json|yarn\.lock|pnpm-lock\.yaml|bun\.lockb?|requirements[^/]*\.txt|pyproject\.toml|poetry\.lock|uv\.lock|Pipfile(\.lock)?|Gemfile(\.lock)?|go\.(mod|sum)|Cargo\.(toml|lock)|pubspec\.(yaml|lock)|Podfile(\.lock)?|Package\.(swift|resolved)|composer\.(json|lock)|build\.gradle(\.kts)?|\.npmrc)$
(^|/)(Dockerfile[^/]*|docker-compose[^/]*|fly\.toml|vercel\.json|netlify\.toml|railway\.(json|toml)|wrangler\.toml|Procfile|app\.yaml|render\.yaml|\.gitlab-ci\.yml)$
\.tf$
(^|/)(deploy|infra|terraform|k8s|helm)/
(^|/)(playwright|jest|vitest|cypress|karma)\.conf(ig)?\.|(^|/)(pytest\.ini|conftest\.py|tox\.ini|setup\.cfg|phpunit\.xml(\.dist)?|Makefile|\.mocharc[^/]*)$'
# never overridable: CI of any system, the gate, the kit's scripts, agent
# instructions and agent configuration (they steer the next agent)
ALWAYS_PROTECTED='^\.github/
^\.(circleci|buildkite)/
(^|/)Jenkinsfile$
(^|/)(azure-pipelines|bitbucket-pipelines|\.travis|\.gitlab-ci)\.ya?ml$
(^|/)\.(claude|cursor|codex|gemini|windsurf|clinerules)/
(^|/)\.(mcp\.json|cursorrules|windsurfrules|clinerules)$
(^|/)CODEOWNERS$
(^|/)(AGENTS|CLAUDE|GEMINI)\.md$
^docs/agents/
^scripts/e2e\.sh$
(^|/)(can-merge|check-coverage|read-checks|acceptance-verdict|run-gate|quiet|context)\.sh$'
TEST_FILE='(^|/)(tests?|e2e|spec|__tests__)/|(^|/)[^/]*\.Tests?/|\.(spec|test)\.[A-Za-z]+$|_test\.[A-Za-z]+$|(^|/)test_[^/]*\.py$|(^|/)test-[^/]*\.sh$|Tests?\.(swift|cs|java|kt)$|_spec\.rb$'
# added lines that switch a test off: anywhere (unambiguous) / in test files
SKIP_ANY='#\[ignore\]|@(Disabled|Ignore)\b|XCTSkip|markTestSkipped|skipTest\(|unittest\.skip|@pytest\.mark\.(skip|xfail)|t\.Skip(Now|f)?\(|@tag :skip'
SKIP_TEST='\.(skip|only|fixme|todo|fail)[[:space:]]*[.(]|^\+[[:space:]]*pending\b|(^|[^A-Za-z_.])pending[[:space:]]*\(|\[.(skip|only|fixme|todo).\]|(^|[^A-Za-z])(xit|xdescribe|xtest|xcontext)\b|^\+[[:space:]]*skip\b|skip: *true'

say() { printf '%s\n' "$@"; }
die_hold() { say HOLD "- $1"; exit 1; }
command -v jq >/dev/null || { echo "ERROR: jq is required" >&2; exit 2; }
[ -f FEATURES.json ] || { echo "ERROR: run in the repo root (no FEATURES.json)" >&2; exit 2; }
protected_from() {  # protected_from <FEATURES.json>: configured or default list, plus the always list
  local p; p="$(jq -r '.automerge.protected // empty | .[]' "$1")"
  printf '%s\n%s\n' "${p:-$DEFAULT_PROTECTED}" "$ALWAYS_PROTECTED"
}
base_features() {  # base_features <ref> > file: FEATURES.json from the PR's repo on GitHub
  gh api "repos/{owner}/{repo}/contents/FEATURES.json?ref=$1" 2>/dev/null | jq -er '.content | gsub("\n"; "") | @base64d'
}
if [ "${1:-}" = "--list" ]; then
  # what is enforced: the default branch's policy when GitHub answers, else this checkout's
  f="$(mktemp)"; d="$(gh repo view --json defaultBranchRef --jq .defaultBranchRef.name 2>/dev/null || true)"
  { [ -n "$d" ] && base_features "$d" > "$f"; } || cp FEATURES.json "$f"
  protected_from "$f"; rm -f "$f"; exit 0
fi

pr="${1:-}"; merge=0
case "$pr" in '' | *[!0-9]*) echo "usage: can-merge.sh <pr number> [--merge] | --list" >&2; exit 2 ;; esac
case "${2:-}" in '') ;; --merge) merge=1 ;; *) echo "usage: can-merge.sh <pr number> [--merge] | --list" >&2; exit 2 ;; esac
command -v gh >/dev/null || { echo "ERROR: gh is required" >&2; exit 2; }

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
if ! gh pr view "$pr" --json number,state,isDraft,mergeable,title,body,labels,baseRefName,headRefOid,statusCheckRollup \
     > "$tmp/pr.json" 2>/dev/null || ! jq -e 'type == "object"' "$tmp/pr.json" >/dev/null 2>&1; then
  die_hold "could not read PR #$pr"
fi
head="$(jq -r .headRefOid "$tmp/pr.json")"; baseref="$(jq -r .baseRefName "$tmp/pr.json")"
default="$(gh repo view --json defaultBranchRef --jq .defaultBranchRef.name 2>/dev/null)" || die_hold "could not read the default branch"
holds=()
hold() { holds+=("$1"); }

[ "$baseref" = "$default" ] || die_hold "base is $baseref, not the default branch ($default)"
# the owner's policy: FEATURES.json on the base branch of the PR's own repo
P="$tmp/base.json"
if ! base_features "$baseref" > "$P" || ! jq -e . "$P" >/dev/null 2>&1; then
  die_hold "cannot read FEATURES.json on $baseref (the grants and protected list live there)"
fi
protected="$(protected_from "$P")"
while IFS= read -r re; do
  [ -z "$re" ] && continue
  rc=0; printf 'x\n' | grep -qiE -- "$re" 2>/dev/null || rc=$?
  [ "$rc" -le 1 ] || hold "invalid protected pattern: $re"
done <<< "$protected"

[ "$(jq -r '.automerge.enabled != false' "$P")" = true ] || hold "automerge is off for this repo (FEATURES.json automerge.enabled)"
[ "$(jq -r .state "$tmp/pr.json")" = OPEN ] || hold "PR is not open"
[ "$(jq -r '.isDraft // false' "$tmp/pr.json")" = false ] || hold "PR is a draft"
m="$(jq -r '.mergeable // "UNKNOWN"' "$tmp/pr.json")"
[ "$m" = MERGEABLE ] || hold "not mergeable ($m)"
jq -e 'any(.labels[]?; .name == "harness:agent")' "$tmp/pr.json" >/dev/null || hold "not labelled harness:agent (only agent PRs merge themselves)"

ids="$(jq -r '"\(.title) \(.body // "")"' "$tmp/pr.json" | grep -oE 'M[0-9]+-[0-9]+' | sort -u || true)"
[ -n "$ids" ] || hold "names no feature (M<n>-<nnn>) in title or body"
for id in $ids; do
  g="$(jq -r --arg id "$id" 'first(.features[] | select(.id == $id) | (.automerge == true | tostring)) // "missing"' "$P")"
  case "$g" in true) ;; missing) hold "$id: no such feature in FEATURES.json on $baseref (a grant counts once it is there)" ;; *) hold "$id: not granted automerge on $baseref" ;; esac
done

# changed files, exact names and per-file patches, from GitHub
gh api "repos/{owner}/{repo}/pulls/$pr/files?per_page=100" --paginate > "$tmp/files.json" 2>/dev/null \
  || die_hold "could not list the PR's files"
jq -s 'add // []' "$tmp/files.json" > "$tmp/f.json" 2>/dev/null || die_hold "could not parse the PR's files"
matches() { printf '%s\n' "$1" | grep -qiE -- "$2" 2>/dev/null; }
# unit separator, not tab: bash collapses empty tab-separated fields
while IFS=$'\x1f' read -r status file prev adds dels; do
  for path in "$file" ${prev:+"$prev"}; do
    while IFS= read -r re; do
      [ -n "$re" ] && matches "$path" "$re" && { hold "protected path: $path (matches $re)"; break; }
    done <<< "$protected"
  done
  if [ "$file" = FEATURES.json ]; then
    # the PR's own change: head against where it branched off (not today's base)
    if { git cat-file -e "$head^{commit}" 2>/dev/null || git fetch -q origin "$head" 2>/dev/null; } \
       && git fetch -q origin "$baseref" 2>/dev/null && mb="$(git merge-base "$head" "origin/$baseref" 2>/dev/null)" \
       && git show "$head:FEATURES.json" > "$tmp/head.json" 2>/dev/null && git show "$mb:FEATURES.json" > "$tmp/mb.json" 2>/dev/null; then
      q='[.automerge, (.features[]? | select(.automerge != null) | {id, automerge})]'
      [ "$(jq -c "$q" "$tmp/mb.json")" = "$(jq -c "$q" "$tmp/head.json")" ] || hold "PR changes automerge settings in FEATURES.json (only the owner grants)"
    else
      hold "cannot compare FEATURES.json between the PR head and where it branched"
    fi
  fi
  if matches "$file" "$TEST_FILE"; then
    [ "$status" != removed ] || hold "test deleted: $file"
    if [ "$status" != added ] && [ "${dels:-0}" -gt "${adds:-0}" ]; then hold "test shrank: $file (+$adds -$dels)"; fi
  fi
  if [ -n "$prev" ] && matches "$prev" "$TEST_FILE"; then
    if matches "$file" "$TEST_FILE"; then hold "test renamed: $prev -> $file (a runner may stop collecting it)"
    else hold "test deleted: $prev (renamed to $file)"; fi
  fi
done < <(jq -r '.[] | [.status, .filename, (.previous_filename // ""), (.additions // 0 | tostring), (.deletions // 0 | tostring)] | join("\u001f")' "$tmp/f.json")
if jq -e 'any(.[]; (.filename + (.previous_filename // "")) | test("[\u0000-\u001f\u007f]"))' "$tmp/f.json" >/dev/null; then
  hold "control character in a file name"
fi
n="$(jq length "$tmp/f.json")"
for ((k = 0; k < n; k++)); do
  file="$(jq -r ".[$k].filename" "$tmp/f.json")"
  [ "$(jq -r ".[$k].status" "$tmp/f.json")" != removed ] || continue
  intest=0; matches "$file" "$TEST_FILE" && intest=1
  if ! jq -e ".[$k] | has(\"patch\")" "$tmp/f.json" >/dev/null; then
    # no patch: binary or too large; an existing test file changed unseen waits
    if [ "$intest" = 1 ] && [ "$(jq -r ".[$k].status" "$tmp/f.json")" != added ]; then
      hold "test $file: GitHub sent no patch (too large); the owner reviews it"
    fi
    continue
  fi
  jq -r ".[$k].patch" "$tmp/f.json" | grep '^+' > "$tmp/added" || true
  if grep -qE -- "$SKIP_ANY" "$tmp/added" || { [ "$intest" = 1 ] && grep -qE -- "$SKIP_TEST" "$tmp/added"; }; then
    hold "test weakened in $file"
  fi
done

# checks: failed ones hold, running ones wait; no passing check -> the local gate
checks="$(jq -c '[.statusCheckRollup[]? | {name: (.name // .context // "check"),
  state: (if has("status") then (if .status != "COMPLETED" then "PENDING" else (.conclusion // "PENDING") end) else (.state // "PENDING") end)}]' "$tmp/pr.json")"
# a passing check counts as the gate only when the owner named it in
# FEATURES.json automerge.required_checks; otherwise the local gate always runs
required="$(jq -r '.automerge.required_checks // [] | .[]' "$P")"
pending=0; passed=0
while IFS= read -r rq; do
  [ -n "$rq" ] || continue
  st="$(jq -r --arg n "$rq" 'first(.[] | select(.name == $n) | .state) // "MISSING"' <<< "$checks")"
  case "$st" in SUCCESS) passed=1 ;; MISSING) hold "required check $rq was not reported" ;; *) ;; esac
done <<< "$required"
while IFS=$'\t' read -r name st; do
  case "$st" in
    SUCCESS | NEUTRAL | SKIPPED) ;;
    PENDING | EXPECTED | QUEUED | IN_PROGRESS | WAITING | REQUESTED) pending=1 ;;
    *) hold "check $name: $st" ;;
  esac
done < <(jq -r '.[] | "\(.name)\t\(.state)"' <<< "$checks")
if [ "$passed" = 0 ] && [ "$pending" = 0 ] && [ "${#holds[@]}" = 0 ]; then
  if [ "$(git rev-parse HEAD 2>/dev/null)" != "$head" ]; then
    hold "no passing CI check: check out the PR head to run the local gate"
  elif [ -n "$(git status --porcelain 2>/dev/null)" ]; then
    hold "no passing CI check and the working tree is not clean: the local gate must run on the PR head as committed"
  elif ! bash scripts/e2e.sh > "$tmp/gate.log" 2>&1; then
    hold "no passing CI check and the local gate (scripts/e2e.sh) failed"
  fi
fi

# the PR must not have moved while it was being checked
now="$(gh pr view "$pr" --json headRefOid --jq .headRefOid 2>/dev/null || true)"
[ "$now" = "$head" ] || hold "the PR head moved during the check ($head -> ${now:-unknown}); run again"

if [ "${#holds[@]}" -gt 0 ]; then say HOLD; printf -- '- %s\n' "${holds[@]}"; exit 1; fi
if [ "$pending" = 1 ]; then say WAIT "- checks still running; run again when they finish"; exit 3; fi
why="- $(echo "$ids" | tr '\n' ' ')granted, checks green, no protected path or test touched"
if [ "$merge" = 1 ]; then
  # pinned: GitHub refuses the merge if the PR moved since it was checked
  if err="$(gh pr merge "$pr" --merge --delete-branch --match-head-commit "$head" 2>&1 >/dev/null)"; then
    say MERGE "$why" "- merged #$pr at $head"
  else
    say HOLD "- GitHub refused the merge: $err"; exit 1
  fi
else
  say MERGE "$why"
fi
