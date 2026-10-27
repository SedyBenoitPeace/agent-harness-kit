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
  # no model names (M28-001): every CLI uses its own default
  grep -Eq '^model *[:=]' "$c" "$g" "$x" && fail "$n: generated agent must not name a model"
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

# per-size builders (M33-003)
# no map: Claude trio from aliases, none for Codex/Copilot, base builder unchanged
for z in small:haiku medium:sonnet large:opus; do
  f="$t/.claude/agents/harness-builder-${z%%:*}.md"
  [ -f "$f" ] || fail "claude: missing harness-builder-${z%%:*}"
  grep -qx "name: harness-builder-${z%%:*}" "$f" || fail "claude sized builder name wrong"
  grep -qx "model: ${z##*:}" "$f" || fail "claude ${z%%:*} must be model: ${z##*:}"
  grep -q '^effort:' "$f" && fail "claude sized builder must have no effort line (the per-feature effort stays in charge)"
  grep -q '^tools:' "$f" && fail "sized builder must keep full tools"
done
ls "$t"/.github/agents/harness-builder-* "$t"/.codex/agents/harness-builder-* >/dev/null 2>&1 \
  && fail "no size map: Codex/Copilot must get no sized builders"
ls "$t"/.claude/agents/harness-evaluator-* >/dev/null 2>&1 && fail "only the builder gets sizes"
# with a map: Codex and Copilot get the mapped model lines
s2="$(mktemp -d)"; mkdir -p "$s2/docs/agents"
cp scripts/fixtures/model-sizes/model-sizes.json "$s2/docs/agents/"
bash scripts/gen-agents.sh "$s2" >/dev/null
for z in small:S medium:M large:L; do
  zz="${z%%:*}"; k="${z##*:}"; kl="$(echo "$k" | tr '[:upper:]' '[:lower:]')"
  x="$s2/.codex/agents/harness-builder-$zz.toml"; g="$s2/.github/agents/harness-builder-$zz.agent.md"
  grep -qx "model = \"fixture-codex-$kl\"" "$x" || fail "codex $zz model line"
  grep -qx "name = \"harness-builder-$zz\"" "$x" || fail "codex $zz name"
  grep -q "^developer_instructions = '''" "$x" || fail "codex $zz instructions"
  grep -qx "model: Fixture Copilot $k" "$g" || fail "copilot $zz model line"
  grep -qx "name: harness-builder-$zz" "$g" || fail "copilot $zz name"
  # Codex: the file value wins over spawn, so each sized file pins its effort
  [ "$(grep -c '^model_reasoning_effort' "$x")" -eq 1 ] || fail "codex $zz needs one effort line"
  grep -qx 'model_reasoning_effort = "medium"' "$x" || fail "codex $zz effort must be medium"
  grep -Eq '^(effort|model_reasoning_effort)' "$g" && fail "copilot has no per-agent effort"
done
grep -q '^model' "$s2/.codex/agents/harness-builder.toml" "$s2/.github/agents/harness-builder.agent.md" "$s2/.claude/agents/harness-builder.md" && fail "base harness-builder must have no model line"
cmp -s "$t/.codex/agents/harness-builder.toml" "$s2/.codex/agents/harness-builder.toml" || fail "base codex builder must be unchanged by a map"
cmp -s "$t/.github/agents/harness-builder.agent.md" "$s2/.github/agents/harness-builder.agent.md" || fail "base copilot builder must be unchanged by a map"
# removing the map removes the stale sized files
rm "$s2/docs/agents/model-sizes.json"; bash scripts/gen-agents.sh "$s2" >/dev/null
ls "$s2"/.github/agents/harness-builder-* "$s2"/.codex/agents/harness-builder-* >/dev/null 2>&1 && fail "stale sized builders left"
# a partial map is rejected
cp scripts/fixtures/model-sizes/partial.json "$s2/docs/agents/model-sizes.json"
bash scripts/gen-agents.sh "$s2" >/dev/null 2>&1 && fail "partial size map must be rejected"
rm -rf "$s2"

# deferred tool loading: every generated Copilot agent (all access levels,
# base and sized) uses Copilot CLI tool search; Claude and Codex get no such line
s3="$(mktemp -d)"; mkdir -p "$s3/docs/agents"
cp scripts/fixtures/model-sizes/model-sizes.json "$s3/docs/agents/"
bash scripts/gen-agents.sh "$s3" >/dev/null
n=0
for g in "$t"/.github/agents/*.agent.md "$s3"/.github/agents/*.agent.md; do
  awk 'NR==1 && /^---$/ {f=1; next} f && /^---$/ {exit} f' "$g" \
    | grep -qx 'deferred-tool-loading: true' || fail "$g: copilot agent needs deferred-tool-loading: true in its frontmatter"
  n=$((n+1))
done
[ "$n" -ge 6 ] || fail "deferred-tool-loading check saw only $n copilot agents"
grep -rq 'deferred-tool-loading' "$t/.claude" "$t/.codex" "$s3/.claude" "$s3/.codex" \
  && fail "deferred-tool-loading is Copilot-only"
rm -rf "$s3"

# idempotent
before="$(cd "$t" && find . -type f -exec cksum {} + | sort)"
bash scripts/gen-agents.sh "$t" >/dev/null
[ "$before" = "$(cd "$t" && find . -type f -exec cksum {} + | sort)" ] || fail "second run changed output"

# lean reads (M38): every CLI's builder starts briefed sessions from
# context.sh --brief and carries the read rule
for f in "$t/.claude/agents/harness-builder.md" "$t/.github/agents/harness-builder.agent.md" "$t/.codex/agents/harness-builder.toml" \
         "$t/.claude/agents/harness-builder-medium.md"; do
  grep -qF 'context.sh --brief' "$f" || fail "$f: briefed builder must start from context.sh --brief"
  grep -qF 'do not cat SKILL.md, AGENTS.md' "$f" || fail "$f: briefed builder must not cat SKILL.md/AGENTS.md"
  grep -qF 'grep -n first, then sed -n ≤80 lines; never cat a source file over 200 lines' "$f" || fail "$f: read rule missing"
done

echo "AGENTS TESTS GREEN"
