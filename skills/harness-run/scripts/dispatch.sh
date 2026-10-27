#!/usr/bin/env bash
# harness-run: which builder agent to dispatch for one feature, and the
# models.log line for it. No model calls. The size comes from the feature's
# `model` (small|medium|large). Absent or another CLI's alias: medium, except
# on claude where the edition's hook decides (plain harness-builder).
# A sized agent file that does not exist falls back to harness-builder.
# Usage: dispatch.sh <target> <cli: claude|codex|copilot> <id> [retries]
# Prints `AGENT: <name>` and `SIZE: <size>`; appends `<id> <size> model <size>[, +n]`
# to <target>/.harness-run/models.log (not on claude: its hook logs the model).
# Each retry steps up one size, capped at large. Exit 2 = usage error.
# Exit 3 = no builder agent file for this CLI (prints `AGENT: missing`): the
# orchestrator generates them with gen-agents.sh and stops for a CLI restart,
# never a built-in subagent told to act as the builder (M39-001).
set -euo pipefail
target="${1:-}" cli="${2:-}" id="${3:-}" retries="${4:-0}"
[ -n "$id" ] || { echo "usage: dispatch.sh <target> <claude|codex|copilot> <id> [retries]" >&2; exit 2; }
case "$cli" in claude | codex | copilot) ;; *) echo "dispatch: unknown cli $cli" >&2; exit 2 ;; esac
case "$retries" in '' | *[!0-9]*) echo "dispatch: retries must be a number" >&2; exit 2 ;; esac
command -v jq >/dev/null || { echo "ERROR: jq is required" >&2; exit 2; }
m="$(jq -r --arg i "$id" '[.features[] | select(.id == $i)][0].model // ""' "$target/FEATURES.json")"
# agent_file <name>: where this CLI reads that agent from
agent_file() {
  case "$cli" in
    claude) echo "$target/.claude/agents/$1.md" ;;
    copilot) echo "$target/.github/agents/$1.agent.md" ;;
    codex) echo "$target/.codex/agents/$1.toml" ;;
  esac
}
[ -f "$(agent_file harness-builder)" ] || {
  echo "AGENT: missing"
  echo "dispatch: no $(agent_file harness-builder): run gen-agents.sh $target, commit the agent files, restart the CLI" >&2
  exit 3
}
case "$m" in
  small) n=0 ;; medium) n=1 ;; large) n=2 ;;
  *) if [ "$cli" = claude ]; then echo "AGENT: harness-builder"; echo "SIZE: -"; exit 0; fi
     m=medium; n=1 ;;
esac
base=$m
n=$((n + retries)); [ "$n" -le 2 ] || n=2
size=$(echo small medium large | cut -d' ' -f$((n + 1)))
agent=harness-builder-$size
[ -f "$(agent_file "$agent")" ] || agent=harness-builder
echo "AGENT: $agent"
echo "SIZE: $size"
[ "$cli" = claude ] && exit 0
reason="model $base"; [ "$retries" -eq 0 ] || reason="$reason, +$retries"
mkdir -p "$target/.harness-run"
echo "$id $size $reason" >> "$target/.harness-run/models.log"
