#!/usr/bin/env bash
# harness-run: a second opinion from another vendor's agent (M26-001).
# Usage: second-opinion.sh <claude|codex|copilot> <feature-id> <base-commit> [TARGET_DIR]
# Runs that CLI non-interactively and read-only, as the harness evaluator, on
# the commits base..HEAD, with the strong model from agents/models.json.
# Prints VERDICT: PASS | NEEDS_WORK | REJECTED, the CLI and model, then the
# agent's reply. Writes nothing to the target repo.
# Exit codes: 0 PASS; 1 NEEDS_WORK, or REJECTED (the agent changed the tree
# or HEAD; the change is left for the human); 2 broken (unknown or missing
# CLI, unknown feature, dirty tree before the run).
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
kit="$here/../../.."
cli="${1:?usage: second-opinion.sh <claude|codex|copilot> <feature-id> <base> [repo]}"
id="${2:?feature id missing}"
base="${3:?base commit missing}"
target="${4:-.}"

broken() { echo "SECOND OPINION BROKEN: $*" >&2; exit 2; }

case "$cli" in claude|codex|copilot) ;; *) broken "unknown CLI '$cli' (use claude, codex or copilot)" ;; esac
command -v "$cli" >/dev/null || broken "$cli is not installed or not on PATH"
command -v jq >/dev/null || broken "jq is required"

cd "$target"
entry="$(jq -c --arg id "$id" '.features[]? | select(.id == $id)' FEATURES.json 2>/dev/null || true)"
[ -n "$entry" ] || broken "no feature $id in FEATURES.json"
[ -z "$(git status --porcelain)" ] || broken "the tree is dirty; commit or stash before a second opinion"
head_before="$(git rev-parse HEAD)"

model="$(jq -r --arg c "$cli" '.models[$c].strong // empty' "$kit/agents/models.json")"
[ -n "$model" ] || broken "no strong model for $cli in agents/models.json"

# The evaluator role, as gen-agents.sh writes it for every CLI.
role="$(awk 'c>=2{print} /^---$/{c++}' "$kit/agents/src/harness-evaluator.md")"
prompt="$role

Effort: high.

You are giving a second opinion on work another agent built. Do not edit,
create or delete files, and do not commit.

Feature entry:
$entry

Commit range: ${base}..HEAD"

work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
reply="$work/reply"

case "$cli" in
  codex)
    codex exec --sandbox read-only --ephemeral -m "$model" -o "$reply" "$prompt" > "$work/log" 2>&1 || true ;;
  claude)
    claude -p "$prompt" --model "$model" --permission-mode dontAsk \
      --allowedTools Read Grep Glob Bash --disallowedTools Edit Write NotebookEdit > "$reply" 2> "$work/log" || true ;;
  copilot)
    copilot -p "$prompt" -s --no-ask-user --model "$model" --allow-all-tools --deny-tool=write \
      --deny-tool='shell(git commit)' --deny-tool='shell(git push)' --deny-tool='shell(git reset)' \
      --deny-tool='shell(git checkout)' --deny-tool='shell(rm)' > "$reply" 2> "$work/log" || true ;;
esac
touch "$reply"

# Read-only flags differ per CLI; this check is the guarantee.
changes="$(git status --porcelain)"
if [ "$(git rev-parse HEAD)" != "$head_before" ] || [ -n "$changes" ]; then
  echo "VERDICT: REJECTED"
  echo "CLI: $cli ($model)"
  echo "The second-opinion agent changed the repo; its verdict is void. Left as found:"
  [ "$(git rev-parse HEAD)" != "$head_before" ] && echo "HEAD moved: $head_before -> $(git rev-parse HEAD)"
  printf '%s\n' "$changes"
  exit 1
fi

first="$(grep -m1 -v '^[[:space:]]*$' "$reply" | tr -d '[:space:]' || true)"
if [ "$first" = PASS ]; then verdict=PASS; else verdict=NEEDS_WORK; fi
echo "VERDICT: $verdict"
echo "CLI: $cli ($model)"
cat "$reply"
[ "$verdict" = PASS ]
