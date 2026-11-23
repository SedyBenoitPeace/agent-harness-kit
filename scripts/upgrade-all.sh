#!/usr/bin/env bash
# upgrade-all.sh — run upgrade.sh over every repo in a local list and open one
# upgrade PR per repo (M68-001). A tool of this repo, not shipped in the plugin.
#   upgrade-all.sh [--list FILE] [--dry-run] | --add DIR
# The list: one absolute path per line, # comments and blank lines ignored. A line
# that is a repo is upgraded; any other folder stands for each harnessed repo
# directly inside it (one level, never this kit). --add DIR appends a folder (with
# no list, a terminal is asked for one);
# default .git/info/upgrade-repos (git cannot commit it, so no repo name ever
# enters this public repo). Each repo is upgraded in a temp worktree off
# origin/<default branch>: its own checkout (branch, index, files) is never
# touched. Output: one "<path>: <result>" line per repo.
# Exit 0 done (skips are not failures); 1 a repo failed; 2 no list.
set -uo pipefail
KIT="$(cd "$(dirname "$0")/.." && pwd)"
UPGRADE="$KIT/skills/harness-upgrade-structure/scripts/upgrade.sh"
list="$(cd "$KIT" && git rev-parse --git-common-dir)/info/upgrade-repos"; dry=0; addto=""
case "$list" in /*) ;; *) list="$KIT/$list" ;; esac
while [ $# -gt 0 ]; do
  case "$1" in
    --list) list="${2:?--list needs a file}"; shift 2 ;;
    --dry-run) dry=1; shift ;;
    --add) addto="${2:?--add needs a folder}"; shift 2 ;;
    *) echo "usage: upgrade-all.sh [--list FILE] [--dry-run] | --add DIR" >&2; exit 2 ;;
  esac
done

# add DIR: append its absolute path to the list once; the prompt uses it too
add() {
  local d="${1/#\~\//$HOME/}"
  [ -d "$d" ] || { echo "no such folder: $1" >&2; return 1; }
  d="$(cd "$d" && pwd)"
  grep -qxF "$d" "$list" 2>/dev/null || { mkdir -p "$(dirname "$list")"; printf '%s\n' "$d" >> "$list"; }
  echo "added: $d"
}
if [ -n "$addto" ]; then add "$addto"; exit $?; fi
if [ ! -f "$list" ]; then
  if [ -t 0 ]; then
    read -r -p "Folder that holds your repos: " ans
    [ -n "$ans" ] && add "$ans" || exit 2
  else
    echo "no repo list: create $list with one absolute path per line, or run with --add <folder>" >&2
    exit 2
  fi
fi

# one repo, in a subshell so its trap removes the worktree on every path.
# Prints one result line; a non-zero exit is an unexpected failure.
one() (
  set -e
  repo="$1"; wt=""
  # shellcheck disable=SC2329 # runs from the EXIT trap
  cleanup() {
    if [ -n "$wt" ]; then
      git -C "$repo" worktree remove --force "$wt/w" >/dev/null 2>&1 || true
      rm -rf "$wt"; git -C "$repo" worktree prune
      # the PR's head is origin's branch; a local one would block the next run
      git -C "$repo" branch -q -D harness-upgrade >/dev/null 2>&1 || true
    fi
  }
  trap cleanup EXIT
  # the repo's own top level, not a folder inside some other repo
  if [ ! -d "$repo" ] || [ "$(git -C "$repo" rev-parse --show-prefix 2>/dev/null || echo x)" != "" ]; then
    echo "skipped: not a git repo"; exit 0
  fi
  git -C "$repo" remote get-url origin >/dev/null 2>&1 || { echo "skipped: no origin remote"; exit 0; }
  git -C "$repo" fetch -q --prune origin 2>&1 || { echo "fetch failed" >&2; exit 1; }
  if git -C "$repo" show-ref --verify --quiet refs/heads/harness-upgrade \
    || git -C "$repo" show-ref --verify --quiet refs/remotes/origin/harness-upgrade; then
    echo "skipped: harness-upgrade branch exists"; exit 0
  fi
  def="$(git -C "$repo" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##' || true)"
  if [ -z "$def" ]; then
    for b in main master; do
      if git -C "$repo" show-ref --verify --quiet "refs/remotes/origin/$b"; then def="$b"; break; fi
    done
  fi
  [ -n "$def" ] || { echo "skipped: no default branch found on origin"; exit 0; }

  wt="$(mktemp -d)"
  git -C "$repo" worktree add -q --no-track -b harness-upgrade "$wt/w" "origin/$def" >/dev/null 2>&1 \
    || { echo "worktree add failed" >&2; exit 1; }
  rc=0; out="$(bash "$UPGRADE" "$wt/w" 2>&1)" || rc=$?
  if [ "$rc" = 3 ]; then echo "skipped: no harness"; exit 0; fi
  if [ "$rc" != 0 ]; then echo "skipped: $(printf '%s\n' "$out" | tail -n 1)"; exit 0; fi
  if [ -z "$(git -C "$wt/w" status --short)" ]; then echo "up to date"; exit 0; fi

  changed="$(printf '%s\n' "$out" | grep -c '^CHANGED:' || true)"
  todo="$(printf '%s\n' "$out" | grep -c '^TODO:' || true)"
  if [ "$dry" = 1 ]; then echo "would open a PR ($changed changed, $todo todo)"; exit 0; fi

  git -C "$wt/w" add -A
  git -C "$wt/w" commit -q -m "chore: upgrade harness structure"
  git -C "$wt/w" push -q origin harness-upgrade 2>&1 || { echo "push failed" >&2; exit 1; }
  {
    echo "Harness structure upgrade (upgrade-all.sh)."; echo
    printf '%s\n' "$out" | grep -E '^(CHANGED|UPGRADE-NOTE):' || true
    if [ "$todo" != 0 ]; then
      echo; echo "Left for a person or an agent session:"
      printf '%s\n' "$out" | grep '^TODO:' | sed 's/^TODO: */- [ ] /'
    fi
  } > "$wt/body.md"
  url="$(cd "$wt/w" && gh pr create --base "$def" --head harness-upgrade \
    --title "chore: upgrade harness structure" --body-file "$wt/body.md" | tail -n 1)" \
    || { echo "gh pr create failed (branch harness-upgrade is pushed)" >&2; exit 1; }
  echo "PR $url"
)

# top DIR: DIR is a git repo's own top level
top() { [ -d "$1" ] && [ -z "$(git -C "$1" rev-parse --show-prefix 2>/dev/null || echo x)" ]; }
# report PATH: run one repo, print its result line, remember a failure
report() {
  local res rc; res="$(one "$1" 2>&1 </dev/null)"; rc=$?
  if [ "$rc" = 0 ]; then echo "$1: $res"; else echo "$1: failed: $res"; failed=1; fi
}

failed=0
while IFS= read -r repo || [ -n "$repo" ]; do
  case "$repo" in ''|'#'*) continue ;; esac
  if [ -d "$repo" ] && ! top "$repo"; then
    n=0
    for d in "$repo"/*/; do
      d="${d%/}"
      if top "$d" && [ -f "$d/FEATURES.json" ] && [ -f "$d/PROGRESS.md" ] && ! [ "$d" -ef "$KIT" ]; then
        n=$((n + 1)); report "$d"
      fi
    done
    [ "$n" -gt 0 ] || echo "$repo: skipped: no harnessed repos inside"
  else
    report "$repo"
  fi
done < "$list"
exit "$failed"
