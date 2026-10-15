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
set -euo pipefail
target="${1:-}" cli="${2:-}" id="${3:-}" retries="${4:-0}"
[ -n "$id" ] || { echo "usage: dispatch.sh <target> <claude|codex|copilot> <id> [retries]" >&2; exit 2; }
case "$cli" in claude | codex | copilot) ;; *) echo "dispatch: unknown cli $cli" >&2; exit 2 ;; esac
case "$retries" in '' | *[!0-9]*) echo "dispatch: retries must be a number" >&2; exit 2 ;; esac
command -v jq >/dev/null || { echo "ERROR: jq is required" >&2; exit 2; }
m="$(jq -r --arg i "$id" '[.features[] | select(.id == $i)][0].model // ""' "$target/FEATURES.json")"
case "$m" in
  small) n=0 ;; medium) n=1 ;; large) n=2 ;;
  *) if [ "$cli" = claude ]; then echo "AGENT: harness-builder"; echo "SIZE: -"; exit 0; fi
     m=medium; n=1 ;;
esac
base=$m
n=$((n + retries)); [ "$n" -le 2 ] || n=2
size=$(echo small medium large | cut -d' ' -f$((n + 1)))
agent=harness-builder-$size
case "$cli" in
  claude) f=$target/.claude/agents/$agent.md ;;
  copilot) f=$target/.github/agents/$agent.agent.md ;;
  codex) f=$target/.codex/agents/$agent.toml ;;
esac
[ -f "$f" ] || agent=harness-builder
echo "AGENT: $agent"
echo "SIZE: $size"
[ "$cli" = claude ] && exit 0
reason="model $base"; [ "$retries" -eq 0 ] || reason="$reason, +$retries"
mkdir -p "$target/.harness-run"
echo "$id $size $reason" >> "$target/.harness-run/models.log"
