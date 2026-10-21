#!/usr/bin/env bash
# Usage: gen-agents.sh <target-repo>
# Emits harness-builder / harness-evaluator for Claude Code, Copilot CLI and
# Codex CLI from the neutral sources in agents/src. Idempotent.
# Every Copilot agent sets deferred-tool-loading: true, so it uses tool search
# instead of loading every tool definition on each call (the main agent defers
# by default; a custom agent only with this line).
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
target="${1:?usage: gen-agents.sh <target-repo>}"
[ -d "$target" ] || { echo "gen-agents: no such directory: $target" >&2; exit 1; }
mkdir -p "$target/.claude/agents" "$target/.github/agents" "$target/.codex/agents"

field() { sed -n "2,/^---\$/{s/^$2: *//p;}" "$1"; }
body()  { awk 'c>=2{print} /^---$/{c++}' "$1"; }
# No model line on the base agents: every CLI uses its own default model (M28-001).
# Per-size builders (M33-003): harness-builder-small|medium|large. Claude Code
# always gets them (aliases never go stale); Codex and Copilot only when the
# target's docs/agents/model-sizes.json maps that CLI's three sizes.
map="$target/docs/agents/model-sizes.json"
# size_of <cli> <size>: the mapped model name, empty when absent
size_of() {
  [ -f "$map" ] || return 0
  tr '\n' ' ' < "$map" | sed -n "s/.*\"$1\" *: *{\([^}]*\)}.*/\1/p" \
    | sed -n "s/.*\"$2\" *: *\"\([^\"]*\)\".*/\1/p"
}
sizes="small medium large"
for cli in codex copilot; do
  n=0
  for z in $sizes; do
    v="$(size_of "$cli" "$z")"
    case "$v" in *\\*) echo "gen-agents: $map: $cli.$z has a backslash" >&2; exit 1 ;; esac
    [ -n "$v" ] && n=$((n+1))
  done
  [ "$n" -eq 0 ] || [ "$n" -eq 3 ] || { echo "gen-agents: $map: $cli needs small, medium and large (got $n)" >&2; exit 1; }
  case $cli in codex) has_codex=$n ;; *) has_copilot=$n ;; esac
done

for src in "$here"/agents/src/*.md; do
  name="$(field "$src" name)"; desc="$(field "$src" description)"
  access="$(field "$src" access)"
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
    [ -n "$c_effort" ] && printf '%s\n' "$c_effort"
    printf -- '---\n'
    body "$src"
  } > "$target/.claude/agents/$name.md"

  {
    printf -- '---\nname: %s\ndescription: %s\n' "$name" "$desc"
    [ -n "$g_tools" ] && printf '%s\n' "$g_tools"
    printf 'deferred-tool-loading: true\n'
    printf -- '---\n'
    body "$src"
  } > "$target/.github/agents/$name.agent.md"

  {
    printf 'name = "%s"\ndescription = "%s"\n' "$name" "$desc"
    printf '%s' "$x_sandbox"
    [ -n "$x_effort" ] && printf '%s\n' "$x_effort"
    printf "developer_instructions = '''\n"
    body "$src"
    printf "'''\n"
  } > "$target/.codex/agents/$name.toml"

  if [ "$name" = harness-builder ]; then
    for z in $sizes; do
      case $z in small) a=haiku ;; medium) a=sonnet ;; large) a=opus ;; esac
      {
        printf -- '---\nname: %s-%s\ndescription: %s\nmodel: %s\n---\n' "$name" "$z" "$desc" "$a"
        body "$src"
      } > "$target/.claude/agents/$name-$z.md"
      if [ "$has_copilot" -eq 3 ]; then
        {
          printf -- '---\nname: %s-%s\ndescription: %s\nmodel: %s\ndeferred-tool-loading: true\n---\n' "$name" "$z" "$desc" "$(size_of copilot "$z")"
          body "$src"
        } > "$target/.github/agents/$name-$z.agent.md"
      else rm -f "$target/.github/agents/$name-$z.agent.md"; fi
      if [ "$has_codex" -eq 3 ]; then
        {
          # Codex: a file value wins over spawn and a model-only file keeps the
          # parent's effort, so pin it; medium for every size (size != effort)
          printf 'name = "%s-%s"\ndescription = "%s"\nmodel = "%s"\nmodel_reasoning_effort = "medium"\n' "$name" "$z" "$desc" "$(size_of codex "$z")"
          printf "developer_instructions = '''\n"
          body "$src"
          printf "'''\n"
        } > "$target/.codex/agents/$name-$z.toml"
      else rm -f "$target/.codex/agents/$name-$z.toml"; fi
    done
  fi
done
echo "gen-agents: wrote agents to $target"
