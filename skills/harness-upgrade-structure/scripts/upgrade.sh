#!/usr/bin/env bash
# harness-upgrade-structure: bring a repo that ALREADY has a harness up to the
# structure the installed plugin ships. Idempotent; stages and commits nothing.
# Usage: upgrade.sh [TARGET_DIR]    (default: current directory)
# Prints OK: / CHANGED: / TODO: lines. TODO lines need a human or an agent.
# Exit codes: 0 done; 2 refused (not a git repo, dirty tree, branch taken);
# 3 no harness here (use harness-initial-setup).
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SKILLS="$HERE/../.."
TEMPLATES="$SKILLS/harness-initial-setup/templates"
GEN_AGENTS="$SKILLS/../scripts/gen-agents.sh"

cd "${1:-.}"
if [ ! -f FEATURES.json ] || [ ! -f PROGRESS.md ]; then
  echo "HARNESS NOT INITIALIZED: FEATURES.json and/or PROGRESS.md missing."
  echo "This command is for repos that already have a harness; use the harness-initial-setup skill here."
  exit 3
fi
command -v jq >/dev/null || { echo "ERROR: jq is required" >&2; exit 2; }
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "refusing: not a git repository" >&2; exit 2; }
if [ -n "$(git status --short)" ]; then
  echo "refusing: dirty worktree — commit or stash your changes first" >&2
  exit 2
fi

# never upgrade on the default branch: branch off it
default="$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##' || true)"
if [ -z "$default" ]; then
  for b in main master; do
    if git show-ref --verify --quiet "refs/heads/$b"; then default="$b"; break; fi
  done
fi
current="$(git branch --show-current)"
if [ -n "$default" ] && [ "$current" = "$default" ]; then
  git switch -q -c harness-upgrade 2>/dev/null \
    || { echo "refusing: branch harness-upgrade already exists — switch to it or delete it" >&2; exit 2; }
  echo "BRANCH: created harness-upgrade from $default"
else
  echo "BRANCH: ${current:-detached HEAD}"
fi

# protocol copy
dest=docs/agents/harness-protocol.md
if [ ! -f "$dest" ]; then
  mkdir -p docs/agents
  cp "$TEMPLATES/harness-protocol.md" "$dest"
  echo "CHANGED: $dest (was missing; copied from the plugin)"
elif cmp -s "$TEMPLATES/harness-protocol.md" "$dest"; then
  echo "OK: $dest is current"
else
  cp "$TEMPLATES/harness-protocol.md" "$dest"
  echo "CHANGED: $dest (recopied whole from the plugin; re-add any local notes the old copy had — see git diff)"
fi

# harness-run line in AGENTS.md
if [ ! -f AGENTS.md ]; then
  echo "TODO: AGENTS.md is missing — copy and adapt $TEMPLATES/AGENTS.md.tmpl"
elif grep -q 'harness-run' AGENTS.md; then
  echo "OK: AGENTS.md mentions harness-run"
else
  para="$(awk '/^To work through several features/{p=1} p{print} p&&/§2\.7\)/{exit}' "$TEMPLATES/AGENTS.md.tmpl")"
  [ -n "$para" ] || { echo "upgrade: harness-run paragraph not found in AGENTS.md.tmpl" >&2; exit 2; }
  printf '\n%s\n' "$para" >> AGENTS.md
  echo "CHANGED: AGENTS.md (added the harness-run line)"
  lines="$(wc -l < AGENTS.md | tr -d ' ')"
  [ "$lines" -le 100 ] || echo "TODO: AGENTS.md is now $lines lines (limit 100) — trim it"
fi

# generated agent files (M27-001): a repo that has any harness agent file
# gets every role regenerated for each CLI folder it already uses, so new
# instructions (Decisions:, untrusted text, effort) reach builder, evaluator
# and brief reviewer alike. A repo with none gets them only when a feature
# opts in to evaluation (as before).
gen="$(mktemp -d)"
bash "$GEN_AGENTS" "$gen" >/dev/null
agents_changed=0; copilot_changed=0
for pair in ".claude/agents:.md" ".github/agents:.agent.md" ".codex/agents:.toml"; do
  dir="${pair%%:*}"; ext="${pair#*:}"
  ls "$dir"/harness-*"$ext" >/dev/null 2>&1 || continue
  for src in "$gen/$dir"/harness-*"$ext"; do
    dst="$dir/$(basename "$src")"
    if ! cmp -s "$src" "$dst"; then
      cp "$src" "$dst"
      echo "CHANGED: $dst (regenerated from the plugin's agent roles)"
      agents_changed=1
      [ "$dir" = .github/agents ] && copilot_changed=1
    fi
  done
