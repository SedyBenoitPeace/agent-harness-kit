#!/usr/bin/env bash
# Fixture test for skills/harness-run/scripts/usage-codex.sh (M32-003).
# Runs the collector on the synthetic Codex sessions in scripts/fixtures/codex/
# and checks the totals listed in scripts/fixtures/README.md. Exit 0 = green.
set -euo pipefail
cd "$(dirname "$0")/.."
UC="$PWD/skills/harness-run/scripts/usage-codex.sh"
FIX="$PWD/scripts/fixtures/codex"
fail() { echo "USAGE-CODEX TEST FAIL: $*" >&2; exit 1; }

W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
mkdir -p "$W/repo" "$W/codexhome/sessions/2026/01/05"
git -C "$W/repo" init -q -b main
GIT_COMMITTER_DATE="2026-01-05T08:00:00Z" GIT_AUTHOR_DATE="2026-01-05T08:00:00Z" \
  git -C "$W/repo" -c user.email=t@t -c user.name=t commit -q --allow-empty -m start
start="$(git -C "$W/repo" rev-parse HEAD)"
REPO="$(cd "$W/repo" && pwd -P)"

# The fixture's working directory is /repo: point it at the temp repo.
for f in "$FIX"/*.jsonl; do
  sed "s#\"/repo\"#\"$REPO\"#g" "$f" > "$W/codexhome/sessions/2026/01/05/$(basename "$f")"
done
# A thread of another repo, and one from before the start commit: both ignored.
sed "s#\"/repo\"#\"/somewhere/else\"#g" "$FIX"/*05.jsonl > "$W/codexhome/sessions/2026/01/05/rollout-x-other.jsonl"
sed "s#\"/repo\"#\"$REPO\"#g; s#2026-01-05T09:50:00#2026-01-04T09:50:00#g" "$FIX"/*05.jsonl > "$W/codexhome/sessions/2026/01/05/rollout-x-old.jsonl"

run() { (cd "$W/repo" && CODEX_HOME="$W/codexhome" bash "$UC" "$@"); }

run "$start" || fail "collector exited non-zero"
log="$W/repo/.harness-run/usage.log"
[ -f "$log" ] || fail "no usage.log written"
want='M1-001 codex gpt-6.1-sol 550000 480000 5500
M1-002 codex gpt-6.1-sol 300000 270000 3000
M1-003 codex gpt-6.1-sol 500000 450000 5000
orchestration codex codex-auto-review 60000 45000 500
orchestration codex gpt-6.1-sol 900000 840000 6000'
[ "$(cat "$log")" = "$want" ] || { diff <(echo "$want") "$log" >&2 || true; fail "usage.log differs from the README totals"; }

# usage.log lines are appended, never rewritten
run "$start"; [ "$(wc -l < "$log" | tr -d ' ')" -eq 10 ] || fail "second run should append 5 more lines"

# no session directory: nothing written, exit 0
rm -rf "$W/repo/.harness-run"
(cd "$W/repo" && CODEX_HOME="$W/none" bash "$UC" "$start") || fail "missing sessions dir must not fail"
[ ! -e "$W/repo/.harness-run/usage.log" ] || fail "nothing to log must write nothing"

# bad invocation: exit 2
rc=0; run >/dev/null 2>&1 || rc=$?; [ "$rc" -eq 2 ] || fail "no start commit: want exit 2, got $rc"

echo "USAGE-CODEX TESTS GREEN"
