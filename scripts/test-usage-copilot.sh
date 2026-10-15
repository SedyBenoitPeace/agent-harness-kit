#!/usr/bin/env bash
# Fixture test for skills/harness-run/scripts/usage-copilot.sh (M32-004).
# Runs the collector on scripts/fixtures/copilot/ and compares the usage.log
# lines with the totals in scripts/fixtures/README.md. Exit 0 = green.
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$PWD"
U="$ROOT/skills/harness-run/scripts/usage-copilot.sh"
fail() { echo "USAGE-COPILOT TEST FAIL: $*" >&2; exit 1; }

W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
mkdir "$W/repo"; cd "$W/repo"
git init -q -b main . && git config user.email t@t && git config user.name t
echo x > f
git add f
GIT_COMMITTER_DATE="2026-10-01T00:00:00Z" git commit -q -m old --date "2026-10-01T00:00:00Z"
OLD="$(git rev-parse HEAD)"
echo y > f
GIT_COMMITTER_DATE="2026-10-20T00:00:00Z" git commit -qam new --date "2026-10-20T00:00:00Z"
NEW="$(git rev-parse HEAD)"

export COPILOT_HOME="$ROOT/scripts/fixtures/copilot"
export HARNESS_USAGE_REPO=/repo

bash "$U" "$OLD"
want="M1-001 copilot claude-sonnet-5 153000 91600 2700
M1-002 copilot claude-sonnet-5 153000 91600 2700
orchestration copilot claude-sonnet-5 354000 263900 1160 premium=1"
got="$(cat .harness-run/usage.log)"
[ "$got" = "$want" ] || fail "usage.log differs from README totals:
$got"

# Nothing after the start commit: no lines, no file.
rm -rf .harness-run
bash "$U" "$NEW"
[ ! -s .harness-run/usage.log ] || fail "records before the start commit were counted"

# Another repo's sessions are ignored.
HARNESS_USAGE_REPO=/elsewhere bash "$U" "$OLD"
[ ! -s .harness-run/usage.log ] || fail "another repo's sessions were counted"

echo "usage-copilot: ok"
