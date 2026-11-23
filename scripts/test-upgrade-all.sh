#!/usr/bin/env bash
# Proves upgrade-all.sh (M68-001): one run upgrades every listed repo through a
# temp worktree and a PR, never touching the repos' own checkouts. All repos
# are throwaway, each with a bare origin; gh is a stub on PATH. Exit 0 = green.
set -euo pipefail
cd "$(dirname "$0")/.."
UA="$PWD/scripts/upgrade-all.sh"; UPGRADE="$PWD/skills/harness-upgrade-structure/scripts/upgrade.sh"
fail() { echo "UPGRADE-ALL TEST FAIL: $*" >&2; exit 1; }
[ -f "$UA" ] || fail "upgrade-all.sh missing"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t

# stub gh: records its arguments and the --body-file text, prints a URL
mkdir "$WORK/bin"
cat > "$WORK/bin/gh" <<'STUB'
#!/usr/bin/env bash
echo "$*" >> "$GH_LOG"
while [ $# -gt 0 ]; do [ "$1" = --body-file ] && cp "$2" "$GH_LOG.body"; shift; done
echo "https://example.test/acme/pr/7"
STUB
chmod +x "$WORK/bin/gh"
export GH_LOG="$WORK/gh.log"; : > "$GH_LOG"
export PATH="$WORK/bin:$PATH"

# mkrepo <name>: an outdated harnessed repo on main with a bare origin
mkrepo() {
  local r="$WORK/$1"
  git init -q --bare -b main "$WORK/$1.git"; git clone -q "$WORK/$1.git" "$r" 2>/dev/null
  git -C "$r" checkout -q -b main
  mkdir -p "$r/docs/agents" "$r/scripts"
  printf '{ "milestones": { "1": "Core" }, "features": [ { "id": "M1-001", "milestone": 1, "title": "a", "status": "failing", "verify": "x" } ] }\n' > "$r/FEATURES.json"
  printf '# PROGRESS\n\n## 2026-01-01 -- session 1\n- Setup.\n' > "$r/PROGRESS.md"
  printf '# AGENTS.md\n\nSee docs/agents/harness-protocol.md.\n' > "$r/AGENTS.md"
  printf 'old protocol\n' > "$r/docs/agents/harness-protocol.md"
  printf '#!/usr/bin/env bash\nset -e\ntrue\necho "GATE GREEN"\n' > "$r/scripts/e2e.sh"
  git -C "$r" add -A; git -C "$r" commit -qm seed; git -C "$r" push -q origin main 2>/dev/null
  git -C "$r" remote set-head origin main
}
remote_has() { git -C "$WORK/$1.git" show-ref --verify --quiet "refs/heads/harness-upgrade"; }

mkrepo alpha; mkrepo beta; mkrepo gamma
# gamma is already upgraded and merged: upgrade.sh finds nothing to change
bash "$UPGRADE" "$WORK/gamma" >/dev/null 2>&1
git -C "$WORK/gamma" add -A; git -C "$WORK/gamma" commit -qm upgraded
git -C "$WORK/gamma" checkout -q main; git -C "$WORK/gamma" merge -q --ff-only harness-upgrade
git -C "$WORK/gamma" branch -q -d harness-upgrade; git -C "$WORK/gamma" push -q origin main 2>/dev/null
# alpha: dirty checkout on a feature branch
git -C "$WORK/alpha" checkout -q -b feat-x; echo wip > "$WORK/alpha/wip.txt"
printf 'changed\n' >> "$WORK/alpha/PROGRESS.md"
alpha_before="$(git -C "$WORK/alpha" status --short; git -C "$WORK/alpha" worktree list; git -C "$WORK/alpha" branch --show-current)"

LIST="$WORK/list"
run() { bash "$UA" --list "$LIST" "$@" 2>&1; }

echo "-- 1 outdated repo, dirty checkout: PR opened, checkout untouched"
printf '# a comment\n\n%s\n' "$WORK/alpha" > "$LIST"
out="$(run)" || fail "1: exit $?: $out"
echo "$out" | grep -qxF "$WORK/alpha: PR https://example.test/acme/pr/7" || fail "1: no PR line: $out"
remote_has alpha || fail "1: origin has no harness-upgrade"
[ "$(git -C "$WORK/alpha.git" rev-list --count main..harness-upgrade)" = 1 ] || fail "1: expected one commit"
[ "$(git -C "$WORK/alpha.git" log -1 --format=%s harness-upgrade)" = "chore: upgrade harness structure" ] || fail "1: commit subject"
[ "$alpha_before" = "$(git -C "$WORK/alpha" status --short; git -C "$WORK/alpha" worktree list; git -C "$WORK/alpha" branch --show-current)" ] \
  || fail "1: checkout changed"
grep -q '^- \[ \] ' "$GH_LOG.body" || fail "1: PR body has no checklist"
grep -q '^CHANGED: ' "$GH_LOG.body" || fail "1: PR body has no CHANGED lines"
grep -q '^- \[ \] .*scripts/e2e.sh' "$GH_LOG.body" || fail "1: the e2e TODO must be a checklist line"
git -C "$WORK/alpha" worktree list | grep -q 'harness-upgrade' && fail "1: temp worktree left"
git -C "$WORK/alpha" show-ref --verify --quiet refs/heads/harness-upgrade && fail "1: local branch left (the PR head is on origin)"
git -C "$WORK/alpha" worktree prune

echo "-- 2 same repo again: skipped"
out="$(run)" || fail "2: exit $?"
echo "$out" | grep -qxF "$WORK/alpha: skipped: harness-upgrade branch exists" || fail "2: $out"

echo "-- 3 up-to-date repo: nothing left behind"
printf '%s\n' "$WORK/gamma" > "$LIST"
out="$(run)" || fail "3: exit $?: $out"
echo "$out" | grep -qxF "$WORK/gamma: up to date" || fail "3: $out"
remote_has gamma && fail "3: remote branch left"
git -C "$WORK/gamma" show-ref --verify --quiet refs/heads/harness-upgrade && fail "3: local branch left"

echo "-- 4 no harness / not a repo between two good repos"
mkdir "$WORK/plain"
printf '%s\n' "$WORK/beta" "$WORK/plain" "$WORK/missing" "$WORK/gamma" > "$LIST"
out="$(run)" || fail "4: exit $?: $out"
echo "$out" | grep -qxF "$WORK/plain: skipped: no harnessed repos inside" || fail "4: plain: $out"
echo "$out" | grep -qxF "$WORK/missing: skipped: not a git repo" || fail "4: missing: $out"
echo "$out" | grep -q "^$WORK/beta: PR " || fail "4: beta before: $out"
echo "$out" | grep -qxF "$WORK/gamma: up to date" || fail "4: gamma after: $out"
# a repo that really has no harness: needs an origin that works
git init -q --bare -b main "$WORK/nh.git"; git clone -q "$WORK/nh.git" "$WORK/nh2" 2>/dev/null
git -C "$WORK/nh2" checkout -q -b main; echo x > "$WORK/nh2/f"; git -C "$WORK/nh2" add f; git -C "$WORK/nh2" commit -qm x
git -C "$WORK/nh2" push -q origin main 2>/dev/null; git -C "$WORK/nh2" remote set-head origin main
printf '%s\n' "$WORK/nh2" > "$LIST"
out="$(run)" || fail "4: nh exit $?: $out"
echo "$out" | grep -qxF "$WORK/nh2: skipped: no harness" || fail "4: no harness: $out"
git -C "$WORK/nh2" show-ref --verify --quiet refs/heads/harness-upgrade && fail "4: branch left in no-harness repo"

echo "-- 5 --dry-run: nothing pushed, nothing left"
mkrepo delta; : > "$GH_LOG"; printf '%s\n' "$WORK/delta" > "$LIST"
out="$(run --dry-run)" || fail "5: exit $?: $out"
echo "$out" | grep -q "^$WORK/delta: would open a PR (" || fail "5: $out"
remote_has delta && fail "5: pushed"
git -C "$WORK/delta" show-ref --verify --quiet refs/heads/harness-upgrade && fail "5: local branch left"
[ ! -s "$GH_LOG" ] || fail "5: gh was called"
[ "$(git -C "$WORK/delta" worktree list | wc -l | tr -d ' ')" = 1 ] || fail "5: worktree left"

echo "-- 6 no list: exit 2 naming the path"
rc=0; out="$(bash "$UA" --list "$WORK/nolist" 2>&1)" || rc=$?
[ "$rc" = 2 ] || fail "6: exit $rc"
echo "$out" | grep -qF "$WORK/nolist" || fail "6: message must name the path: $out"

echo "-- 7 folder line: only its harnessed repos run"
mkdir "$WORK/fold7"; mkrepo "fold7/eps repo"; mkdir "$WORK/fold7/sub"
git init -q "$WORK/fold7/unharnessed"
printf '%s\n' "$WORK/fold7" > "$LIST"
out="$(run --dry-run)" || fail "7: exit $?: $out"
echo "$out" | grep -q "^$WORK/fold7/eps repo: would open a PR (" || fail "7: harnessed repo missing: $out"
[ "$(printf '%s\n' "$out" | wc -l | tr -d ' ')" = 1 ] || fail "7: want exactly one line: $out"

echo "-- 8 empty folder: skipped"
mkdir "$WORK/fold8"; printf '%s\n' "$WORK/fold8" > "$LIST"
out="$(run --dry-run)" || fail "8: exit $?: $out"
[ "$out" = "$WORK/fold8: skipped: no harnessed repos inside" ] || fail "8: $out"

echo "-- 9 --add: absolute, once; a missing folder is refused"
rm -f "$LIST"; mkdir "$WORK/fold9"
out="$(cd "$WORK" && bash "$UA" --list "$LIST" --add fold9 2>&1)" || fail "9: add exit $?: $out"
[ "$out" = "added: $(cd "$WORK/fold9" && pwd)" ] || fail "9: $out"
bash "$UA" --list "$LIST" --add "$WORK/fold9" >/dev/null 2>&1 || fail "9: second add"
[ "$(cat "$LIST")" = "$(cd "$WORK/fold9" && pwd)" ] || fail "9: list must hold it once: $(cat "$LIST")"
rc=0; bash "$UA" --list "$LIST" --add "$WORK/nope" >/dev/null 2>&1 || rc=$?
[ "$rc" != 0 ] || fail "9: a missing folder was accepted"
[ "$(wc -l < "$LIST" | tr -d ' ')" = 1 ] || fail "9: list changed by a refused add"

echo "-- 10 the kit's own repo is never listed (a copy of the script inside a fixture kit)"
mkdir "$WORK/fold10"; mkrepo fold10/kit; mkrepo fold10/other
mkdir -p "$WORK/fold10/kit/scripts"; cp "$UA" "$WORK/fold10/kit/scripts/"; ln -s "$PWD/skills" "$WORK/fold10/kit/skills"; ln -s "$PWD/agents" "$WORK/fold10/kit/agents"
printf '%s\n' "$WORK/fold10" > "$LIST"
out="$(bash "$WORK/fold10/kit/scripts/upgrade-all.sh" --list "$LIST" --dry-run 2>&1)" || fail "10: exit $?: $out"
echo "$out" | grep -q "^$WORK/fold10/other: would open a PR" || fail "10: other missing: $out"
echo "$out" | grep -qF "fold10/kit" && fail "10: the kit was listed: $out"

echo "UPGRADE-ALL TEST OK"
