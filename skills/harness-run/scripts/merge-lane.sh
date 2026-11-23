#!/usr/bin/env bash
# harness-run: merge a finished lane into the current branch (M61-002).
# git merge --no-ff lane/<id>. A conflict only in files the repo lists in
# FEATURES.json "shared_paths" (absent = README.md and CHANGELOG.md, [] =
# none; many features add a few lines each) is resolved by keeping both sides
# (git merge-file --union --diff3: without --diff3 two blocks interleave line by line);
# the full gate then decides. Any other conflict aborts the merge.
# Usage: merge-lane.sh <target> <id>
# Prints MERGED: lane/<id> (+ UNION: <file> per resolved file), or
# CONFLICT: <file> per unresolved file. Exit 0 merged · 1 conflict, merge
# aborted, tree as before · 2 usage.
set -euo pipefail
t="${1:-}"; id="${2:-}"
[ -d "$t" ] && [ -n "$id" ] || { echo "usage: merge-lane.sh <target> <id>" >&2; exit 2; }
cd "$t"
if git merge -q --no-ff "lane/$id" -m "Merge lane/$id" >/dev/null 2>&1; then
  echo "MERGED: lane/$id"; exit 0
fi
shared="$(jq -r '(.shared_paths // ["README.md", "CHANGELOG.md"])[]' FEATURES.json 2>/dev/null || true)"
files=(); while IFS= read -r f; do files+=("$f"); done < <(git diff --name-only --diff-filter=U)  # bash 3.2: no mapfile
[ "${#files[@]}" -gt 0 ] || { git merge --abort 2>/dev/null || true; echo "CONFLICT: (merge failed without conflicted files)"; exit 1; }
real=()
for f in "${files[@]}"; do grep -qxF -- "$f" <<<"$shared" || real+=("$f"); done
if [ "${#real[@]}" -gt 0 ]; then
  git merge --abort
  printf 'CONFLICT: %s\n' "${real[@]}"; exit 1
fi
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
for f in "${files[@]}"; do
  git show ":1:$f" > "$tmp/base" 2>/dev/null || : > "$tmp/base"
  git show ":2:$f" > "$tmp/ours"; git show ":3:$f" > "$tmp/theirs"
  git merge-file --union --diff3 "$tmp/ours" "$tmp/base" "$tmp/theirs" || true
  cp "$tmp/ours" "$f"; git add -- "$f"
done
git commit -q --no-edit
echo "MERGED: lane/$id"; printf 'UNION: %s\n' "${files[@]}"
