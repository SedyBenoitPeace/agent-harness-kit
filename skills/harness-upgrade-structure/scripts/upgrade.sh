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

# evaluator agent files, only for repos whose features opt in
have=0
for f in .claude/agents/harness-evaluator.md .github/agents/harness-evaluator.agent.md .codex/agents/harness-evaluator.toml; do
  if [ -f "$f" ]; then have=1; fi
done
if jq -e '[.features[] | select(.evaluate == "ui")] | length > 0' FEATURES.json >/dev/null && [ "$have" -eq 0 ]; then
  bash "$GEN_AGENTS" "$PWD" >/dev/null
  echo "CHANGED: .claude/agents/ .github/agents/ .codex/agents/ (evaluator agent files generated; restart Copilot CLI to see them)"
else
  echo "OK: evaluator agent files (not needed, or already present)"
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
echo "NEXT: review git diff, then commit the upgrade as its own commit."
