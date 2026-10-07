#!/usr/bin/env bash
# Usage: gen-agents.sh <target-repo>
# Emits harness-builder / harness-evaluator for Claude Code, Copilot CLI and
# Codex CLI from the neutral sources in agents/src. Idempotent.
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
target="${1:?usage: gen-agents.sh <target-repo>}"
[ -d "$target" ] || { echo "gen-agents: no such directory: $target" >&2; exit 1; }
mkdir -p "$target/.claude/agents" "$target/.github/agents" "$target/.codex/agents"

field() { sed -n "2,/^---\$/{s/^$2: *//p;}" "$1"; }
body()  { awk 'c>=2{print} /^---$/{c++}' "$1"; }
# A tier set to "auto" (or missing) lets the CLI choose its own model.
model() { jq -r --arg c "$1" --arg t "$2" '.models[$c][$t] // "auto"' "$here/agents/models.json"; }

for src in "$here"/agents/src/*.md; do
  name="$(field "$src" name)"; desc="$(field "$src" description)"
  tier="$(field "$src" tier)"; access="$(field "$src" access)"
  # optional effort (low|medium|high|max): Claude Code takes it as-is; Codex
  # calls it model_reasoning_effort and has no max (mapped to high); Copilot
  # has no per-agent setting, so it gets none
  effort="$(field "$src" effort)"
  case "$effort" in
    "") c_effort=""; x_effort="" ;;
    low|medium|high) c_effort="effort: $effort"; x_effort="model_reasoning_effort = \"$effort\"" ;;
    max) c_effort="effort: max"; x_effort='model_reasoning_effort = "high"' ;;
    *) echo "gen-agents: $src effort must be low|medium|high|max, got: $effort" >&2; exit 1 ;;
  esac
  [ "$name" = "$(basename "$src" .md)" ] || { echo "gen-agents: $src name != file name" >&2; exit 1; }
  # Codex body is a TOML literal string: it cannot contain '''
  body "$src" | grep -q "'''" && { echo "gen-agents: $src contains '''" >&2; exit 1; }

  if [ "$access" = read-only ]; then
    c_tools=$'tools: Read, Grep, Glob, Bash\ndisallowedTools: Edit, Write'
    g_tools='tools: ["read", "search", "execute"]'
    x_sandbox=$'sandbox_mode = "read-only"\n'
  else
    c_tools=""; g_tools=""; x_sandbox=""
  fi

  {
    printf -- '---\nname: %s\ndescription: %s\n' "$name" "$desc"
    [ -n "$c_tools" ] && printf '%s\n' "$c_tools"
    m="$(model claude "$tier")"; [ "$m" = auto ] || printf 'model: %s\n' "$m"
    [ -n "$c_effort" ] && printf '%s\n' "$c_effort"
    printf -- '---\n'
    body "$src"
  } > "$target/.claude/agents/$name.md"

  {
    printf -- '---\nname: %s\ndescription: %s\n' "$name" "$desc"
    [ -n "$g_tools" ] && printf '%s\n' "$g_tools"
    m="$(model copilot "$tier")"; [ "$m" = auto ] || printf 'model: %s\n' "$m"
    printf -- '---\n'
    body "$src"
  } > "$target/.github/agents/$name.agent.md"

  {
    printf 'name = "%s"\ndescription = "%s"\n' "$name" "$desc"
    m="$(model codex "$tier")"; [ "$m" = auto ] || printf 'model = "%s"\n' "$m"
    printf '%s' "$x_sandbox"
    [ -n "$x_effort" ] && printf '%s\n' "$x_effort"
    printf "developer_instructions = '''\n"
    body "$src"
    printf "'''\n"
  } > "$target/.codex/agents/$name.toml"
done
echo "gen-agents: wrote agents to $target"
