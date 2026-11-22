#!/usr/bin/env bash
# Proves merge-lane.sh (M61-002): a lane merges with --no-ff; a conflict only
# in FEATURES.json shared_paths is resolved by keeping both sides; any other
# conflict aborts the merge and names the files. Exit 0 = green.
set -euo pipefail
cd "$(dirname "$0")/.."
KIT="$PWD"; ML="$KIT/skills/harness-run/scripts/merge-lane.sh"
fail() { echo "MERGE-LANE TEST FAIL: $*" >&2; exit 1; }
[ -f "$ML" ] || fail "merge-lane.sh missing"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
R="$WORK/repo"; mkdir -p "$R"; g() { git -C "$R" -c user.email=t@t -c user.name=t "$@"; }
g init -q -b main
printf '{"features":[]}\n' > "$R/FEATURES.json"  # default shared_paths: README.md, CHANGELOG.md
printf '# App\n\n## Use\n\n- start\n' > "$R/README.md"
printf '# Changelog\n\n## Unreleased\n\n' > "$R/CHANGELOG.md"
printf 'x = 1\n' > "$R/code.txt"
g add -A; g commit -qm seed
lane() { # id readme-line changelog-line [code-line]
  g checkout -q -b "lane/$1" main
  printf -- '- %s\n' "$2" >> "$R/README.md"; printf -- '- %s\n' "$3" >> "$R/CHANGELOG.md"
  [ -z "${4:-}" ] || printf '%s\n' "$4" > "$R/code.txt"
  printf '%s\n' "$1" > "$R/$1.txt"; g add -A; g commit -qm "$1"; g checkout -q main
}
lane M1-001 "use A" "added A" "x = 2"
lane M1-002 "use B" "added B"
lane M1-003 "use C" "added C" "x = 3"

# 1. clean merge
out="$(cd "$R" && bash "$ML" . M1-001)" || fail "clean lane must merge (exit 0)"
grep -qx 'MERGED: lane/M1-001' <<<"$out" || fail "clean merge must print MERGED"
[ "$(g rev-list --parents -n1 HEAD | wc -w)" -eq 3 ] || fail "merge must be --no-ff (a merge commit)"

# 2. conflict only in shared paths: both sides kept, one merge commit
out="$(cd "$R" && bash "$ML" . M1-002)" || fail "shared-path conflict must resolve (exit 0)"
grep -qx 'UNION: README.md' <<<"$out" || fail "README.md conflict must be resolved by union"
grep -qx 'UNION: CHANGELOG.md' <<<"$out" || fail "CHANGELOG.md conflict must be resolved by union"
for l in '- use A' '- use B'; do grep -qx -- "$l" "$R/README.md" || fail "README must keep both sides ($l)"; done
for l in '- added A' '- added B'; do grep -qx -- "$l" "$R/CHANGELOG.md" || fail "CHANGELOG must keep both sides ($l)"; done
! grep -q '^<<<<<<<\|^>>>>>>>' "$R/README.md" "$R/CHANGELOG.md" || fail "no conflict markers may remain"
[ -f "$R/M1-002.txt" ] || fail "the lane's own files must land"
[ -z "$(g status --porcelain)" ] || fail "tree must be clean after a union merge"

# 3. conflict in a non-shared file: abort, name it, exit 1, tree untouched
head="$(g rev-parse HEAD)"
set +e; out="$(cd "$R" && bash "$ML" . M1-003 2>&1)"; rc=$?; set -e
[ "$rc" -eq 1 ] || fail "a real conflict must exit 1, got $rc"
grep -qx 'CONFLICT: code.txt' <<<"$out" || fail "a real conflict must name the file: $out"
[ "$(g rev-parse HEAD)" = "$head" ] || fail "a real conflict must not commit"
[ -z "$(g status --porcelain)" ] || fail "a real conflict must abort the merge cleanly"

# 4. shared_paths [] opts out: every conflict is real
jq '.shared_paths = []' "$R/FEATURES.json" > "$WORK/f" && mv "$WORK/f" "$R/FEATURES.json"; g commit -qam "no shared"
lane M1-004 "use D" "added D"; lane M1-005 "use E" "added E"
(cd "$R" && bash "$ML" . M1-004 >/dev/null) || fail "M1-004 merges clean"
set +e; (cd "$R" && bash "$ML" . M1-005 >/dev/null 2>&1); rc=$?; set -e
[ "$rc" -eq 1 ] || fail "with shared_paths [] a README conflict is real"

# 5. usage
set +e; (cd "$R" && bash "$ML" . >/dev/null 2>&1); rc=$?; set -e
[ "$rc" -eq 2 ] || fail "missing id must exit 2"
echo "MERGE-LANE TESTS GREEN"