done
have=0
for f in .claude/agents/harness-*.md .github/agents/harness-*.agent.md .codex/agents/harness-*.toml; do
  if [ -f "$f" ]; then have=1; fi
done
if [ "$have" -eq 0 ] && jq -e '[.features[] | select(.evaluate == "ui" or has("second_opinion"))] | length > 0' FEATURES.json >/dev/null; then
  bash "$GEN_AGENTS" "$PWD" >/dev/null
  echo "CHANGED: .claude/agents/ .github/agents/ .codex/agents/ (agent files generated for evaluation; restart Copilot CLI to see them)"
elif [ "$agents_changed" -eq 0 ]; then
  echo "OK: generated agent files are current (or not needed)"
fi
if [ "$copilot_changed" -eq 1 ]; then
  echo "TODO: restart Copilot CLI if it is running, so it reads the regenerated agents"
fi

# kit version stamp + release notes (M27-004): print the Upgrade: block of
# every CHANGELOG release newer than the version this repo was last upgraded
# to (all of them when none is recorded), then record the current version.
KIT="$SKILLS/.."
kit_v="$(jq -r '.version // empty' "$KIT/.claude-plugin/plugin.json" 2>/dev/null || true)"
stamp=docs/agents/harness-kit-version
have_v="$(tr -d '[:space:]' < "$stamp" 2>/dev/null || true)"
if [ -n "$kit_v" ] && [ -f "$KIT/CHANGELOG.md" ]; then
  awk '
    /^## [0-9]+\.[0-9]+\.[0-9]+ / { v = $2; up = 0; next }
    /^Upgrade:/ { up = 1; next }
    up && /^- / { sub(/^- /, ""); print v "\t" $0; next }
    up && /^[^ ]/ { up = 0 }
  ' "$KIT/CHANGELOG.md" > "$gen.notes" 2>/dev/null || true
  # vlt A B: version A < B, numerically per field (portable: no sort -V)
  vlt() {
    local a1 a2 a3 b1 b2 b3
    IFS=. read -r a1 a2 a3 <<< "$1"; IFS=. read -r b1 b2 b3 <<< "$2"
    [ "${a1:-0}" -lt "${b1:-0}" ] && return 0; [ "${a1:-0}" -gt "${b1:-0}" ] && return 1
    [ "${a2:-0}" -lt "${b2:-0}" ] && return 0; [ "${a2:-0}" -gt "${b2:-0}" ] && return 1
    [ "${a3:-0}" -lt "${b3:-0}" ]
  }
  # releases after the recorded one, up to the installed kit, oldest first
  awk '{ l[NR] = $0 } END { for (i = NR; i > 0; i--) print l[i] }' "$gen.notes" | while IFS=$'\t' read -r v note; do
    vlt "$kit_v" "$v" && continue
    if [ -z "$have_v" ] || vlt "$have_v" "$v"; then echo "UPGRADE-NOTE: $v: $note"; fi
  done
  rm -f "$gen.notes"
  if [ "$have_v" = "$kit_v" ]; then
    echo "OK: $stamp is $kit_v"
  else
    mkdir -p docs/agents
    printf '%s\n' "$kit_v" > "$stamp"
    echo "CHANGED: $stamp (${have_v:-none} -> $kit_v)"
  fi
fi

# things only a human or an agent can do
if [ ! -f scripts/e2e.sh ]; then
  echo "TODO: scripts/e2e.sh is missing — adapt $TEMPLATES/e2e.sh.tmpl"
elif grep -q 'FULL_LOG' scripts/e2e.sh; then
  echo "OK: scripts/e2e.sh output is bounded"
else
  echo "TODO: scripts/e2e.sh output is unbounded — wrap each command with the step function from $TEMPLATES/e2e.sh.tmpl and add echo \"FULL_LOG: \$LOG\" after GATE GREEN"
fi
if jq -e '[.features[] | select(.status == "failing" and (.depends_on | type) != "array")] | length > 0' FEATURES.json >/dev/null; then
  echo "TODO: run harness-audit and approve its depends_on/paths proposals — without declared depends_on a skipped feature stops a continuous run"
else
  echo "OK: failing features declare depends_on"
fi
rm -rf "$gen"
echo "NEXT: review git diff and every UPGRADE-NOTE line above, then commit the upgrade as its own commit."
