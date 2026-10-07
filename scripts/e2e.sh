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
                   or ((.status? // "") | IN("failing","passing","deferred","superseded","review") | not) )
       ] | length == 0' FEATURES.json >/dev/null \
  || fail "FEATURES.json: entry missing id/title/verify or has illegal status"

# optional parallel-lane fields (harness-run), when present, are string arrays
# (key presence, not value: an explicit null is rejected, not skipped)
jq -e '[ .features[] | to_entries[] | select(.key == "depends_on" or .key == "paths")
         | .value | select(type != "array" or any(.[]; type != "string")) ] | length == 0' \
  FEATURES.json >/dev/null \
  || fail "FEATURES.json: depends_on/paths must be arrays of strings"

# optional evaluator fields (M18), when present: evaluate ui|none, bar string, eval_attempts integer
jq -e '[ .features[]
         | select( (has("evaluate") and (.evaluate | IN("ui","none") | not))
                   or (has("bar") and (.bar | type != "string"))
                   or (has("eval_attempts") and (.eval_attempts | type != "number" or . != floor)) ) ] | length == 0' \
  FEATURES.json >/dev/null \
  || fail "FEATURES.json: evaluate must be ui|none, bar a string, eval_attempts an integer"

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
grep -q 'harness-session' ARCHITECTURE.md || fail "ARCHITECTURE.md: harness-session dogfood coverage missing"

# --- plugin packaging -------------------------------------------------------

jq -e '.name == "agent-harness-kit" and (.version | type == "string")' \
  .claude-plugin/plugin.json >/dev/null 2>&1 \
  || fail "plugin.json missing, invalid, or wrong name"
jq -e '.plugins[0].name == "agent-harness-kit" and .plugins[0].source == "./"' \
  .claude-plugin/marketplace.json >/dev/null 2>&1 \
  || fail "marketplace.json missing, invalid, or wrong plugin entry"
[ "$(jq -r .version .claude-plugin/plugin.json)" = "$(jq -r '.plugins[0].version' .claude-plugin/marketplace.json)" ] \
  || fail "plugin.json / marketplace.json version mismatch"
[ -f package.json ] || fail "package.json missing"
[ "$(jq -r .version .claude-plugin/plugin.json)" = "$(jq -r .version package.json)" ] \
  || fail "plugin.json / package.json version mismatch"

# --- templates ------------------------------------------------------------

TMPL_DIR="skills/harness-initial-setup/templates"
SESSION_SKILL_MD="skills/harness-session/SKILL.md"

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
grep -q 'harness-session' "$TMPL_DIR/AGENTS.md.tmpl" \
  || fail "AGENTS.md.tmpl does not mention harness-session"

# pointer.md.tmpl: a pointer, nothing more
[ -f "$TMPL_DIR/pointer.md.tmpl" ] || fail "pointer.md.tmpl missing"
[ "$(wc -l < "$TMPL_DIR/pointer.md.tmpl")" -le 5 ] || fail "pointer.md.tmpl must stay a one-line pointer"

# ARCHITECTURE.md.tmpl: living shape doc with all required sections
ARCH_TMPL="$TMPL_DIR/ARCHITECTURE.md.tmpl"
[ -f "$ARCH_TMPL" ] || fail "ARCHITECTURE.md.tmpl missing"
grep -q '{{' "$ARCH_TMPL" || fail "ARCHITECTURE.md.tmpl has no {{placeholders}}"
grep -q '^## System diagram' "$ARCH_TMPL" || fail "ARCHITECTURE.md.tmpl: system diagram section missing"
grep -q '^## Module map' "$ARCH_TMPL" || fail "ARCHITECTURE.md.tmpl: module map section missing"
grep -q '^## Key entities' "$ARCH_TMPL" || fail "ARCHITECTURE.md.tmpl: key entities section missing"
grep -q '^## Cross-cutting invariants' "$ARCH_TMPL" || fail "ARCHITECTURE.md.tmpl: invariants section missing"
grep -q '^## Subsystem notes' "$ARCH_TMPL" || fail "ARCHITECTURE.md.tmpl: subsystem notes section missing"
grep -q '{{LOGGING_STRATEGY}}' "$ARCH_TMPL" || fail "ARCHITECTURE.md.tmpl: logging/observability placeholder missing"
! grep -qi 'claude' "$ARCH_TMPL" || fail "ARCHITECTURE.md.tmpl must be agent-neutral"
grep -q 'ARCHITECTURE.md' "$TMPL_DIR/AGENTS.md.tmpl" || fail "AGENTS.md.tmpl does not map ARCHITECTURE.md"

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

