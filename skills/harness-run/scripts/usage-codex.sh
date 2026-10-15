#!/usr/bin/env bash
# harness-run: token usage of a Codex run, from Codex's own session files (M32-003).
# Usage: usage-codex.sh <start-commit>   (run in the repo root)
# Reads ${CODEX_HOME:-~/.codex}/sessions/**/rollout-*.jsonl (.jsonl.zst too when
# zstd exists) whose first session_meta names this repo in
# runtime_workspace_roots and starts at or after the start commit. A thread's
# tokens are its last token_count total_token_usage; its model is its first
# turn_context model. A harness-builder thread whose task_complete carries a
# `SESSION: <id> · ...` line is that feature's; every other thread (the
# orchestrator, guardian_review, a builder that never reported) is
# `orchestration`. Appends one line per (scope, model) to .harness-run/usage.log:
#   <scope> codex <model> <input> <cached> <output>
# Exit codes: 0 done (also when nothing was found); 2 usage error / not a repo.
set -euo pipefail

start="${1:-}"
[ -n "$start" ] || { echo "usage: usage-codex.sh <start-commit>" >&2; exit 2; }
command -v jq >/dev/null || { echo "ERROR: jq is required" >&2; exit 2; }
repo="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "ERROR: not a git repo" >&2; exit 2; }
repo="$(cd "$repo" && pwd -P)"
since="$(TZ=UTC git show -s --format=%cd --date=format-local:%Y-%m-%dT%H:%M:%S "$start" 2>/dev/null)" \
  || { echo "ERROR: unknown commit $start" >&2; exit 2; }
dir="${CODEX_HOME:-$HOME/.codex}/sessions"
[ -d "$dir" ] || exit 0

# Print a session file as plain JSONL (nothing for .zst without zstd).
emit() {
  case "$1" in
    *.zst) if command -v zstd >/dev/null; then zstd -dc "$1" 2>/dev/null; fi ;;
    *) cat "$1" ;;
  esac
}

# One TSV row per thread: scope model input cached output
rows="$(
  find "$dir" -type f \( -name 'rollout-*.jsonl' -o -name 'rollout-*.jsonl.zst' \) | sort | while IFS= read -r f; do
    emit "$f" | jq -nr --arg repo "$repo" --arg since "$since" '
      reduce (inputs | select(type == "object")) as $l ({};
        if $l.type == "session_meta" then (if .meta == null then .meta = $l.payload else . end)
        elif $l.type == "turn_context" then (if .model == null then .model = $l.payload.model else . end)
        elif ($l.payload | type) != "object" then .
        elif $l.payload.type == "token_count" and ($l.payload.info | type) == "object" then .u = $l.payload.info.total_token_usage
        elif $l.payload.type == "task_complete" then .msg = $l.payload.last_agent_message
        else . end)
      | select(.meta != null and .u != null)
      | select((.meta.runtime_workspace_roots // []) | index($repo))
      | select((.meta.timestamp // "")[0:19] >= $since)
      | (if .meta.agent_role == "harness-builder"
         then ((.msg // "") | capture("SESSION: (?<id>[^ ]+) ").id // "orchestration")
         else "orchestration" end) as $scope
      | [$scope, (.model // "-"), .u.input_tokens, .u.cached_input_tokens, .u.output_tokens] | @tsv'
  done
)"
[ -n "$rows" ] || exit 0

mkdir -p .harness-run
printf '%s\n' "$rows" | awk -F'\t' '
  { k = $1 "\t" $2; i[k] += $3; c[k] += $4; o[k] += $5 }
  END { for (k in i) { split(k, p, "\t"); printf "%s codex %s %d %d %d\n", p[1], p[2], i[k], c[k], o[k] } }' \
  | LC_ALL=C sort >> .harness-run/usage.log
