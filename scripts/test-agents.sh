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

# idempotent
before="$(cd "$t" && find . -type f -exec cksum {} + | sort)"
bash scripts/gen-agents.sh "$t" >/dev/null
[ "$before" = "$(cd "$t" && find . -type f -exec cksum {} + | sort)" ] || fail "second run changed output"

echo "AGENTS TESTS GREEN"