# e2e.sh.tmpl: bounded output by construction (full log on disk, short terminal report)
gate_tmp="$(mktemp -d)"
sed 's/{{[A-Za-z0-9_]*}}/true/g' "$TMPL_DIR/e2e.sh.tmpl" > "$gate_tmp/green.sh"
green_out="$(bash "$gate_tmp/green.sh")" || fail "e2e.sh.tmpl: green substitution exited non-zero"
echo "$green_out" | grep -q 'GATE GREEN' || fail "e2e.sh.tmpl: green run missing GATE GREEN"
echo "$green_out" | grep -q 'FULL_LOG:' || fail "e2e.sh.tmpl: green run does not name FULL_LOG"
[ "$(echo "$green_out" | wc -l)" -le 10 ] || fail "e2e.sh.tmpl: green run prints more than 10 lines"
sed -e 's/{{TEST_COMMAND}}/seq 1 300; false/' -e 's/{{[A-Za-z0-9_]*}}/true/g' "$TMPL_DIR/e2e.sh.tmpl" > "$gate_tmp/red.sh"
if red_out="$(bash "$gate_tmp/red.sh" 2>&1)"; then fail "e2e.sh.tmpl: red substitution exited 0"; fi
echo "$red_out" | grep -q 'FAIL  tests' || fail "e2e.sh.tmpl: red run does not name the failing step"
[ "$(echo "$red_out" | wc -l)" -le 70 ] || fail "e2e.sh.tmpl: red run prints more than 70 lines"
red_log="$(echo "$red_out" | sed -n 's/^FULL_LOG: //p')"
[ "$(grep -c '^[0-9]' "$red_log")" -eq 300 ] || fail "e2e.sh.tmpl: full log does not retain the noisy output"
rm -rf "$gate_tmp"

# protocol doc: exists, has the planning section, no Claude-isms
PROTO="$TMPL_DIR/harness-protocol.md"
[ -f "$PROTO" ] || fail "harness-protocol.md missing"
grep -q '^## 1\. Planning protocol' "$PROTO" || fail "protocol: '## 1. Planning protocol' missing"
grep -q 'PRODUCT\.md' "$PROTO" || fail "protocol: planning section never mentions PRODUCT.md"
grep -qi 'verify' "$PROTO" || fail "protocol: planning section never teaches the verify field"
! grep -qi 'claude' "$PROTO" || fail "protocol doc must be agent-neutral (found 'claude')"
grep -q 'Already have requirements' "$PROTO" || fail "protocol: PRD-input rule missing from section 1.1"
grep -q 'Choose the verification tooling' "$PROTO" || fail "protocol: verification tooling section (1.7) missing"
grep -q 'Write ARCHITECTURE.md' "$PROTO" || fail "protocol: architecture section (1.8) missing"
grep -q 'update ARCHITECTURE.md in the same commit' "$PROTO" || fail "protocol: session architecture-update rule missing"
grep -q 'Choose the logging/observability approach' "$PROTO" || fail "protocol: logging/observability section (1.9) missing"
grep -q 'bounded' "$PROTO" || fail "protocol: bounded-gate-output contract (1.6) missing"
grep -q 'native plan mode' "$PROTO" || fail "protocol: native-plan-mode rule (1.5) missing"
grep -q 'one harness coding session' "$PROTO" || fail "protocol: plan header routing tasks through harness sessions (1.5) missing"
grep -q 'one harness coding session' "$TMPL_DIR/AGENTS.md.tmpl" || fail "AGENTS.md.tmpl: plan-execution rule missing"

grep -q '^## 2\. Coding-session protocol' "$PROTO" || fail "protocol: coding-session section missing"
grep -q 'git log -20' "$PROTO" || fail "protocol: session loop must start from git log -20"
grep -q 'ONE feature' "$PROTO" || fail "protocol: one-feature-per-session rule missing"
grep -q 'CONTINUING INTERRUPTED FEATURE' "$PROTO" || fail "protocol: interrupted-feature continuation rule missing"
grep -q 'scripts/preflight.sh' "$PROTO" || fail "protocol: optional target preflight rule missing"
grep -q 'tracked by another failing or deferred feature' "$PROTO" || fail "protocol: out-of-scope-warning rule missing"
grep -q 'Execution mode' "$PROTO" || fail "protocol: execution-mode choice (2.4) missing"
grep -q 'show-me' "$PROTO" || fail "protocol: show-me rule for explanations and summaries missing"
grep -q 'show-me' "$TMPL_DIR/AGENTS.md.tmpl" || fail "AGENTS.md.tmpl: show-me rule missing"
grep -q 'own built-in' "$PROTO" || fail "protocol: own-tools-only execution rule missing"

