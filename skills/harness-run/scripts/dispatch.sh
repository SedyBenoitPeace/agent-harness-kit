#!/usr/bin/env bash
# harness-run: which builder agent to dispatch for one feature, and the
# models.log line for it. No model calls. The size comes from the feature's
# `model` (small|medium|large). Absent or another CLI's alias: medium, except
# on claude where the edition's hook decides (plain harness-builder).
# A sized agent file that does not exist falls back to harness-builder.
# Usage: dispatch.sh <target> <cli: claude|codex|copilot> <id> [retries] [--via <provider>[/<model>]]
# --via appends who built it to the dispatch event (M66-004); without it nothing changes.
# Providers (M69-004): when run-start.sh --providers listed 2+ in
# .harness-run/providers, every dispatch prints `VIA: <provider>`, the next
# one round-robin after the provider last used, and logs it; the builder goes
# to that provider. --via may name another listed provider (the next one
# failed to start); a provider not in the list exits 4.
# Prints `AGENT: <name>` and `SIZE: <size>` (codex also `SPAWN: fork_turns=none`:
# Codex spawn_agent forks the orchestrator's whole history when fork_turns is
# omitted, so a builder would start from it, M44-001); appends `<id> <size> model <size>[, +n]`
# to <target>/.harness-run/models.log (not on claude: its hook logs the model).
# Inside a run (.harness-run/start in the main repo) it also appends
# `<epoch> dispatch <id> <cli> <agent> <size>` to .harness-run/events.log (M47-001).
# Each retry steps up one size, capped at large. Exit 2 = usage error.
# Exit 3 = no builder agent file for this CLI (prints `AGENT: missing`): the
# orchestrator generates them with gen-agents.sh and stops for a CLI restart,
# never a built-in subagent told to act as the builder (M39-001).
# Exit 4 = --via names a provider this run did not list (M69-004).
set -euo pipefail
via="" positional_args=()
while [ $# -gt 0 ]; do
  if [ "$1" = --via ]; then
    case "${2:-}" in
      '' | *[[:space:]]*) echo "dispatch: --via needs <provider>[/<model>] without whitespace" >&2; exit 2 ;;
    esac
    via=" $2"
    shift 2
  else
    positional_args+=("$1")
    shift
  fi
done
set -- "${positional_args[@]+"${positional_args[@]}"}"
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
ev() { local root; root="$(cd "$target" 2>/dev/null && cd "$(git rev-parse --git-common-dir 2>/dev/null)/.." 2>/dev/null && pwd)" || return 0
  [ ! -f "$root/.harness-run/start" ] || echo "$(date +%s) $*" >> "$root/.harness-run/events.log"; }
_root="$(cd "$target" 2>/dev/null && cd "$(git rev-parse --git-common-dir 2>/dev/null)/.." 2>/dev/null && pwd)" || _root=""
pf="$_root/.harness-run/providers"
if [ -n "$_root" ] && [ -f "$_root/.harness-run/start" ] && [ "$(grep -c . "$pf" 2>/dev/null || echo 0)" -ge 2 ]; then
  provs=(); while IFS= read -r l; do [ -z "$l" ] || provs+=("$l"); done < "$pf"
  last="$(cat "$_root/.harness-run/provider-last" 2>/dev/null || true)"; nxt="${provs[0]}"
  for i in "${!provs[@]}"; do [ "${provs[$i]}" != "$last" ] || nxt="${provs[$(( (i + 1) % ${#provs[@]} ))]}"; done
  if [ -z "$via" ]; then via=" $nxt"; fi
  use="${via# }"; use="${use%%/*}"
  printf '%s\n' "${provs[@]}" | grep -qxF -- "$use" || { echo "dispatch: provider $use is not in this run's list ($(tr '\n' ' ' < "$pf"| sed 's/ $//')); next is $nxt" >&2; exit 4; }
  echo "$use" > "$_root/.harness-run/provider-last"
  echo "VIA: $use"
fi
# M47-002: refresh the run board last (guarded; never changes output or exit code)
_bt="$(cd "$target" 2>/dev/null && pwd)" || _bt=.; _bs="$(cd "$(dirname "$0")" && pwd)/board.sh"
# shellcheck disable=SC2317,SC2329 # runs from the EXIT trap
board() { local r; r="$(cd "$_bt" && cd "$(git rev-parse --git-common-dir 2>/dev/null)/.." 2>/dev/null && pwd)" || return 0
  [ -s "$r/.harness-run/start" ] || return 0
  [ "$(tail -n1 "$r/.harness-run/events.log" 2>/dev/null | cut -d' ' -f2)" != run-end ] || return 0
  bash "$_bs" "$_bt" >/dev/null 2>&1 || true; }
trap board EXIT
case "$m" in
  small) n=0 ;; medium) n=1 ;; large) n=2 ;;
  *) if [ "$cli" = claude ]; then echo "AGENT: harness-builder"; echo "SIZE: -"; ev dispatch "$id" claude harness-builder "-$via"; exit 0; fi
     m=medium; n=1 ;;
esac
base=$m
n=$((n + retries)); [ "$n" -le 2 ] || n=2
size=$(echo small medium large | cut -d' ' -f$((n + 1)))
agent=harness-builder-$size
[ -f "$(agent_file "$agent")" ] || agent=harness-builder
echo "AGENT: $agent"
echo "SIZE: $size"
ev dispatch "$id" "$cli" "$agent" "$size$via"
[ "$cli" = codex ] && echo "SPAWN: fork_turns=none"
[ "$cli" = claude ] && exit 0
reason="model $base"; [ "$retries" -eq 0 ] || reason="$reason, +$retries"
mkdir -p "$target/.harness-run"
echo "$id $size $reason" >> "$target/.harness-run/models.log"
