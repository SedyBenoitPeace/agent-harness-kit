#!/usr/bin/env bash
# Gate for the harness-planning-skill repo. Exit 0 = green.
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

# --- templates ------------------------------------------------------------

TMPL_DIR="skill/harness-planning/templates"

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

grep -q '^## 2\. Coding-session protocol' "$PROTO" || fail "protocol: coding-session section missing"
grep -q 'git log -20' "$PROTO" || fail "protocol: session loop must start from git log -20"
grep -q 'ONE feature' "$PROTO" || fail "protocol: one-feature-per-session rule missing"

grep -q '^## 3\. Maintenance protocol' "$PROTO" || fail "protocol: maintenance section missing"
grep -qi 'entropy' "$PROTO" || fail "protocol: maintenance section must cover entropy GC"

# SKILL.md: valid frontmatter, references only templates that exist
SKILL="skill/harness-planning/SKILL.md"
[ -f "$SKILL" ] || fail "SKILL.md missing"
[ "$(head -1 "$SKILL")" = "---" ] || fail "SKILL.md: missing frontmatter"
grep -q '^name: harness-planning$' "$SKILL" || fail "SKILL.md: frontmatter name wrong"
grep -q '^description: ' "$SKILL" || fail "SKILL.md: frontmatter description missing"
while read -r ref; do
  [ -f "skill/harness-planning/$ref" ] || fail "SKILL.md references missing file: $ref"
done < <(grep -oE 'templates/[A-Za-z0-9._-]+' "$SKILL" | sort -u)

# README: both quickstarts present
grep -q '\.claude/skills' README.md || fail "README: Claude install quickstart missing"
grep -q 'harness-protocol.md' README.md || fail "README: non-Claude quickstart missing"

echo "GATE GREEN"