grep -q '^## 3\. Maintenance protocol' "$PROTO" || fail "protocol: maintenance section missing"
grep -qi 'entropy' "$PROTO" || fail "protocol: maintenance section must cover entropy GC"

# orchestrated runs (M17): optional lane fields, documented end to end
grep -q 'Depends on' "$PROTO" || fail "protocol: depends_on planning question missing (1.4)"
grep -q 'Paths touched' "$PROTO" || fail "protocol: paths planning question missing (1.4)"
grep -q '### 2.7 Orchestrated runs' "$PROTO" || fail "protocol: orchestrated-runs section (2.7) missing"
grep -q 'depends_on' "$TMPL_DIR/FEATURES.json.tmpl" || fail "FEATURES.json.tmpl: optional lane fields undocumented"
grep -q 'harness-run' "$TMPL_DIR/AGENTS.md.tmpl" || fail "AGENTS.md.tmpl does not mention harness-run"
grep -q 'harness-run' README.md || fail "README: harness-run skill missing"
grep -q 'absent fields stay sequential' README.md || fail "README: upgrade note for lane fields missing"
grep -q 'depends_on' skills/harness-audit/SKILL.md || fail "harness-audit SKILL.md: lane-field suggestion missing"
grep -qi 'never touch FEATURES.json or PROGRESS.md' "$SESSION_SKILL_MD" || fail "harness-session SKILL.md: lane rule must forbid FEATURES.json/PROGRESS.md writes"
grep -q 'harness-run line' skills/harness-upgrade-structure/SKILL.md || fail "harness-upgrade-structure SKILL.md: upgrade must add the harness-run line to AGENTS.md"

# SKILL.md: valid frontmatter, references only templates that exist
SKILL="skills/harness-initial-setup/SKILL.md"
[ -f "$SKILL" ] || fail "SKILL.md missing"
[ "$(head -1 "$SKILL")" = "---" ] || fail "SKILL.md: missing frontmatter"
grep -q '^name: harness-initial-setup$' "$SKILL" || fail "SKILL.md: frontmatter name wrong"
grep -q '^description: ' "$SKILL" || fail "SKILL.md: frontmatter description missing"
grep -q 'Already harnessed' "$SKILL" || fail "SKILL.md: already-initialized guard missing"
grep -q 'ARCHITECTURE.md' "$SKILL" || fail "SKILL.md: architecture scaffold step missing"
grep -q 'logging/observability' "$SKILL" || fail "SKILL.md: logging/observability scaffold step missing"
grep -q 'native plan mode' "$SKILL" || fail "SKILL.md: native plan mode step missing"
while read -r ref; do
  [ -f "skills/harness-initial-setup/$ref" ] || fail "SKILL.md references missing file: $ref"
done < <(grep -oE 'templates/[A-Za-z0-9._-]+' "$SKILL" | sort -u)

# README: all three quickstarts present
grep -q '/plugin marketplace add' README.md || fail "README: plugin install quickstart missing"
grep -q '\.claude/skills' README.md || fail "README: manual copy fallback missing"
grep -q 'harness-protocol.md' README.md || fail "README: non-Claude quickstart missing"
grep -q 'PRD' README.md || fail "README: PRD-input section missing"
grep -q 'Using the skills' README.md || fail "README: using-the-skills prompts section missing"
grep -q 'harness-status' README.md || fail "README: harness-status skill missing"
grep -q '/agent-harness-kit:harness-initial-setup' README.md || fail "README: slash-command forms missing"
grep -q '## Lifecycle' README.md || fail "README: lifecycle section missing"
grep -q 'harness-handoff' README.md || fail "README: harness-handoff skill missing"
grep -q 'Switching agents' README.md || fail "README: switching-agents section missing"
grep -q 'codex plugin marketplace add' README.md || fail "README: Codex quickstart missing"
grep -q 'claude plugin update' README.md || fail "README: Claude update command missing"
grep -q 'ARCHITECTURE.md' README.md || fail "README: ARCHITECTURE.md coverage missing"
grep -qi 'logging/observability' README.md || fail "README: logging/observability coverage missing"
grep -q 'harness-session' README.md || fail "README: harness-session skill missing"
grep -q 'run-gate.sh' README.md || fail "README: run-gate.sh coverage missing"
grep -q 'native plan mode' README.md || fail "README: native plan mode coverage missing"
grep -q 'humanlayer.com/blog/show-me-skill' README.md || fail "README: show-me credit missing"
# no third-party workflow plugin is ever required to plan or execute
! grep -rqi 'superpowers' skills README.md || fail "a skill/template/README references a third-party workflow plugin"

