#!/usr/bin/env bash
# Sync the agent-harness-template mirror from this repo's templates (M27-005).
# Usage: sync-template.sh <mirror-dir> [--check]
# Writes every template to its mirror path. The mirror keeps its own README.md,
# docs/PRODUCT.md, LICENSE, .gitignore and the "uninitialized" banner at the
# top of AGENTS.md. Idempotent; commits nothing.
# --check: change nothing; print STALE: <path> per out-of-date file, exit 1
# when any is stale, 0 when the mirror is in sync.
set -euo pipefail

kit="$(cd "$(dirname "$0")/.." && pwd)"
T="$kit/skills/harness-initial-setup/templates"
mirror="${1:?usage: sync-template.sh <mirror-dir> [--check]}"
check=0; [ "${2:-}" = "--check" ] && check=1
[ -d "$mirror" ] || { echo "sync-template: no such directory: $mirror" >&2; exit 2; }

# template -> mirror path
map="harness-protocol.md:docs/agents/harness-protocol.md
harness-protocol-planning.md:docs/agents/harness-protocol-planning.md
harness-protocol-runs.md:docs/agents/harness-protocol-runs.md
harness-protocol-maintenance.md:docs/agents/harness-protocol-maintenance.md
FEATURES.json.tmpl:FEATURES.json
PROGRESS.md.tmpl:PROGRESS.md
ARCHITECTURE.md.tmpl:ARCHITECTURE.md
pointer.md.tmpl:CLAUDE.md
pointer.md.tmpl:GEMINI.md
dev.sh.tmpl:scripts/dev.sh
e2e.sh.tmpl:scripts/e2e.sh"

build="$(mktemp -d)"; trap 'rm -rf "$build"' EXIT

# AGENTS.md: the template's title line, the mirror's banner (the first block
# of "> " lines after the title), then the rest of the template.
agents="$build/AGENTS.md"
banner="$(awk 'NR > 1 && /^>( |$)/ { b = 1; print; next } b { exit }' "$mirror/AGENTS.md" 2>/dev/null || true)"
{
  head -1 "$T/AGENTS.md.tmpl"
  if [ -n "$banner" ]; then printf '\n%s\n' "$banner"; fi
  tail -n +2 "$T/AGENTS.md.tmpl"
} > "$agents"

stale=0
sync_one() { # sync_one <source> <mirror path>
  local src="$1" dst="$mirror/$2"
  if cmp -s "$src" "$dst"; then return 0; fi
  if [ "$check" -eq 1 ]; then echo "STALE: $2"; stale=1; return 0; fi
  mkdir -p "$(dirname "$dst")"
  cp "$src" "$dst"
  case "$2" in scripts/*.sh) chmod +x "$dst" ;; esac
  echo "SYNCED: $2"
}

while IFS=: read -r src dst; do sync_one "$T/$src" "$dst"; done <<< "$map"
sync_one "$agents" AGENTS.md
for d in docs/plans/active docs/plans/completed; do
  if [ ! -e "$mirror/$d/.gitkeep" ]; then
    if [ "$check" -eq 1 ]; then echo "STALE: $d/.gitkeep"; stale=1
    else mkdir -p "$mirror/$d"; : > "$mirror/$d/.gitkeep"; echo "SYNCED: $d/.gitkeep"; fi
  fi
done

if [ "$check" -eq 1 ]; then
  [ "$stale" -eq 0 ] && echo "IN SYNC: $mirror"
  exit "$stale"
fi
echo "DONE: review git diff in $mirror, commit, open a PR there"
