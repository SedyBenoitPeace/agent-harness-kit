#!/usr/bin/env bash
# Fixture tests for skills/harness-audit/scripts/check.sh.
# Builds a harnessed repo from the shipped templates, then breaks it one
# defect at a time and asserts the checker catches each one.
set -euo pipefail
cd "$(dirname "$0")/.."

CHECK="skills/harness-audit/scripts/check.sh"
TMPL="skills/harness-initial-setup/templates"

fail() { echo "AUDIT-TEST FAIL: $*" >&2; exit 1; }

make_fixture() {  # $1 = destination dir
  local d="$1"
  mkdir -p "$d/scripts" "$d/docs/plans/active" "$d/docs/plans/completed" "$d/docs/agents"
  sed 's/{{[A-Za-z0-9_]*}}/X/g'    "$TMPL/AGENTS.md.tmpl"     > "$d/AGENTS.md"
  sed 's/{{[A-Za-z0-9_]*}}/X/g'    "$TMPL/FEATURES.json.tmpl" > "$d/FEATURES.json"
  sed 's/{{[A-Za-z0-9_]*}}/X/g'    "$TMPL/PROGRESS.md.tmpl"   > "$d/PROGRESS.md"
  sed 's/{{[A-Za-z0-9_]*}}/X/g'    "$TMPL/ARCHITECTURE.md.tmpl" > "$d/ARCHITECTURE.md"
  sed 's/{{[A-Za-z0-9_]*}}/true/g' "$TMPL/e2e.sh.tmpl"        > "$d/scripts/e2e.sh"
  chmod +x "$d/scripts/e2e.sh"
  cp "$TMPL"/harness-protocol*.md "$d/docs/agents/"
  cp "$TMPL/pointer.md.tmpl" "$d/CLAUDE.md"
}

expect_fail() {  # $1 = fixture dir, $2 = expected FAIL pattern, $3 = label
  local out
  if out="$(bash "$CHECK" "$1")"; then
    fail "$3: checker exited 0, expected failure"
  fi
  echo "$out" | grep -q "^FAIL.*$2" || fail "$3: missing expected FAIL line ($2)"
  echo "$out" | grep -q "NOT HARNESS READY" || fail "$3: missing NOT HARNESS READY verdict"
}

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# 1. good fixture: exit 0, READY verdict, zero FAIL lines
make_fixture "$WORK/good"
out="$(bash "$CHECK" "$WORK/good")" || fail "good fixture: checker exited non-zero"
echo "$out" | grep -q "HARNESS READY" || fail "good fixture: no HARNESS READY verdict"
if echo "$out" | grep -q "^FAIL"; then fail "good fixture: unexpected FAIL line"; fi

# 2. drifted protocol doc: WARN, still exit 0
make_fixture "$WORK/drift"
echo "local note" >> "$WORK/drift/docs/agents/harness-protocol.md"
out="$(bash "$CHECK" "$WORK/drift")" || fail "drifted protocol must not fail the audit"
echo "$out" | grep -q "^WARN.*differs" || fail "drifted protocol: expected WARN line"
make_fixture "$WORK/drift-runs"
echo "local note" >> "$WORK/drift-runs/docs/agents/harness-protocol-runs.md"
out="$(bash "$CHECK" "$WORK/drift-runs")" || fail "drifted runs part must not fail the audit"
echo "$out" | grep -q "^WARN.*harness-protocol-runs.md differs" || fail "drifted runs part: expected WARN line"

# 2b. missing ARCHITECTURE.md: WARN (repair flow lives in SKILL.md), still exit 0
make_fixture "$WORK/no-arch"
rm "$WORK/no-arch/ARCHITECTURE.md"
out="$(bash "$CHECK" "$WORK/no-arch")" || fail "missing ARCHITECTURE.md must not fail the audit"
echo "$out" | grep -q "^WARN.*ARCHITECTURE.md" || fail "missing ARCHITECTURE.md: expected WARN line"

# 2c. missing logging/observability strategy: WARN (repair flow lives in
# SKILL.md), still exit 0 — strip the mention while keeping ARCHITECTURE.md
make_fixture "$WORK/no-logging"
grep -vi 'logging' "$WORK/no-logging/ARCHITECTURE.md" > "$WORK/no-logging/ARCH.tmp"
mv "$WORK/no-logging/ARCH.tmp" "$WORK/no-logging/ARCHITECTURE.md"
out="$(bash "$CHECK" "$WORK/no-logging")" || fail "missing logging strategy must not fail the audit"
echo "$out" | grep -q "^WARN.*logging/observability" || fail "missing logging strategy: expected WARN line"

