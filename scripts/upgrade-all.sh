#!/usr/bin/env bash
# upgrade-all.sh — run upgrade.sh over every repo in a local list and open one
# upgrade PR per repo (M68-001). A tool of this repo, not shipped in the plugin.
#   upgrade-all.sh [--list FILE] [--dry-run] [PATH...] | --add DIR
# PATH... (a repo or a folder of repos, as list lines) runs just those: no list is
# read, needed or prompted for.
# The list: one absolute path per line, # comments and blank lines ignored. A line
# that is a repo is upgraded; any other folder stands for each harnessed repo
# directly inside it (one level, never this kit). --add DIR appends a folder (with
# no list, a terminal is asked for one);
# default .git/info/upgrade-repos (git cannot commit it, so no repo name ever
# enters this public repo). Each repo is upgraded in a temp worktree off
# origin/<default branch>: its own checkout (branch, index, files) is never
# touched; its own harness-upgrade branch is never created or deleted (the temp
# worktree is detached, the push is HEAD:refs/heads/harness-upgrade, never forced).
# An origin harness-upgrade branch: with an open PR it is updated in place; if its
# PR was merged and it is still the PR's head it is stale and deleted first (never
# under --dry-run); otherwise it is the start and a PR is opened from it. Output: one "<path>: <result>" line per repo.
# Exit 0 done (skips are not failures); 1 a repo failed; 2 no list.
set -uo pipefail
KIT="$(cd "$(dirname "$0")/.." && pwd)"
UPGRADE="$KIT/skills/harness-upgrade-structure/scripts/upgrade.sh"
list="$(cd "$KIT" && git rev-parse --git-common-dir)/info/upgrade-repos"; dry=0; addto=""; paths=()
case "$list" in /*) ;; *) list="$KIT/$list" ;; esac
while [ $# -gt 0 ]; do
  case "$1" in
    --list) list="${2:?--list needs a file}"; shift 2 ;;
    --dry-run) dry=1; shift ;;
    --add) addto="${2:?--add needs a folder}"; shift 2 ;;
    -*) echo "usage: upgrade-all.sh [--list FILE] [--dry-run] [PATH...] | --add DIR" >&2; exit 2 ;;
    *) paths+=("$1"); shift ;;
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
if [ "${#paths[@]}" = 0 ] && [ ! -f "$list" ]; then
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
    fi
  }
  trap cleanup EXIT
  # the repo's own top level, not a folder inside some other repo
  if [ ! -d "$repo" ] || [ "$(git -C "$repo" rev-parse --show-prefix 2>/dev/null || echo x)" != "" ]; then
    echo "skipped: not a git repo"; exit 0
  fi
  git -C "$repo" remote get-url origin >/dev/null 2>&1 || { echo "skipped: no origin remote"; exit 0; }
  git -C "$repo" fetch -q --prune origin 2>&1 || { echo "fetch failed" >&2; exit 1; }
  def="$(git -C "$repo" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##' || true)"
  if [ -z "$def" ]; then
    for b in main master; do
      if git -C "$repo" show-ref --verify --quiet "refs/remotes/origin/$b"; then def="$b"; break; fi
    done
  fi
  [ -n "$def" ] || { echo "skipped: no default branch found on origin"; exit 0; }

  # origin's harness-upgrade: open PR = update it; stale (merged, still its head) = delete
  # and start over; anything else = start from it. A local branch of that name is ignored.
  start="origin/$def"; mode=""; prurl=""
  if git -C "$repo" show-ref --verify --quiet refs/remotes/origin/harness-upgrade; then
    prs="$(cd "$repo" && gh pr list --head harness-upgrade --state all --json number,state,url,headRefOid)" \
      || { echo "gh pr list failed" >&2; exit 1; }
    prurl="$(printf '%s' "$prs" | jq -r 'map(select(.state == "OPEN")) | .[0].url // empty')" \
      || { echo "unreadable gh pr list output" >&2; exit 1; }
    tipsha="$(git -C "$repo" rev-parse refs/remotes/origin/harness-upgrade)"
    if [ -n "$prurl" ]; then
      start="origin/harness-upgrade"; mode=open
    elif [ "$(printf '%s' "$prs" | jq -r '.[0] | "\(.state) \(.headRefOid)"')" = "MERGED $tipsha" ]; then
      [ "$dry" = 1 ] || git -C "$repo" push -q origin --delete harness-upgrade 2>&1 \
        || { echo "could not delete the stale origin branch" >&2; exit 1; }
    else
      start="origin/harness-upgrade"; mode=other
    fi
  fi

  wt="$(mktemp -d)"
  git -C "$repo" worktree add -q --detach "$wt/w" "$start" >/dev/null 2>&1 \
    || { echo "worktree add failed" >&2; exit 1; }
  rc=0; out="$(bash "$UPGRADE" "$wt/w" 2>&1)" || rc=$?
  if [ "$rc" = 3 ]; then echo "skipped: no harness"; exit 0; fi
  if [ "$rc" != 0 ]; then echo "skipped: $(printf '%s\n' "$out" | tail -n 1)"; exit 0; fi
  ahead="$(git -C "$wt/w" rev-list --count "origin/$def..HEAD")"
  dirty="$(git -C "$wt/w" status --short)"
  if [ -z "$dirty" ]; then
    if [ "$mode" = open ]; then echo "PR $prurl (already open)"; exit 0; fi
    if [ "$mode" != other ] || [ "$ahead" = 0 ]; then
      if [ "$mode" = other ] && [ "$dry" != 1 ]; then
        git -C "$repo" push -q origin --delete harness-upgrade 2>&1 || { echo "could not delete the empty origin branch" >&2; exit 1; }
      fi
      echo "up to date"; exit 0
    fi
  fi

  changed="$(printf '%s\n' "$out" | grep -c '^CHANGED:' || true)"
  todo="$(printf '%s\n' "$out" | grep -c '^TODO:' || true)"
  if [ "$dry" = 1 ]; then
    if [ "$mode" = open ]; then echo "would update PR $prurl ($changed changed, $todo todo)"
    else echo "would open a PR ($changed changed, $todo todo)"; fi
    exit 0
  fi

  if [ -n "$dirty" ]; then
    git -C "$wt/w" add -A
    git -C "$wt/w" commit -q -m "chore: upgrade harness structure"
    git -C "$wt/w" push -q origin HEAD:refs/heads/harness-upgrade 2>&1 || { echo "push failed" >&2; exit 1; }
  fi
  if [ "$mode" = open ]; then echo "PR $prurl (updated)"; exit 0; fi
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

# line ENTRY: a repo, or a folder of repos
line() {
  local repo="$1" d n
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
}

failed=0
if [ "${#paths[@]}" -gt 0 ]; then
  for p in "${paths[@]}"; do line "$p"; done
else
  while IFS= read -r repo || [ -n "$repo" ]; do
    case "$repo" in ''|'#'*) continue ;; esac
    line "$repo"
  done < "$list"
fi
exit "$failed"
