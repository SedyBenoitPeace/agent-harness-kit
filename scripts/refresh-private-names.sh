#!/usr/bin/env bash
# refresh-private-names.sh — write the names of every private repo you can see
# (your own and your organisations') to .git/info/private-names, outside git,
# for check-private-names.sh (M64-001). ci-local.sh runs it before each push,
# so a new private repo is covered without anyone editing a list.
# No gh, or not signed in: the existing list is kept.
set -euo pipefail
out="$(git rev-parse --git-common-dir)/info/private-names"
if ! command -v gh >/dev/null || ! gh auth status >/dev/null 2>&1; then
  echo "private-names: gh not available or not signed in; kept the existing list"; exit 0
fi
tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT
{ gh repo list --visibility private --limit 1000 --json name -q '.[].name'
  for org in $(gh api user/orgs -q '.[].login'); do
    gh repo list "$org" --visibility private --limit 1000 --json name -q '.[].name'
  done; } | sort -u > "$tmp"
mkdir -p "$(dirname "$out")"; cp "$tmp" "$out"
echo "private-names: $(wc -l < "$out" | tr -d ' ') private repo names in $out"