# 2d. legacy unbounded gate (no FULL_LOG marker): WARN, still exit 0; the
# template-built good fixture must not get that WARN
make_fixture "$WORK/loud-gate"
printf '#!/usr/bin/env bash\ntrue\n' > "$WORK/loud-gate/scripts/e2e.sh"
out="$(bash "$CHECK" "$WORK/loud-gate")" || fail "unbounded gate must not fail the audit"
echo "$out" | grep -q "^WARN.*not bounded" || fail "unbounded gate: expected WARN line"
out="$(bash "$CHECK" "$WORK/good")" || fail "good fixture re-run exited non-zero"
if echo "$out" | grep -q "^WARN.*not bounded"; then fail "template gate wrongly flagged as unbounded"; fi

# 2e. opted-in evaluator features without agent files: WARN, still exit 0;
# generated agent files clear it
make_fixture "$WORK/opt-in"
jq '.features += [{"id":"M9-001","milestone":9,"title":"t","status":"failing","verify":"v","evaluate":"ui"}]' \
  "$WORK/opt-in/FEATURES.json" > "$WORK/opt-in/F.tmp" && mv "$WORK/opt-in/F.tmp" "$WORK/opt-in/FEATURES.json"
out="$(bash "$CHECK" "$WORK/opt-in")" || fail "missing evaluator agent files must not fail the audit"
echo "$out" | grep -q "^WARN.*harness-evaluator" || fail "opt-in without agent files: expected WARN line"
bash scripts/gen-agents.sh "$WORK/opt-in" >/dev/null
out="$(bash "$CHECK" "$WORK/opt-in")" || fail "opt-in with agent files: exit non-zero"
echo "$out" | grep -q "^WARN.*harness-evaluator" && fail "opt-in with agent files: WARN should clear"

# 2f. effort hint (M23-002): a known level passes silently; an unknown
# value is a WARN (advice, never a FAIL)
make_fixture "$WORK/effort"
jq '.features[0].effort = "high"' "$WORK/effort/FEATURES.json" > "$WORK/effort/F.tmp" && mv "$WORK/effort/F.tmp" "$WORK/effort/FEATURES.json"
out="$(bash "$CHECK" "$WORK/effort")" || fail "valid effort must not fail the audit"
echo "$out" | grep -q "^WARN.*effort" && fail "valid effort: no WARN expected"
jq '.features[0].effort = "turbo"' "$WORK/effort/FEATURES.json" > "$WORK/effort/F.tmp" && mv "$WORK/effort/F.tmp" "$WORK/effort/FEATURES.json"
out="$(bash "$CHECK" "$WORK/effort")" || fail "unknown effort must not fail the audit"
echo "$out" | grep -q "^WARN.*effort.*M0-001" || fail "unknown effort: expected WARN naming the feature"

# 2f2. model size (M33-001): a size or a lowercase alias passes silently;
# anything else is a WARN naming the feature
make_fixture "$WORK/msize"
for v in small medium large haiku gpt-5.1; do
  jq --arg v "$v" '.features[0].model = $v' "$WORK/msize/FEATURES.json" > "$WORK/msize/F.tmp" && mv "$WORK/msize/F.tmp" "$WORK/msize/FEATURES.json"
  out="$(bash "$CHECK" "$WORK/msize")" || fail "valid model $v must not fail the audit"
  echo "$out" | grep -q "^WARN.*model" && fail "valid model $v: no WARN expected"
done
jq '.features[0].model = "Big Model!"' "$WORK/msize/FEATURES.json" > "$WORK/msize/F.tmp" && mv "$WORK/msize/F.tmp" "$WORK/msize/FEATURES.json"
out="$(bash "$CHECK" "$WORK/msize")" || fail "unknown model must not fail the audit"
echo "$out" | grep -q "^WARN.*model.*M0-001" || fail "unknown model: expected WARN naming the feature"

