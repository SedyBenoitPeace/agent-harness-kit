#!/usr/bin/env bash
# check-private-names.sh — fail when a committed file, a text (a PR body) or a
# commit message names one of the owner's private repos (M64-001). The list
# lives outside git, in .git/info/private-names (refresh-private-names.sh
# writes it from `gh repo list`); names in scripts/private-names-allow.txt are
# meant to be public. No list (CI, a contributor's clone) = skipped.
#   check-private-names.sh [--list FILE] [--messages REV_RANGE] [TEXT_FILE...]
# Whole words, case-insensitive. Exit 0 clean or skipped, 1 a name found.
set -euo pipefail
list="$(git rev-parse --git-common-dir)/info/private-names"; range=""; texts=()
while [ $# -gt 0 ]; do
  case "$1" in
    --list) list="$2"; shift 2 ;;
    --messages) range="$2"; shift 2 ;;
    *) texts+=("$1"); shift ;;
  esac
done
if [ ! -s "$list" ]; then echo "private-names: no list at $list, skipped"; exit 0; fi
names="$(mktemp)"; trap 'rm -f "$names"' EXIT
allow="$(git rev-parse --show-toplevel)/scripts/private-names-allow.txt"
grep -vxiF -f <(cat "$allow" 2>/dev/null; echo) "$list" | grep -v '^\s*$' > "$names" || true
hits=""
if [ ${#texts[@]} -gt 0 ]; then
  hits="$(grep -HnwiF -f "$names" "${texts[@]}" || true)"
else
  hits="$(git grep -nwiF -f "$names" || true)"
fi
if [ -n "$range" ]; then
  m="$(git log --format='%h %s%n%b' "$range" | grep -wiF -f "$names" | sed 's/^/commit message: /' || true)"
  hits="$(printf '%s\n%s' "$hits" "$m" | sed '/^$/d')"
fi
if [ -n "$hits" ]; then
  printf '%s\n' "$hits" >&2
  echo "PRIVATE-NAMES: a private repo name is in the lines above; reword it (e.g. \"an app repo\") or, if the repo is public, add it to scripts/private-names-allow.txt" >&2
  exit 1
fi
echo "private-names: clean ($(wc -l < "$names" | tr -d ' ') names)"
