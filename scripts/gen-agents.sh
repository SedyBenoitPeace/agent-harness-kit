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
model() { jq -r --arg c "$1" --arg t "$2" '.models[$c][$t]' "$here/agents/models.json"; }

for src in "$here"/agents/src/*.md; do
  name="$(field "$src" name)"; desc="$(field "$src" description)"
  tier="$(field "$src" tier)"; access="$(field "$src" access)"
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
    printf 'model: %s\n---\n' "$(model claude "$tier")"
    body "$src"
  } > "$target/.claude/agents/$name.md"

  {
    printf -- '---\nname: %s\ndescription: %s\n' "$name" "$desc"
    [ -n "$g_tools" ] && printf '%s\n' "$g_tools"
    printf 'model: %s\n---\n' "$(model copilot "$tier")"
    body "$src"
  } > "$target/.github/agents/$name.agent.md"

  {
    printf 'name = "%s"\ndescription = "%s"\nmodel = "%s"\n%s' \
      "$name" "$desc" "$(model codex "$tier")" "$x_sandbox"
    printf "developer_instructions = '''\n"
    body "$src"
    printf "'''\n"
  } > "$target/.codex/agents/$name.toml"
done
echo "gen-agents: wrote agents to $target"
