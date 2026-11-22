#!/usr/bin/env bash
# shellcheck disable=SC2015 # a && b || fail asserts
# Fixture tests for scripts/check-private-names.sh (M64-001). Exit 0 = green.
set -euo pipefail
cd "$(dirname "$0")/.."
CHK="$PWD/scripts/check-private-names.sh"
fail() { echo "PRIVATE-NAMES TEST FAIL: $*" >&2; exit 1; }
t() { echo "-- $1"; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
R="$W/repo"; mkdir -p "$R/scripts"; git -C "$R" init -q -b main
printf 'secret-app\nother-thing\nshared-template\n' > "$W/list"
printf 'shared-template\n' > "$R/scripts/private-names-allow.txt"
printf '# Notes\nA run of the shared-template repo.\nsecret-apps is a different word.\n' > "$R/NOTES.md"
git -C "$R" add -A

t "M64-001.1 a private repo name in a tracked file or a text fails the check @critical"
rc=0; out="$(cd "$R" && bash "$CHK" --list "$W/list" 2>&1)" || rc=$?
[ "$rc" -eq 0 ] || fail "M64-001.1: allowed and partial-word names must pass: $out"
printf 'Ran it on secret-app today.\n' >> "$R/NOTES.md"; git -C "$R" add -A
rc=0; out="$(cd "$R" && bash "$CHK" --list "$W/list" 2>&1)" || rc=$?
[ "$rc" -eq 1 ] && grep -q 'NOTES.md:4' <<< "$out" || fail "M64-001.1: a tracked file naming a private repo must fail with file:line: $out"
printf 'PR body naming Other-Thing.\n' > "$W/body.md"
rc=0; out="$(cd "$R" && bash "$CHK" --list "$W/list" "$W/body.md" 2>&1)" || rc=$?
[ "$rc" -eq 1 ] && grep -q 'body.md:1' <<< "$out" || fail "M64-001.1: a text file (PR body) naming a private repo must fail, case-insensitive: $out"
rc=0; out="$(cd "$R" && bash "$CHK" --list "$W/missing" 2>&1)" || rc=$?
[ "$rc" -eq 0 ] && grep -q 'skipped' <<< "$out" || fail "M64-001.1: no list (CI) must skip, not fail: $out"

t "M64-001.2 ci-local refreshes the list and checks commit messages before a push"
grep -q 'refresh-private-names.sh' scripts/ci-local.sh || fail "M64-001.2: ci-local.sh must refresh the private-name list"
grep -q 'check-private-names.sh' scripts/ci-local.sh || fail "M64-001.2: ci-local.sh must run the check"
grep -q 'gh repo list' scripts/refresh-private-names.sh && grep -q 'private' scripts/refresh-private-names.sh || fail "M64-001.2: refresh must list private repos with gh"
rc=0; out="$(cd "$R" && git -c user.email=t@t -c user.name=t commit -qm 'fix secret-app crash' && bash "$CHK" --list "$W/list" --messages HEAD~0 2>&1)" || rc=$?
[ "$rc" -eq 1 ] && grep -q 'commit' <<< "$out" || fail "M64-001.2: a commit message naming a private repo must fail: $out"
echo "PRIVATE-NAMES TESTS GREEN"
