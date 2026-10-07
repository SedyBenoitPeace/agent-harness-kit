#!/usr/bin/env bash
# Proves gen-agents.sh output for all three CLIs. Exit 0 = green.
set -euo pipefail
cd "$(dirname "$0")/.."
fail() { echo "AGENTS TEST FAIL: $*" >&2; exit 1; }

t="$(mktemp -d)"; trap 'rm -rf "$t"' EXIT
bash scripts/gen-agents.sh "$t" >/dev/null

for n in harness-builder harness-evaluator harness-brief-reviewer; do
  c="$t/.claude/agents/$n.md"; g="$t/.github/agents/$n.agent.md"; x="$t/.codex/agents/$n.toml"
  for f in "$c" "$g" "$x"; do [ -f "$f" ] || fail "missing $f"; done
  grep -qx "name: $n" "$c" || fail "$n: claude name != file name"
  grep -qx "name: $n" "$g" || fail "$n: copilot name != file name"
  grep -qx "name = \"$n\"" "$x" || fail "$n: codex name != file name"
  grep -q '^description: .' "$g" || fail "$n: copilot description missing"
  grep -q '^description = ".' "$x" || fail "$n: codex description missing"
  grep -q "^developer_instructions = '''" "$x" || fail "$n: codex developer_instructions missing"
  grep -Eq '^model: [^ [{"]+$' "$g" || fail "$n: copilot model must be a plain string"
  grep -Eq '^model: [^ ]+$' "$c" || fail "$n: claude model missing"
done

# read-only agents (evaluator, brief reviewer): no edit/write tool in any format, read-only sandbox for Codex
for ev in harness-evaluator harness-brief-reviewer; do
grep -q '^tools: ' "$t/.claude/agents/$ev.md" || fail "claude evaluator has no tools list"
grep -q '^tools: ' "$t/.github/agents/$ev.agent.md" || fail "copilot evaluator has no tools list"
grep '^tools: ' "$t/.claude/agents/$ev.md" "$t/.github/agents/$ev.agent.md" | grep -Eiq 'edit|write' \
  && fail "evaluator tools list includes edit/write"
grep -q '^disallowedTools: Edit, Write' "$t/.claude/agents/$ev.md" || fail "claude evaluator must disallow Edit, Write"
grep -qx 'sandbox_mode = "read-only"' "$t/.codex/agents/$ev.toml" || fail "codex evaluator not read-only"
done
grep -q 'sandbox_mode' "$t/.codex/agents/harness-builder.toml" && fail "codex builder must not be sandboxed read-only"
grep -q '^tools:' "$t/.claude/agents/harness-builder.md" && fail "builder must keep full tools"

# evaluator prompt contract
# shellcheck disable=SC2016 # literal backticks
grep -qF 'exactly `PASS` or `NEEDS_WORK`' "$t/.claude/agents/harness-evaluator.md" || fail "evaluator verdict contract missing"

# brief reviewer prompt contract: sees only the brief, first line READY or GAPS
# shellcheck disable=SC2016 # literal backticks
grep -qF 'exactly `READY` or `GAPS`' "$t/.claude/agents/harness-brief-reviewer.md" || fail "reviewer verdict contract missing"
grep -qi 'never the conversation' "$t/.claude/agents/harness-brief-reviewer.md" || fail "reviewer must ignore the conversation"

# effort (M24-002): a source effort: becomes effort: for Claude Code and
# model_reasoning_effort for Codex (max maps to high there); Copilot gets
# none; a source without effort gets no effort line anywhere
grep -qx 'effort: high' agents/src/harness-evaluator.md || fail "evaluator source must set effort: high"
grep -qx 'effort: high' "$t/.claude/agents/harness-evaluator.md" || fail "claude evaluator: effort: high missing"
grep -qx 'model_reasoning_effort = "high"' "$t/.codex/agents/harness-evaluator.toml" || fail "codex evaluator: model_reasoning_effort missing"
awk 'NR==1 && /^---$/ {f=1; next} f && /^---$/ {exit} f' "$t/.github/agents/harness-evaluator.agent.md" \
  | grep -q '^effort' && fail "copilot agent must not get an effort field"
grep -q '^effort:' "$t/.claude/agents/harness-builder.md" && fail "builder without source effort must get no effort line"
grep -q 'model_reasoning_effort' "$t/.codex/agents/harness-builder.toml" && fail "codex builder without source effort must get none"
# max -> high mapping for Codex, proved on a copy of the sources
m="$(mktemp -d)"; cp -R agents scripts "$m/"
sed -i.bak 's/^effort: high$/effort: max/' "$m/agents/src/harness-evaluator.md" && rm -f "$m/agents/src/harness-evaluator.md.bak"
mkdir "$m/out"; bash "$m/scripts/gen-agents.sh" "$m/out" >/dev/null
grep -qx 'effort: max' "$m/out/.claude/agents/harness-evaluator.md" || fail "claude: effort: max must pass through"
grep -qx 'model_reasoning_effort = "high"' "$m/out/.codex/agents/harness-evaluator.toml" || fail "codex: max must map to high"
sed -i.bak 's/^effort: max$/effort: turbo/' "$m/agents/src/harness-evaluator.md" && rm -f "$m/agents/src/harness-evaluator.md.bak"
bash "$m/scripts/gen-agents.sh" "$m/out" >/dev/null 2>&1 && fail "unknown effort level must be rejected"
rm -rf "$m"

# model fallback (M27-002): a tier set to "auto" (or missing) lets the CLI
# choose: no model line in that CLI's agent file
a="$(mktemp -d)"; cp -R agents scripts "$a/"
jq '.models.claude.standard = "auto" | del(.models.codex.standard)' "$a/agents/models.json" > "$a/m.json" && mv "$a/m.json" "$a/agents/models.json"
mkdir "$a/out"; bash "$a/scripts/gen-agents.sh" "$a/out" >/dev/null
grep -q '^model:' "$a/out/.claude/agents/harness-builder.md" && fail "auto claude tier must not write a model line"
grep -q '^model = ' "$a/out/.codex/agents/harness-builder.toml" && fail "missing codex tier must not write a model line"
grep -q '^model:' "$a/out/.github/agents/harness-builder.agent.md" || fail "copilot tier still set: model line expected"
rm -rf "$a"

# idempotent
before="$(cd "$t" && find . -type f -exec cksum {} + | sort)"
bash scripts/gen-agents.sh "$t" >/dev/null
[ "$before" = "$(cd "$t" && find . -type f -exec cksum {} + | sort)" ] || fail "second run changed output"

echo "AGENTS TESTS GREEN"