# --- harness-audit skill ----------------------------------------------------

AUDIT="skills/harness-audit"
[ -f "$AUDIT/scripts/check.sh" ] || fail "harness-audit check.sh missing"
shellcheck "$AUDIT/scripts/check.sh"
[ -f "$AUDIT/SKILL.md" ] || fail "harness-audit SKILL.md missing"
[ "$(head -1 "$AUDIT/SKILL.md")" = "---" ] || fail "harness-audit SKILL.md: missing frontmatter"
grep -q '^name: harness-audit$' "$AUDIT/SKILL.md" || fail "harness-audit SKILL.md: frontmatter name wrong"
grep -q '^description: ' "$AUDIT/SKILL.md" || fail "harness-audit SKILL.md: description missing"
grep -q 'ARCHITECTURE.md' "$AUDIT/SKILL.md" || fail "harness-audit SKILL.md: architecture repair flow missing"
bash scripts/test-audit.sh

# --- harness-status skill -----------------------------------------------------

STATUS_SKILL="skills/harness-status"
[ -f "$STATUS_SKILL/scripts/status.sh" ] || fail "harness-status status.sh missing"
shellcheck "$STATUS_SKILL/scripts/status.sh"
[ -f "$STATUS_SKILL/SKILL.md" ] || fail "harness-status SKILL.md missing"
[ "$(head -1 "$STATUS_SKILL/SKILL.md")" = "---" ] || fail "harness-status SKILL.md: missing frontmatter"
grep -q '^name: harness-status$' "$STATUS_SKILL/SKILL.md" || fail "harness-status SKILL.md: frontmatter name wrong"
grep -q '^description: ' "$STATUS_SKILL/SKILL.md" || fail "harness-status SKILL.md: description missing"
grep -q 'show-me' "$STATUS_SKILL/SKILL.md" || fail "harness-status SKILL.md: show-me relay step missing"
bash scripts/test-status.sh

# --- harness-handoff skill ----------------------------------------------------

HANDOFF_SKILL="skills/harness-handoff"
[ -f "$HANDOFF_SKILL/scripts/handoff.sh" ] || fail "harness-handoff handoff.sh missing"
shellcheck "$HANDOFF_SKILL/scripts/handoff.sh"
[ -f "$HANDOFF_SKILL/SKILL.md" ] || fail "harness-handoff SKILL.md missing"
[ "$(head -1 "$HANDOFF_SKILL/SKILL.md")" = "---" ] || fail "harness-handoff SKILL.md: missing frontmatter"
grep -q '^name: harness-handoff$' "$HANDOFF_SKILL/SKILL.md" || fail "harness-handoff SKILL.md: frontmatter name wrong"
grep -q '^description: ' "$HANDOFF_SKILL/SKILL.md" || fail "harness-handoff SKILL.md: description missing"
bash scripts/test-handoff.sh

# --- harness-session skill -----------------------------------------------

