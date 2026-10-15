#!/usr/bin/env bash
# usage-copilot.sh <start-commit>: append this run's Copilot CLI token usage to
# .harness-run/usage.log, one line per scope and model:
#   <scope> copilot <model> <input> <cached> <output> [premium=<n>]
# Reads ~/.copilot/session-state/*/events.jsonl (COPILOT_HOME overrides ~/.copilot)
# for sessions whose workspace.yaml cwd/git_root is this repo (HARNESS_USAGE_REPO
# overrides the git top level). Counts only usage_records stamped after the
# start commit. A subagent whose assistant.message has a `SESSION: <id> ·` line
# is scope <id>; every other record (main thread, other subagents) is
# `orchestration`. input includes cache reads/writes; cached = cacheReadTokens;
# premium = summed usage.cost. Needs jq.
set -euo pipefail
START="${1:-}"
[ -n "$START" ] || { echo "usage: usage-copilot.sh <start-commit>" >&2; exit 2; }
command -v jq >/dev/null || { echo "usage-copilot.sh: jq is required" >&2; exit 2; }
REPO="${HARNESS_USAGE_REPO:-$(git rev-parse --show-toplevel)}"
# Commit time as UTC ISO text, comparable with Copilot's timestamps.
SINCE="$(TZ=UTC git log -1 --date=format-local:%Y-%m-%dT%H:%M:%S --format=%cd "$START")"
[ -n "$SINCE" ] || { echo "usage-copilot.sh: unknown commit $START" >&2; exit 2; }

files=()
for d in "${COPILOT_HOME:-$HOME/.copilot}"/session-state/*/; do
  [ -f "$d/events.jsonl" ] && [ -f "$d/workspace.yaml" ] || continue
  grep -Eq "^(cwd|git_root): ${REPO}\$" "$d/workspace.yaml" && files+=("$d/events.jsonl")
done
[ ${#files[@]} -gt 0 ] || exit 0

mkdir -p .harness-run
jq -rs --arg since "$SINCE" '
  (map(select(.type == "assistant.message" and .agentId != null)
       | {key: .agentId, value: (.data.content | capture("SESSION: (?<id>[^ ]+) ·").id? // empty)})
   | from_entries) as $feat
  | map(select(.type == "session.usage_record" and .timestamp[0:19] >= $since))
  | map({scope: (if .agentId then ($feat[.agentId] // "orchestration") else "orchestration" end),
         model: (.data.usage.model // "-"), u: .data.usage})
  | group_by([.scope, .model])[]
  | "\(.[0].scope) copilot \(.[0].model) \(map(.u.inputTokens) | add) \(map(.u.cacheReadTokens) | add) \(map(.u.outputTokens) | add)"
    + ((map(.u.cost // 0) | add) as $p | if $p > 0 then " premium=\($p | if . == floor then floor else . end)" else "" end)
' "${files[@]}" >> .harness-run/usage.log