# exclusive (M34-006): a non-empty string passes; anything else is a WARN
make_fixture "$WORK/excl"
jq '.features[0].exclusive = "ios-simulator"' "$WORK/excl/FEATURES.json" > "$WORK/excl/F.tmp" && mv "$WORK/excl/F.tmp" "$WORK/excl/FEATURES.json"
out="$(bash "$CHECK" "$WORK/excl")" || fail "valid exclusive must not fail the audit"
echo "$out" | grep -q "^WARN.*exclusive" && fail "valid exclusive: no WARN expected"
jq '.features[0].exclusive = 3' "$WORK/excl/FEATURES.json" > "$WORK/excl/F.tmp" && mv "$WORK/excl/F.tmp" "$WORK/excl/FEATURES.json"
out="$(bash "$CHECK" "$WORK/excl")" || fail "bad exclusive must not fail the audit"
echo "$out" | grep -q "^WARN.*exclusive.*M0-001" || fail "bad exclusive: expected WARN naming the feature"

# 2g. model-tagged rules (M23-003): none = no WARN; tagged lines = a WARN
# with their count, telling the human to re-test them on model change
out="$(bash "$CHECK" "$WORK/good")" || fail "good fixture re-run exited non-zero"
echo "$out" | grep -q "^WARN.*model-tagged" && fail "untagged AGENTS.md: no WARN expected"
make_fixture "$WORK/tagged"
printf -- '- Always run the linter before the gate (model: example-1)\n- Never mock the clock (model: example-1)\n' >> "$WORK/tagged/AGENTS.md"
out="$(bash "$CHECK" "$WORK/tagged")" || fail "tagged rules must not fail the audit"
echo "$out" | grep -q "^WARN.*2 model-tagged rule" || fail "tagged rules: expected WARN with count 2"
# 2g2. rule expiry (M28-003): dated rules older than 90 days → WARN with
#      their count; recent ones and the combined tag are understood
make_fixture "$WORK/dated"
today="$(date -u +%F)"
printf -- '- Run the linter first (added 2020-01-01)\n- Never mock the clock (added 2021-06-30; model: example-2)\n- Seed the db (added %s)\n' "$today" >> "$WORK/dated/AGENTS.md"
out="$(bash "$CHECK" "$WORK/dated")" || fail "dated rules must not fail the audit"
echo "$out" | grep -q "^WARN.*2 rule(s) added more than 90 days ago" || fail "dated rules: expected WARN for the 2 old rules only"
echo "$out" | grep -q "^WARN.*1 model-tagged rule" || fail "dated rules: (added ...; model: x) must count as model-tagged"
out="$(bash "$CHECK" "$WORK/good")"
echo "$out" | grep -q "added more than 90 days" && fail "no dated rules: no expiry WARN expected"

# 2h. second opinion (M26-001): a CLI not on PATH is a WARN naming it
make_fixture "$WORK/second"
jq '.features[0].second_opinion = "codex"' "$WORK/second/FEATURES.json" > "$WORK/second/F.tmp" && mv "$WORK/second/F.tmp" "$WORK/second/FEATURES.json"
out="$(PATH="/usr/bin:/bin" bash "$CHECK" "$WORK/second")" || fail "second opinion without its CLI must not fail the audit"
if command -v codex >/dev/null 2>&1; then :; else
  echo "$out" | grep -q "^WARN.*second_opinion.*codex" || fail "second opinion: expected WARN naming codex"
fi

# 3. defect fixtures: each must FAIL with its specific line
make_fixture "$WORK/big-agents"
for _ in $(seq 1 101); do echo "filler line" >> "$WORK/big-agents/AGENTS.md"; done
expect_fail "$WORK/big-agents" "AGENTS.md exceeds" "oversized AGENTS.md"

make_fixture "$WORK/empty-verify"
jq '.features[0].verify = ""' "$WORK/empty-verify/FEATURES.json" > "$WORK/empty-verify/F.tmp"
mv "$WORK/empty-verify/F.tmp" "$WORK/empty-verify/FEATURES.json"
expect_fail "$WORK/empty-verify" "id/milestone/verify" "empty verify"

make_fixture "$WORK/no-gate"
rm "$WORK/no-gate/scripts/e2e.sh"
expect_fail "$WORK/no-gate" "scripts/e2e.sh missing" "missing gate"

make_fixture "$WORK/no-plans"
rmdir "$WORK/no-plans/docs/plans/active"
expect_fail "$WORK/no-plans" "docs/plans" "missing plans dir"