SESSION_SKILL="skills/harness-session"
[ -f "$SESSION_SKILL/scripts/context.sh" ] || fail "harness-session context.sh missing"
shellcheck "$SESSION_SKILL/scripts/context.sh"
[ -f "$SESSION_SKILL/scripts/run-gate.sh" ] || fail "harness-session run-gate.sh missing"
shellcheck "$SESSION_SKILL/scripts/run-gate.sh"
grep -q 'run-gate.sh' "$SESSION_SKILL/SKILL.md" || fail "harness-session SKILL.md: does not reference run-gate.sh"
grep -qi 'delegated' "$SESSION_SKILL/SKILL.md" || fail "harness-session SKILL.md: execution-mode proposal missing"
grep -q 'UPGRADE: offer' "$SESSION_SKILL/SKILL.md" || fail "harness-session SKILL.md: upgrade-offer step missing"
grep -q 'UPGRADE: offer' README.md || fail "README: plugin-upgrade notice coverage missing"
[ -f "$SESSION_SKILL/SKILL.md" ] || fail "harness-session SKILL.md missing"
[ "$(head -1 "$SESSION_SKILL/SKILL.md")" = "---" ] || fail "harness-session SKILL.md: missing frontmatter"
grep -q '^name: harness-session$' "$SESSION_SKILL/SKILL.md" || fail "harness-session SKILL.md: frontmatter name wrong"
grep -q '^description: ' "$SESSION_SKILL/SKILL.md" || fail "harness-session SKILL.md: description missing"
grep -q '^description: .*execution plan' "$SESSION_SKILL/SKILL.md" || fail "harness-session SKILL.md: description does not trigger on executing a plan"
grep -q 'SESSION: <id> · <passing|review|blocked>' "$SESSION_SKILL/SKILL.md" || fail "harness-session SKILL.md: end-of-session summary contract missing"
grep -qi 'inside a subagent.*inline' "$SESSION_SKILL/SKILL.md" || fail "harness-session SKILL.md: subagent sessions must run inline"
bash scripts/test-session.sh

# --- harness-run skill ---------------------------------------------------

RUN_SKILL="skills/harness-run"
[ -f "$RUN_SKILL/SKILL.md" ] || fail "harness-run SKILL.md missing"
[ "$(head -1 "$RUN_SKILL/SKILL.md")" = "---" ] || fail "harness-run SKILL.md: missing frontmatter"
grep -q '^name: harness-run$' "$RUN_SKILL/SKILL.md" || fail "harness-run SKILL.md: frontmatter name wrong"
grep -q '^description: ' "$RUN_SKILL/SKILL.md" || fail "harness-run SKILL.md: description missing"
grep -q 'SESSION: <id> · <passing|review|blocked>' "$RUN_SKILL/SKILL.md" || fail "harness-run SKILL.md: summary contract missing"
grep -q 'status.sh' "$RUN_SKILL/SKILL.md" || fail "harness-run SKILL.md: status.sh verification missing"
grep -qi 'cap.*default 10' "$RUN_SKILL/SKILL.md" || fail "harness-run SKILL.md: run cap missing"
grep -qi 'no subagent' "$RUN_SKILL/SKILL.md" || fail "harness-run SKILL.md: no-subagent fallback missing"
grep -q 'PARALLEL:' "$RUN_SKILL/SKILL.md" || fail "harness-run SKILL.md: parallel lanes missing"
grep -q 'git worktree' "$RUN_SKILL/SKILL.md" || fail "harness-run SKILL.md: lane worktrees missing"
grep -qi 'never touch FEATURES.json' "$RUN_SKILL/SKILL.md" || fail "harness-run SKILL.md: lanes must not write FEATURES.json"
grep -qi 'redo.*sequentially' "$RUN_SKILL/SKILL.md" || fail "harness-run SKILL.md: merge-conflict fallback missing"
grep -q 'harness-builder' "$RUN_SKILL/SKILL.md" || fail "harness-run SKILL.md: named harness-builder missing"
grep -q 'harness-evaluator' "$RUN_SKILL/SKILL.md" || fail "harness-run SKILL.md: named harness-evaluator missing"
grep -q 'HEAD unchanged' "$RUN_SKILL/SKILL.md" || fail "harness-run SKILL.md: post-evaluator integrity check missing"
grep -q 'docs/verification/<id>.md' "$RUN_SKILL/SKILL.md" || fail "harness-run SKILL.md: evidence file missing"
grep -q 'eval_attempts' "$RUN_SKILL/SKILL.md" || fail "harness-run SKILL.md: eval_attempts rule missing"
grep -q 'reaching 2' "$RUN_SKILL/SKILL.md" || fail "harness-run SKILL.md: STOP-at-2-attempts rule missing"

# --- harness-continuous skill (M20) ----------------------------------------

shellcheck skills/harness-run/scripts/run-report.sh
bash scripts/test-run.sh

# --- agents (M18) --------------------------------------------------------

jq -e '.models | (.claude and .copilot and .codex)' agents/models.json >/dev/null \
  || fail "agents/models.json: missing a CLI model map"
bash scripts/test-agents.sh

# evaluator documented end to end (M18)
grep -q 'Can the gate prove this' "$PROTO" || fail "protocol: 'Can the gate prove this?' question missing (1.4)"
grep -q 'docs/verification/<id>.md' "$PROTO" || fail "protocol: evidence file (2.7) missing"
grep -q 'NEEDS_WORK' "$PROTO" || fail "protocol: review step (2.7) missing"
for w in review evaluate bar; do
  grep -q "$w" "$TMPL_DIR/FEATURES.json.tmpl" || fail "FEATURES.json.tmpl: $w undocumented"
