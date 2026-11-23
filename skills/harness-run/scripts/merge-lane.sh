#!/usr/bin/env bash
# harness-run: merge a finished lane into the current branch (M61-002).
# git merge --no-ff lane/<id>. A conflict only in files the repo lists in
# FEATURES.json "shared_paths" (absent = README.md and CHANGELOG.md, [] =
# none; many features add a few lines each) is resolved by keeping both sides
# (git merge-file --union --diff3: without --diff3 two blocks interleave line by line);
# the full gate then decides. Any other conflict aborts the merge.
# Usage: merge-lane.sh <target> <id> [--into-lane]
# Prints MERGED: lane/<id> (+ UNION: <file> per resolved file), or
# CONFLICT: <file> per unresolved file. Exit 0 merged · 1 conflict, merge
# aborted, tree as before · 2 usage.
# --into-lane (M69-002, after a CONFLICT): merges the current branch into
# lane/<id> inside the lane's worktree instead, so the lane, not the run,
# resolves it (lanes share files by default, M69-001). Clean, or conflicts
# only in shared_paths → committed there, SYNCED: lane/<id>, exit 0.
# Otherwise the merge stays in progress in the lane (shared_paths already
# resolved): RESOLVE: <file> per file and one BRIEF: line for the lane's
# builder, exit 1.
set -euo pipefail
t="${1:-}"; id="${2:-}"; into="${3:-}"
{ [ -d "$t" ] && [ -n "$id" ] && { [ -z "$into" ] || [ "$into" = --into-lane ]; }; } \
  || { echo "usage: merge-lane.sh <target> <id> [--into-lane]" >&2; exit 2; }
cd "$t"
src="lane/$id" msg="Merge lane/$id" ok="MERGED: lane/$id"
if [ -n "$into" ]; then
  cur="$(git rev-parse --abbrev-ref HEAD)"
  lane="$(git worktree list --porcelain | awk -v b="refs/heads/lane/$id" '/^worktree /{w=substr($0,10)} $0=="branch " b {print w}')"
  [ -n "$lane" ] || { echo "merge-lane: no worktree has lane/$id checked out" >&2; exit 2; }
  cd "$lane"  # a lane never edits FEATURES.json, so the merge brings the run's shared_paths
  src="$cur" msg="Merge $cur into lane/$id" ok="SYNCED: lane/$id"
fi
if git merge -q --no-ff "$src" -m "$msg" >/dev/null 2>&1; then
  echo "$ok"; exit 0
fi
shared="$(jq -r '(.shared_paths // ["README.md", "CHANGELOG.md"])[]' FEATURES.json 2>/dev/null || true)"
files=(); while IFS= read -r f; do files+=("$f"); done < <(git diff --name-only --diff-filter=U)  # bash 3.2: no mapfile
[ "${#files[@]}" -gt 0 ] || { git merge --abort 2>/dev/null || true; echo "CONFLICT: (merge failed without conflicted files)"; exit 1; }
real=() union=()
for f in "${files[@]}"; do if grep -qxF -- "$f" <<<"$shared"; then union+=("$f"); else real+=("$f"); fi; done
if [ "${#real[@]}" -gt 0 ] && [ -z "$into" ]; then
  git merge --abort
  printf 'CONFLICT: %s\n' "${real[@]}"; exit 1
fi
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
for f in "${union[@]+"${union[@]}"}"; do
  git show ":1:$f" > "$tmp/base" 2>/dev/null || : > "$tmp/base"
  git show ":2:$f" > "$tmp/ours"; git show ":3:$f" > "$tmp/theirs"
  git merge-file --union --diff3 "$tmp/ours" "$tmp/base" "$tmp/theirs" || true
  cp "$tmp/ours" "$f"; git add -- "$f"
done
if [ "${#real[@]}" -gt 0 ]; then
  printf 'RESOLVE: %s\n' "${real[@]}"
  echo "BRIEF: A merge of $cur into lane/$id is in progress in $PWD. Resolve each RESOLVE file keeping both features' behaviour (never drop the other side's change), run the gate, commit the merge in the lane, end with the SESSION line."
  exit 1
fi
git commit -q --no-edit
echo "$ok"; printf 'UNION: %s\n' "${union[@]}"