make_fixture "$WORK/no-proto"
rm "$WORK/no-proto/docs/agents/harness-protocol.md"
expect_fail "$WORK/no-proto" "harness-protocol.md missing" "missing protocol doc"
make_fixture "$WORK/no-planning"
rm "$WORK/no-planning/docs/agents/harness-protocol-planning.md"
expect_fail "$WORK/no-planning" "harness-protocol-planning.md missing" "missing planning part (repo not upgraded)"

# M30-005: an active plan's task ids must be in FEATURES.json
make_fixture "$WORK/plan-ok"
jq '.features += [{"id": "M1-001", "milestone": 1, "title": "t", "status": "failing", "verify": "x"}]' "$WORK/plan-ok/FEATURES.json" > "$WORK/plan-ok/f.json" && mv "$WORK/plan-ok/f.json" "$WORK/plan-ok/FEATURES.json"
printf '# Plan\n\n## M1-001 — first task\n\nDepends on nothing; see M9-999 in prose.\n' > "$WORK/plan-ok/docs/plans/active/p.md"
out="$(bash "$CHECK" "$WORK/plan-ok")" || fail "plan with its tasks in FEATURES.json: audit should pass ($out)"
make_fixture "$WORK/plan-missing"
printf '# Plan\n\n## M1-002 — not added yet\n' > "$WORK/plan-missing/docs/plans/active/p.md"
expect_fail "$WORK/plan-missing" "names M1-002, which is not in FEATURES.json" "plan task missing from FEATURES.json"

# M34-005: verify must be provable from the repo alone (WARN naming the
# feature); an active plan whose features declare neither depends_on nor
# paths allows no lanes (WARN). Neither fails the audit.
make_fixture "$WORK/prov"
jq '.features += [{"id":"M1-001","milestone":1,"title":"t","status":"failing","verify":"bash scripts/e2e.sh exits 0 with the fixture"},
                  {"id":"M1-002","milestone":1,"title":"t","status":"failing","verify":"a real session on the owner machine shows it","depends_on":[],"paths":["x/"]},
                  {"id":"M1-003","milestone":1,"title":"t","status":"passing","verify":"pushed by a human","depends_on":[],"paths":["x/"]}]' \
  "$WORK/prov/FEATURES.json" > "$WORK/prov/F.tmp" && mv "$WORK/prov/F.tmp" "$WORK/prov/FEATURES.json"
printf '# Plan\n\n## M1-001 — a\n\n## M1-002 — b\n' > "$WORK/prov/docs/plans/active/p.md"
out="$(bash "$CHECK" "$WORK/prov")" || fail "unprovable verify must not fail the audit"
echo "$out" | grep -q "^WARN.*verify.*M1-002" || fail "unprovable verify: expected WARN naming M1-002"
echo "$out" | grep -q "^WARN.*verify.*M1-00[13]" && fail "provable or passing feature wrongly flagged"
echo "$out" | grep -q "^WARN.*p.md.*depends_on" && fail "plan with a feature declaring paths: no lanes WARN expected"
jq '(.features[] | select(.id=="M1-002")) |= del(.depends_on, .paths)' "$WORK/prov/FEATURES.json" > "$WORK/prov/F.tmp" && mv "$WORK/prov/F.tmp" "$WORK/prov/FEATURES.json"
out="$(bash "$CHECK" "$WORK/prov")" || fail "plan without depends_on/paths must not fail the audit"
echo "$out" | grep -q "^WARN.*p.md.*depends_on" || fail "plan without depends_on/paths: expected WARN naming the plan"
# this repo, with M34-005 as passing (its verify quotes the word list and is
# flipped by the orchestrator); the repo itself is not self-harnessed, so
# only the WARN lines matter, not the exit code
mkdir -p "$WORK/self/docs/plans"
cp -R FEATURES.json "$WORK/self/"; cp -R docs/plans/active "$WORK/self/docs/plans/"
jq '(.features[] | select(.id=="M34-005")).status = "passing"' FEATURES.json > "$WORK/self/FEATURES.json"
out="$(bash "$CHECK" "$WORK/self" || true)"
echo "$out" | grep -q "^WARN.*\(verify names\|declare neither\)" && fail "this repo wrongly gets a provability/lanes WARN"
# protocol 1.4 carries the rule and the plan section
grep -q 'Before the run' "$TMPL/harness-protocol-planning.md" || fail "protocol 1.4: Before the run section missing"
grep -q 'provable by a builder from the repo alone' "$TMPL/harness-protocol-planning.md" || fail "protocol 1.4: provable-verify rule missing"

echo "AUDIT TESTS GREEN"