done
grep -q 'harness-evaluator' skills/harness-audit/scripts/check.sh || fail "harness-audit: missing-agent-files WARN missing"
grep -qi 'independent evaluator' README.md || fail "README: evaluator missing"
grep -q 'gen-agents.sh' skills/harness-initial-setup/SKILL.md || fail "harness-initial-setup SKILL.md: gen-agents step missing"

# --- harness-brief skill (M19) ---------------------------------------------

BRIEF_SKILL="skills/harness-brief"
shellcheck "$BRIEF_SKILL/scripts/check-brief.sh"
bash scripts/test-brief.sh

# planning consumes briefs; needs-a-human boundary (M19)
grep -q 'Already have a brief' "$PROTO" || fail "protocol: 'Already have a brief' rule missing (1.1)"
grep -q '^## Needs a human' "$TMPL_DIR/AGENTS.md.tmpl" || fail "AGENTS.md.tmpl: Needs a human section missing"
for w in 'deploy or publish' 'push to' 'production data' 'adding dependencies' 'auth' 'deleting or renumbering'; do
  grep -qi "$w" "$TMPL_DIR/AGENTS.md.tmpl" || fail "AGENTS.md.tmpl: Needs a human default missing: $w"
done
grep -q 'harness-brief' README.md || fail "README: harness-brief missing"
grep -Eq 'brief.*plan.*run' README.md || fail "README: lifecycle must show brief -> plan -> run"

# --- continuous runs documented end to end (M20) -----------------------------

[ "$(jq -r .version .claude-plugin/plugin.json)" = "3.1.0" ] || fail "plugin version must be 3.1.0"
grep -q '^### 2\.8 Continuous runs' "$PROTO" || fail "protocol: continuous-runs section (2.8) missing"
for w in 'harness-continuous' 'git stash push -u' 'Question for the human' '.harness-run/STOP' 'status.sh --skip' 'docs/runs/' 'run-report.sh' 'depends_on'; do
  sed -n '/^### 2\.8 Continuous runs/,/^## 3\./p' "$PROTO" | grep -qF -- "$w" || fail "protocol 2.8: '$w' missing"
done
grep -q 'do not wait for the PR to merge' "$PROTO" || fail "protocol 2.5: plan must move to completed/ in the last feature's commit"
grep -q 'harness-continuous' README.md || fail "README: harness-continuous missing from the skills"
grep -q '^## Unattended runs' README.md || fail "README: 'Unattended runs' section missing"
grep -q '^## Upgrading a repo and running continuously' README.md || fail "README: upgrade-and-run walkthrough missing"
if grep -qE -- '--yolo|--dangerously-skip-permissions|--allow-all' README.md; then
  fail "README: must not suggest skip-all-permissions flags"
fi
walk="$(sed -n '/^## Upgrading a repo and running continuously/,/^## /p' README.md)"
grep -qF 'a skipped feature stops the run' <<< "$walk" || fail "README walkthrough: must say that without depends_on a skipped feature stops the run"
grep -qF 'harness-run skip <id>' <<< "$walk" || fail "README walkthrough: stash recovery hint missing"
last=0
for w in 'Update the plugin' 'green gate' 'UPGRADE: offer' 'harness-audit' 'gen-agents.sh' 'harness-continuous' '.harness-run/STOP' 'docs/runs/' 'git stash list'; do
  n="$(grep -nF -m1 -- "$w" <<< "$walk" | cut -d: -f1)"
  [ -n "$n" ] || fail "README walkthrough: step '$w' missing"
  [ "$n" -gt "$last" ] || fail "README walkthrough: '$w' is out of order"
  last="$n"
done

# --- renamed entry point (M21): no live reference to the old skill name ------

old_name="harness-""setup"
[ ! -e "skills/$old_name" ] || fail "skills/$old_name still exists (renamed to harness-initial-setup)"
# the README's one rename note ("was renamed") is the only allowed mention
if git grep -nI -e "$old_name" -- . ':!docs/plans' ':!docs/specs' ':!PROGRESS.md' ':!FEATURES.json' | grep -v 'was renamed' | grep -q .; then
  fail "stale reference to the old skill name '$old_name'"
