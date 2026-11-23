#!/usr/bin/env bash
# harness-session: bring the current PR branch up to date with the default
# branch when parallel PRs collide only in the harness files (M67-001).
# Merges origin/<base> (a merge, not a rebase: one resolution, no force push).
# When both sides changed them (conflicting in git or not):
#   FEATURES.json  three-way by key: objects key by key, arrays of objects
#                  with an "id" by id (base branch order, then this branch's
#                  new ids); a value both sides changed differently, or an id
#                  both added differently, is a conflict.
#   PROGRESS.md    by "## " entry: this branch's new entries on top, then the
#                  base branch's, minus entries this branch removed.
# A conflict in a shared_paths file: both sides kept (merge-file --union
# --diff3; without --diff3 git interleaves two blocks line by line).
# Any other conflict aborts the merge. A merge then runs scripts/e2e.sh; red
# undoes it. --push pushes the branch afterwards (a plain push).
# Usage: sync-branch.sh [<base>] [--push]   (base: origin's default branch)
# Prints UP TO DATE: <branch> | SYNCED: <branch> (+ RESOLVED:/UNION: <file>)
# | CONFLICT: <file> [at <json path>] | GATE RED: merge undone.
# Exit 0 synced or up to date · 1 conflict or red gate, branch as before · 2 usage.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
base=""; push=0
for a in "$@"; do
  case "$a" in
    --push) push=1 ;;
    -*) echo "usage: sync-branch.sh [<base>] [--push]" >&2; exit 2 ;;
    *) base="$a" ;;
  esac
done
cd "$(git rev-parse --show-toplevel)"
[ -n "$base" ] || base="$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||')" || true
[ -n "$base" ] || { echo "usage: sync-branch.sh <base> [--push] (origin/HEAD is not set)" >&2; exit 2; }
[ -z "$(git status --porcelain --untracked-files=no)" ] || { echo "sync-branch.sh: commit or stash changes first" >&2; exit 2; }
branch="$(git branch --show-current)"
git fetch -q origin "$base"
head="$(git rev-parse HEAD)"
undo() { git merge --abort 2>/dev/null || git reset -q --hard "$head"; }
stop() { undo; printf 'CONFLICT: %s\n' "$@"; exit 1; }

if git merge-base --is-ancestor "origin/$base" HEAD; then echo "UP TO DATE: $branch"; exit 0; fi
# git overwrites an ignored file the base branch starts tracking, and no undo brings it back
while IFS= read -r f; do
  [ ! -e "$f" ] || { echo "sync-branch.sh: $f is untracked here but tracked on $base; move it away first" >&2; exit 2; }
done < <(git diff --name-only --diff-filter=A HEAD "origin/$base")
mb="$(git merge-base HEAD "origin/$base")"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
both() { ! git diff --quiet "$mb" HEAD -- "$1" && ! git diff --quiet "$mb" "origin/$base" -- "$1"; }
blobs() { # <file>: base/ours/theirs from the commits; an absent file is empty
  git show "$mb:$1" > "$tmp/base" 2>/dev/null || : > "$tmp/base"
  git show "HEAD:$1" > "$tmp/ours" 2>/dev/null || : > "$tmp/ours"
  git show "origin/$base:$1" > "$tmp/theirs" 2>/dev/null || : > "$tmp/theirs"
}
git merge -q --no-commit --no-ff "origin/$base" >/dev/null 2>&1 || true
[ -f "$(git rev-parse --git-path MERGE_HEAD)" ] || stop "(merge did not start)"
shared="$(git show "origin/$base:FEATURES.json" 2>/dev/null | jq -r '(.shared_paths // ["README.md", "CHANGELOG.md"])[]' 2>/dev/null || true)"
real=(); unmerged=()
while IFS= read -r f; do
  unmerged+=("$f")
  [ "$f" = FEATURES.json ] || [ "$f" = PROGRESS.md ] || grep -qxF -- "$f" <<<"$shared" || real+=("$f")
