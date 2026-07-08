#!/usr/bin/env bash
# Gate for the agent-harness-kit repo. Exit 0 = green.
# Run at the start (baseline) and end (proof) of every session.
set -euo pipefail
cd "$(dirname "$0")/.."

fail() { echo "GATE FAIL: $*" >&2; exit 1; }

command -v jq >/dev/null || fail "jq is required (brew install jq)"
command -v shellcheck >/dev/null || fail "shellcheck is required (brew install shellcheck)"

# --- repo harness ---------------------------------------------------------

# FEATURES.json: valid JSON with the required top-level shape
jq -e '(.milestones | type == "object") and (.features | type == "array")' \
  FEATURES.json >/dev/null 2>&1 \
  || fail "FEATURES.json: invalid JSON or missing milestones/features"

# every feature entry is complete and uses a legal status
jq -e '[ .features[]
         | select( ((.id? // "") == "") or ((.title? // "") == "")
                   or ((.verify? // "") == "")
                   or ((.status? // "") | IN("failing","passing","deferred","superseded") | not) )
       ] | length == 0' FEATURES.json >/dev/null \
  || fail "FEATURES.json: entry missing id/title/verify or has illegal status"

# AGENTS.md stays a table of contents
[ "$(wc -l < AGENTS.md)" -le 100 ] || fail "AGENTS.md exceeds 100 lines"

# no personal/local paths leaked into tracked files
if git grep -nIE '/Users/[a-z]|/home/[a-z]' -- ':!scripts/e2e.sh' >/dev/null 2>&1; then
  fail "personal path leaked into a tracked file"
fi

# this repo's scripts are clean shell
shellcheck scripts/*.sh

# --- open-source hygiene --------------------------------------------------

grep -q "MIT License" LICENSE 2>/dev/null || fail "LICENSE missing or not MIT"
[ -f .gitignore ] || fail ".gitignore missing"
[ -f README.md ] || fail "README.md missing"

# --- plugin packaging -------------------------------------------------------

jq -e '.name == "agent-harness-kit" and (.version | type == "string")' \
  .claude-plugin/plugin.json >/dev/null 2>&1 \
  || fail "plugin.json missing, invalid, or wrong name"
jq -e '.plugins[0].name == "agent-harness-kit" and .plugins[0].source == "./"' \
  .claude-plugin/marketplace.json >/dev/null 2>&1 \
  || fail "marketplace.json missing, invalid, or wrong plugin entry"

# --- templates ------------------------------------------------------------

TMPL_DIR="skills/harness-setup/templates"

# FEATURES.json.tmpl: contains placeholders, valid JSON once they are substituted
grep -q '{{' "$TMPL_DIR/FEATURES.json.tmpl" \
  || fail "FEATURES.json.tmpl has no {{placeholders}}"
sed 's/{{[A-Za-z0-9_]*}}/X/g' "$TMPL_DIR/FEATURES.json.tmpl" | jq -e . >/dev/null \
  || fail "FEATURES.json.tmpl: not valid JSON after placeholder substitution"

[ -f "$TMPL_DIR/PROGRESS.md.tmpl" ] || fail "PROGRESS.md.tmpl missing"
grep -q '{{' "$TMPL_DIR/PROGRESS.md.tmpl" || fail "PROGRESS.md.tmpl has no {{placeholders}}"

# AGENTS.md.tmpl: map-not-encyclopedia, with adaptation headroom
[ -f "$TMPL_DIR/AGENTS.md.tmpl" ] || fail "AGENTS.md.tmpl missing"
[ "$(wc -l < "$TMPL_DIR/AGENTS.md.tmpl")" -le 80 ] || fail "AGENTS.md.tmpl exceeds 80 lines"
grep -q 'docs/agents/harness-protocol.md' "$TMPL_DIR/AGENTS.md.tmpl" \
  || fail "AGENTS.md.tmpl does not point at the protocol doc"

# pointer.md.tmpl: a pointer, nothing more
[ -f "$TMPL_DIR/pointer.md.tmpl" ] || fail "pointer.md.tmpl missing"
[ "$(wc -l < "$TMPL_DIR/pointer.md.tmpl")" -le 5 ] || fail "pointer.md.tmpl must stay a one-line pointer"

# script templates: must be clean shell once placeholders are substituted
found_sh_tmpl=0
for t in "$TMPL_DIR"/*.sh.tmpl; do
  [ -e "$t" ] || continue
  found_sh_tmpl=1
  sub="$(mktemp)"
  sed 's/{{[A-Za-z0-9_]*}}/true/g' "$t" > "$sub"
  shellcheck -s bash "$sub" || fail "$(basename "$t") fails shellcheck after substitution"
  rm -f "$sub"
done
[ "$found_sh_tmpl" -eq 1 ] || fail "no *.sh.tmpl templates found"

# protocol doc: exists, has the planning section, no Claude-isms
PROTO="$TMPL_DIR/harness-protocol.md"
[ -f "$PROTO" ] || fail "harness-protocol.md missing"
grep -q '^## 1\. Planning protocol' "$PROTO" || fail "protocol: '## 1. Planning protocol' missing"
grep -q 'PRODUCT\.md' "$PROTO" || fail "protocol: planning section never mentions PRODUCT.md"
grep -qi 'verify' "$PROTO" || fail "protocol: planning section never teaches the verify field"
! grep -qi 'claude' "$PROTO" || fail "protocol doc must be agent-neutral (found 'claude')"
grep -q 'Already have requirements' "$PROTO" || fail "protocol: PRD-input rule missing from section 1.1"
grep -q 'Choose the verification tooling' "$PROTO" || fail "protocol: verification tooling section (1.7) missing"

grep -q '^## 2\. Coding-session protocol' "$PROTO" || fail "protocol: coding-session section missing"
grep -q 'git log -20' "$PROTO" || fail "protocol: session loop must start from git log -20"
grep -q 'ONE feature' "$PROTO" || fail "protocol: one-feature-per-session rule missing"

grep -q '^## 3\. Maintenance protocol' "$PROTO" || fail "protocol: maintenance section missing"
grep -qi 'entropy' "$PROTO" || fail "protocol: maintenance section must cover entropy GC"

# SKILL.md: valid frontmatter, references only templates that exist
SKILL="skills/harness-setup/SKILL.md"
[ -f "$SKILL" ] || fail "SKILL.md missing"
[ "$(head -1 "$SKILL")" = "---" ] || fail "SKILL.md: missing frontmatter"
grep -q '^name: harness-setup$' "$SKILL" || fail "SKILL.md: frontmatter name wrong"
grep -q '^description: ' "$SKILL" || fail "SKILL.md: frontmatter description missing"
grep -q 'Already harnessed' "$SKILL" || fail "SKILL.md: already-initialized guard missing"
while read -r ref; do
  [ -f "skills/harness-setup/$ref" ] || fail "SKILL.md references missing file: $ref"
done < <(grep -oE 'templates/[A-Za-z0-9._-]+' "$SKILL" | sort -u)

# README: all three quickstarts present
grep -q '/plugin marketplace add' README.md || fail "README: plugin install quickstart missing"
grep -q '\.claude/skills' README.md || fail "README: manual copy fallback missing"
grep -q 'harness-protocol.md' README.md || fail "README: non-Claude quickstart missing"
grep -q 'PRD' README.md || fail "README: PRD-input section missing"
grep -q 'Using the skills' README.md || fail "README: using-the-skills prompts section missing"

# --- harness-audit skill ----------------------------------------------------

AUDIT="skills/harness-audit"
[ -f "$AUDIT/scripts/check.sh" ] || fail "harness-audit check.sh missing"
shellcheck "$AUDIT/scripts/check.sh"
[ -f "$AUDIT/SKILL.md" ] || fail "harness-audit SKILL.md missing"
[ "$(head -1 "$AUDIT/SKILL.md")" = "---" ] || fail "harness-audit SKILL.md: missing frontmatter"
grep -q '^name: harness-audit$' "$AUDIT/SKILL.md" || fail "harness-audit SKILL.md: frontmatter name wrong"
grep -q '^description: ' "$AUDIT/SKILL.md" || fail "harness-audit SKILL.md: description missing"
bash scripts/test-audit.sh

# --- harness-status skill -----------------------------------------------------

STATUS_SKILL="skills/harness-status"
[ -f "$STATUS_SKILL/scripts/status.sh" ] || fail "harness-status status.sh missing"
shellcheck "$STATUS_SKILL/scripts/status.sh"
[ -f "$STATUS_SKILL/SKILL.md" ] || fail "harness-status SKILL.md missing"
[ "$(head -1 "$STATUS_SKILL/SKILL.md")" = "---" ] || fail "harness-status SKILL.md: missing frontmatter"
grep -q '^name: harness-status$' "$STATUS_SKILL/SKILL.md" || fail "harness-status SKILL.md: frontmatter name wrong"
grep -q '^description: ' "$STATUS_SKILL/SKILL.md" || fail "harness-status SKILL.md: description missing"
bash scripts/test-status.sh

echo "GATE GREEN"