fi
[ -f skills/harness-initial-setup/SKILL.md ] || fail "harness-initial-setup SKILL.md missing"
grep -q '^description: .*harness-upgrade-structure' skills/harness-initial-setup/SKILL.md || fail "harness-initial-setup: description must point existing repos at harness-upgrade-structure"

# --- harness-upgrade-structure (M21) -----------------------------------------

shellcheck skills/harness-upgrade-structure/scripts/upgrade.sh
bash scripts/test-upgrade.sh
grep -q '^## Upgrading existing repos' README.md || fail "README: 'Upgrading existing repos' section missing"
grep -q 'harness-upgrade-structure/scripts/upgrade.sh' README.md || fail "README: by-hand upgrade.sh command missing"
grep -q 'harness-upgrade-structure' <<< "$walk" || fail "README walkthrough: upgrade step must use harness-upgrade-structure"

# --- strict-YAML-safe frontmatter (M22) ----------------------------------------
# Copilot CLI and Codex CLI reject (silently skip) a skill whose unquoted
# name/description contains ': ' — Claude Code does not, so check it here.
for f in skills/*/SKILL.md agents/src/*.md; do
  if grep -qE '^(name|description): .*: ' "$f"; then
    fail "$f: unquoted ': ' in frontmatter name/description breaks strict YAML parsers (Copilot, Codex)"
  fi
done

# --- decision notes (M23-001) ------------------------------------------------
# Most failures are a right answer considered and rejected; the session entry
# records those choices so a reviewer can ask for the thing that was skipped.
close_out="$(sed -n '/^### 2\.5 Close out/,/^### 2\.6/p' "$PROTO")"
grep -qF 'Decisions:' <<< "$close_out" || fail "protocol 2.5: PROGRESS.md entry must ask for a Decisions: line"
grep -qF 'options considered and rejected' <<< "$close_out" || fail "protocol 2.5: Decisions: must name options considered and rejected"
grep -qF 'assumptions made' <<< "$close_out" || fail "protocol 2.5: Decisions: must name assumptions made"
grep -q '^- Decisions:' "$TMPL_DIR/PROGRESS.md.tmpl" || fail "PROGRESS.md.tmpl: entry must show a Decisions: line"
grep -qF 'Decisions:' agents/src/harness-builder.md || fail "harness-builder: must write the Decisions: line"
grep -qF 'Decisions:' agents/src/harness-evaluator.md || fail "harness-evaluator: must read the Decisions: line"
grep -qF 'leads, not evidence' agents/src/harness-evaluator.md || fail "harness-evaluator: Decisions: are leads, not evidence"
grep -qF 'leads, not evidence' "$PROTO" || fail "protocol 2.7: evaluator reads Decisions: as leads, not evidence"

# --- per-feature effort (M23-002) ----------------------------------------------
jq -e '[ .features[] | select(has("effort") and (.effort | IN("low","medium","high","max") | not)) ] | length == 0' \
  FEATURES.json >/dev/null || fail "FEATURES.json: effort must be low|medium|high|max"
grep -q 'effort' "$TMPL_DIR/FEATURES.json.tmpl" || fail "FEATURES.json.tmpl: effort undocumented"
plan_14="$(sed -n '/^### 1\.4 Write FEATURES.json entries/,/^### 1\.5/p' "$PROTO")"
grep -qF 'How much verification does this deserve?' <<< "$plan_14" || fail "protocol 1.4: effort question missing"
grep -qF 'low, medium, high or max' <<< "$plan_14" || fail "protocol 1.4: effort levels missing"
grep -qF 'effort:' "$RUN_SKILL/SKILL.md" || fail "harness-run SKILL.md: must pass the effort line to the builder dispatch"
grep -qF 'evaluator at high or above' "$RUN_SKILL/SKILL.md" || fail "harness-run SKILL.md: evaluator must be dispatched at high or above"
grep -qF 'effort:' "$SESSION_SKILL_MD" || fail "harness-session SKILL.md: must read the effort line"

# --- model-tagged rules, start lean (M23-003) -----------------------------------
# Rules written to fix one model's failure over-constrain the next model.
grep -qF '(model: <name>)' <<< "$(sed -n '/^### 3\.4/,/^Copy-paste maintenance prompt/p' "$PROTO")" \
  || fail "protocol 3.4: a rule for one model's repeated failure must be tagged (model: <name>)"
grep -qF 're-test every rule tagged' <<< "$(sed -n '/^### 3\.2 Doc gardening/,/^### 3\.3/p' "$PROTO")" \
  || fail "protocol 3.2: re-test tagged rules when the model changes"
grep -qF '(model: <name>)' "$TMPL_DIR/AGENTS.md.tmpl" || fail "AGENTS.md.tmpl: model-tag rule missing"
grep -qF 'model-tagged' skills/harness-audit/scripts/check.sh || fail "harness-audit: model-tagged WARN missing"
grep -q '^## Decision notes, effort and model-tagged rules' README.md || fail "README: M23 section missing"
for w in 'Decisions:' 'effort' '(model: <name>)'; do
  sed -n '/^## Decision notes, effort and model-tagged rules/,/^## /p' README.md | grep -qF -- "$w" \
    || fail "README M23 section: '$w' missing"
done

# --- Claude edition plugin (M24-001) -------------------------------------------
# A second plugin in this marketplace that adds Claude Code-only features on
# top of the core plugin. It never copies the protocol: the core owns it.
ED=".claude-plugin/plugin.json"
ED_MANIFEST="claude/.claude-plugin/plugin.json"
[ -f "$ED_MANIFEST" ] || fail "Claude edition: $ED_MANIFEST missing"
jq -e '.name == "agent-harness-kit-mods" and ((.dependencies // []) | index("agent-harness-kit") != null)' "$ED_MANIFEST" >/dev/null \
  || fail "Claude edition: plugin.json must be agent-harness-kit-mods and depend on agent-harness-kit"
jq -e '[.plugins[] | select(.name == "agent-harness-kit-mods" and .source == "./claude")] | length == 1' .claude-plugin/marketplace.json >/dev/null \
  || fail "marketplace.json: Claude edition entry (source ./claude) missing"
core_v="$(jq -r .version "$ED")"
[ "$(jq -r .version "$ED_MANIFEST")" = "$core_v" ] || fail "Claude edition: plugin.json version must match the core ($core_v)"
[ "$(jq -r '.plugins[] | select(.name == "agent-harness-kit-mods") | .version' .claude-plugin/marketplace.json)" = "$core_v" ] \
  || fail "marketplace.json: Claude edition version must match the core ($core_v)"
if find claude -name 'harness-protocol.md' | grep -q .; then fail "Claude edition must not copy harness-protocol.md"; fi
grep -qF '/plugin install agent-harness-kit-mods' README.md || fail "README: Claude edition install line missing"
# claude plugin validate when the CLI is present (CI runners may not have it)
if command -v claude >/dev/null; then
  claude plugin validate --strict claude >/dev/null 2>&1 || fail "claude plugin validate --strict claude/ failed"
  claude plugin validate . >/dev/null 2>&1 || fail "claude plugin validate . (marketplace) failed"
fi

# --- Claude edition: auto mode + eval suite (M24-003) ---------------------------
edition="$(sed -n '/^## Claude Code edition/,/^## [^C]/p' README.md)"
grep -qF 'claude --permission-mode auto' <<< "$edition" || fail "README Claude edition: auto mode start command missing"
grep -qF 'harness-continuous' <<< "$edition" || fail "README Claude edition: harness-continuous on auto mode missing"
grep -qF 'Never use the bypass mode' <<< "$edition" || fail "README Claude edition: must rule out bypass mode"
if grep -qE 'bypassPermissions|--dangerously-skip-permissions' <<< "$edition"; then
  fail "README Claude edition: must not name a bypass flag"
fi
grep -qF 'claude plugin eval . --eval-dir claude/evals' <<< "$edition" || fail "README Claude edition: eval command missing"
for c in brief-from-rough-prompt:harness-brief session-builds-next-feature:harness-session; do
  case_dir="claude/evals/${c%%:*}"; skill="${c##*:}"
  [ -f "$case_dir/prompt.md" ] || fail "eval case $case_dir: prompt.md missing"
  grep -qF 'plugins: ["../../.."]' "$case_dir/prompt.md" || fail "eval case $case_dir: must load the core plugin (plugins: [\"../../..\"])"
  grep -rqF "$skill" "$case_dir/graders" || fail "eval case $case_dir: no grader names $skill"
  [ -f "$case_dir/scaffold.sh" ] && shellcheck "$case_dir/scaffold.sh"
  ls "$case_dir"/graders/*.md >/dev/null 2>&1 || fail "eval case $case_dir: no graders"
done
git check-ignore -q claude/evals/results/x || fail ".gitignore: claude/evals/results/ must be ignored"

echo "GATE GREEN"
