#!/usr/bin/env bash
# harness-run: the brief for one feature (M38-002). Prints its FEATURES.json
# entry and its plan section, so the orchestrator pastes them into the
# builder's prompt instead of handing it the plan path: the builder then
# never reads FEATURES.json or the plan itself.
# Usage: feature.sh <id> [TARGET_DIR] [--prompt builder [--lane <dir>]]
#        feature.sh <id> [TARGET_DIR] --prompt evaluator --range <base>..<head>
# TARGET_DIR defaults to the current directory.
# Plan section = the `## ` heading in docs/plans/active/*.md naming the id, up
# to the next `## `, capped at 80 lines. Exit 2 = usage error or unknown id.
set -euo pipefail
usage() {
  echo "usage: feature.sh <id> [target] [--prompt builder [--lane <dir>]]" >&2
  echo "       feature.sh <id> [target] --prompt evaluator --range <base>..<head>" >&2
  exit 2
}

id="${1:-}"
[ -n "$id" ] || usage
shift
target=.
if [ "$#" -gt 0 ] && [[ "$1" != --* ]]; then
  target="${1:-.}"
  shift
fi

prompt=''
lane=''
range=''
if [ "$#" -gt 0 ]; then
  [ "$1" = --prompt ] && [ "$#" -ge 2 ] || usage
  prompt="$2"
  shift 2
  case "$prompt" in
    builder)
      if [ "$#" -gt 0 ]; then
        [ "$#" -eq 2 ] && [ "$1" = --lane ] && [ -n "$2" ] || usage
        lane="$2"
      fi
      ;;
    evaluator)
      [ "$#" -eq 2 ] && [ "$1" = --range ] && [[ "$2" == ?*..?* ]] || usage
      range="$2"
      ;;
    *) usage ;;
  esac
  kit="$(cd "$(dirname "$0")/../../.." && pwd -P)"
fi

cd "$target"
command -v jq >/dev/null || { echo "ERROR: jq is required" >&2; exit 2; }
[ -f FEATURES.json ] || { echo "feature: no FEATURES.json here" >&2; exit 2; }
entry="$(jq --arg i "$id" '[.features[] | select(.id == $i)][0] // empty' FEATURES.json)"
[ -n "$entry" ] || { echo "feature: no feature $id in FEATURES.json" >&2; exit 2; }

if [ -n "$prompt" ]; then
  # Strip frontmatter and expand the builder role's template examples.
  awk -v id="$id" -v role="$prompt" '
    c<2 { if (/^---$/) c++; next }
    role=="builder" {
      sub(/`can-merge[.]sh <pr> --merge`/, "`can-merge.sh` with the PR number followed by `--merge`")
      sub(/`Needs a human: <the design question>`/, "`Needs a human:` followed by the design question")
      if (/^End with the line `SESSION:/) {
        print "End with a SESSION line in this format, for example:"
        print "SESSION: " id " · passing · gate green · abc1234"
        print "Use the actual status (passing, review, or blocked), gate color (green or red), and commit or reason."
        next
      }
    }
    { print }
  ' "$kit/agents/src/harness-$prompt.md"
  echo
fi
if [ "$prompt" = builder ]; then
  printf 'Run one harness session for %s. ' "$id"
  if [ -n "$lane" ]; then
    printf 'Work and commit only in the parallel lane %q, on branch lane/%s (cd there first). A lane never touches FEATURES.json or PROGRESS.md: put the Decisions: line in the commit body. Skip can-merge.sh and opening a PR: the orchestrator merges lanes. End with SESSION status review. ' "$lane" "$id"
  fi
  printf "Start with \`bash %q --brief\` and follow its Session protocol; do not cat SKILL.md, AGENTS.md, docs/agents/, FEATURES.json or the plan.\n\n" \
    "$kit/skills/harness-session/scripts/context.sh"
fi

echo "== Feature $id =="
printf '%s\n' "$entry"
echo
if [ "$prompt" = evaluator ]; then
  printf 'Commit range: %s\n' "$range"
  exit 0
fi
echo "== Plan section =="
found=0
for pf in docs/plans/active/*.md; do
  [ -f "$pf" ] || continue
  section="$(awk -v id="$id" '/^## /{ on = (index($0, id) > 0) } on' "$pf")"
  [ -n "$section" ] || continue
  found=1
  echo "PLAN: $pf"
  printf '%s\n' "$section" | head -80
  n="$(printf '%s\n' "$section" | wc -l | tr -d ' ')"
  [ "$n" -le 80 ] || echo "(section cut at 80 of $n lines: sed -n the rest from $pf)"
done
[ "$found" -eq 1 ] || echo "PLAN: no section naming $id in docs/plans/active/"
# a hint the human left on the board (M49-001): .harness-run/hints/<id>.md in the main repo
root="$PWD"; gc="$(git rev-parse --git-common-dir 2>/dev/null)" && root="$(cd "$gc/.." && pwd -P)"
hf="$root/.harness-run/hints/$id.md"
if [ -s "$hf" ]; then
  echo
  echo "== Human hint =="
  cat "$hf"
fi