done < <(git diff --name-only --diff-filter=U)
[ "${#real[@]}" -eq 0 ] || stop "${real[@]}"
resolved=()
# FEATURES.json and PROGRESS.md: merged by entry whenever both sides changed
# them, even when git's text merge was clean (two ids added at different lines)
if both FEATURES.json; then
  blobs FEATURES.json
  # shellcheck disable=SC2016 # jq program, not shell
  if ! jq -n --slurpfile b "$tmp/base" --slurpfile o "$tmp/ours" --slurpfile t "$tmp/theirs" '
        def at($k): if type == "object" and has($k) then [.[$k]] else [] end;
        def isids: type == "array" and all(.[]; type == "object" and has("id"));
        def byid($p): reduce .[] as $e ({}; ($e.id | tojson) as $i
          | if has($i) then error("CONFLICT: FEATURES.json at \($p) duplicate id \($i)") else .[$i] = $e end);
        def m($b; $o; $t; $p): # each side wrapped: [value], or [] when absent
          if $o == $t then $o elif $o == $b then $t elif $t == $b then $o
          elif ($b | length) == 0 or ($o | length) == 0 or ($t | length) == 0 then error("CONFLICT: FEATURES.json at \($p)")
          else $b[0] as $B | $o[0] as $O | $t[0] as $T
            | if ($B | type) == "object" and ($O | type) == "object" and ($T | type) == "object" then
                [reduce (($T + $O + $B) | keys_unsorted[]) as $k ({};
                  m($B | at($k); $O | at($k); $T | at($k); "\($p).\($k)") as $r
                  | if $r == [] then . else .[$k] = $r[0] end)]
              elif ($B | isids) and ($O | isids) and ($T | isids) then
                ($B | byid($p)) as $Bi | ($O | byid($p)) as $Oi | ($T | byid($p)) as $Ti
                | [[($T[].id | tojson), ($O[].id | tojson | select(. as $i | $Ti | has($i) | not))]
                  | map(. as $i | m($Bi | at($i); $Oi | at($i); $Ti | at($i); "\($p)[\($i)]")[])]
              else error("CONFLICT: FEATURES.json at \($p)") end
          end;
        m($b; $o; $t; "")[0]' > "$tmp/merged" 2> "$tmp/err"; then
    cat "$tmp/err" >&2; stop "$(grep -o 'CONFLICT: .*' "$tmp/err" | sed 's/^CONFLICT: //' || echo 'FEATURES.json (not valid JSON on a side)')"
  fi
  # ponytail: rewrites in jq's format (what the kit's tools write); keep-format merge if a repo needs it
  jq . "$tmp/theirs" | cmp -s - "$tmp/theirs" || echo "NOTE: FEATURES.json rewritten in jq format"
  cp "$tmp/merged" FEATURES.json; git add FEATURES.json; resolved+=("RESOLVED: FEATURES.json")
fi
if both PROGRESS.md; then
  blobs PROGRESS.md
  [ -s "$tmp/ours" ] && [ -s "$tmp/theirs" ] || stop "PROGRESS.md (deleted on one side)"
  # entries are "## " blocks: this branch's new entries on top, then the base
  # branch's, minus those this branch removed; the preamble from the side that changed it
  if ! awk '
    function trim(s) { while (s ~ /\n\n$/) s = substr(s, 1, length(s) - 1); return s }
    FNR == 1 { f++ }
    /^## / { n[f]++; blk[f, n[f]] = $0 "\n"; next }
    { if (n[f] == 0) pre[f] = pre[f] $0 "\n"; else blk[f, n[f]] = blk[f, n[f]] $0 "\n" }
    END {
      for (k = 1; k <= 3; k++) pre[k] = trim(pre[k])
      if (pre[2] == pre[3] || pre[3] == pre[1]) p = pre[2]
      else if (pre[2] == pre[1]) p = pre[3]
      else exit 1
      for (i = 1; i <= n[1]; i++) inb[trim(blk[1, i])] = 1
      for (i = 1; i <= n[2]; i++) ino[trim(blk[2, i])] = 1
      printf "%s", p; sep = (p == "" ? "" : "\n")
      for (i = 1; i <= n[2]; i++) { b = trim(blk[2, i]); if (!(b in inb) && !(b in seen)) { printf "%s%s", sep, b; sep = "\n"; seen[b] = 1 } }
      for (i = 1; i <= n[3]; i++) { b = trim(blk[3, i]); if ((b in inb) && !(b in ino)) continue
        if (!(b in seen)) { printf "%s%s", sep, b; sep = "\n"; seen[b] = 1 } }
    }' "$tmp/base" "$tmp/ours" "$tmp/theirs" > "$tmp/merged"; then
    stop "PROGRESS.md (both sides changed the text above the first entry)"
  fi
  cp "$tmp/merged" PROGRESS.md; git add PROGRESS.md; resolved+=("RESOLVED: PROGRESS.md")
fi
for f in ${unmerged[@]+"${unmerged[@]}"}; do
  [ "$f" != FEATURES.json ] && [ "$f" != PROGRESS.md ] || continue
  { git show ":2:$f" > "$tmp/ours" 2>/dev/null && git show ":3:$f" > "$tmp/theirs" 2>/dev/null; } || stop "$f (deleted on one side)"
  git show ":1:$f" > "$tmp/base" 2>/dev/null || : > "$tmp/base"
  # exit 0 = merged; >0 counts conflicts (none under --union); <0 (255) = error, e.g. a binary file
  rc=0; git merge-file --union --diff3 "$tmp/ours" "$tmp/base" "$tmp/theirs" 2>/dev/null || rc=$?
  [ "$rc" -eq 0 ] || stop "$f (cannot be merged as text)"
  cp "$tmp/ours" "$f"; git add -- "$f"; resolved+=("UNION: $f")
done
[ -z "$(git diff --name-only --diff-filter=U)" ] || stop "$(git diff --name-only --diff-filter=U)"
git commit -q --no-edit >/dev/null 2>&1 || stop "(commit refused, e.g. by a hook)"
jq empty FEATURES.json 2>/dev/null || { undo; echo "CONFLICT: FEATURES.json (merged file is not valid JSON)"; exit 1; }
if ! gate="$(bash "$here/quiet.sh" sync-gate -- bash scripts/e2e.sh)"; then
  git reset -q --hard "$head"; echo "$gate"; echo "GATE RED: merge undone"; exit 1
fi
echo "SYNCED: $branch"
[ "${#resolved[@]}" -eq 0 ] || printf '%s\n' "${resolved[@]}"
[ "$push" -eq 0 ] || git push -q origin HEAD
