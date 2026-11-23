#!/usr/bin/env bash
# Proves sync-branch.sh (M67-001): two feature PRs built in parallel off the
# same base, each the session-loop way (FEATURES.json entry appended and
# flipped, PROGRESS.md entry on top), both merge with zero human edits; a real
# conflict or a red gate leaves the branch as it was. Exit 0 = green.
# Each t "<check id> …" line is the one test for that check (check-coverage.sh).
set -euo pipefail
cd "$(dirname "$0")/.."
KIT="$PWD"; SB="$KIT/skills/harness-session/scripts/sync-branch.sh"
fail() { echo "SYNC-BRANCH TEST FAIL: $*" >&2; exit 1; }
t() { echo "-- $1"; }
[ -f "$SB" ] || fail "sync-branch.sh missing"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
O="$WORK/origin.git"; R="$WORK/repo"
git init -q --bare -b main "$O"; git clone -q "$O" "$R" 2>/dev/null
g() { git -C "$R" "$@"; }
g checkout -q -b main
mkdir -p "$R/scripts"
jq -n '{_instructions: "x", milestones: {"0": "Base"}, features: [
  {id: "M0-001", milestone: 0, title: "Seed", status: "passing", notes: ""}]}' > "$R/FEATURES.json"
printf '# PROGRESS\n\nNewest-first.\n\n## 2026-11-22 -- session 1 (M0-001)\n\n- Done: M0-001.\n- Gate: GREEN.\n' > "$R/PROGRESS.md"
printf 'x = 1\n' > "$R/code.txt"
printf '#!/usr/bin/env bash\njq empty FEATURES.json && [ ! -f RED ]\n' > "$R/scripts/e2e.sh"
g add -A; g commit -qm seed; g push -q origin main 2>/dev/null
g remote set-head origin main

# feat <branch> <id> <milestone> [file content]: one harness session on its own branch off main
feat() {
  g checkout -q -b "$1" main
  jq --arg id "$2" --argjson m "$3" '.milestones[$m|tostring] = "M\($m)"
    | .features += [{id: $id, milestone: $m, title: "Build \($id)", status: "failing", notes: ""}]
    | (.features[] | select(.id == $id) | .status) = "passing"' "$R/FEATURES.json" > "$WORK/f"
  mv "$WORK/f" "$R/FEATURES.json"
  { sed -n '1,4p' "$R/PROGRESS.md"
    printf '## 2026-11-23 -- session 2 (%s)\n\n- Branch: %s\n- Done: %s.\n- Gate: GREEN.\n\n' "$2" "$1" "$2"
    sed -n '5,$p' "$R/PROGRESS.md"; } > "$WORK/p"; mv "$WORK/p" "$R/PROGRESS.md"
  printf '%s\n' "${4:-$2}" > "$R/$2.txt"
  g add -A; g commit -qm "$2"; g checkout -q main
}
# land <branch>: what the GitHub merge button does (fails on any conflict)
land() { g checkout -q main && g merge -q --no-ff --no-edit "$1" && g push -q origin main 2>/dev/null; }
sync() { (cd "$R" && g checkout -q "$1" && bash "$SB" "${@:2}" 2>&1); }

t "M67-001.1 two parallel feature PRs both merge @critical"
feat a M1-001 1; feat b M2-001 2
land a
! g merge-tree --write-tree main b >/dev/null 2>&1 || fail "fixture: b must conflict with main before the sync"
out="$(sync b --push)" || fail "sync must resolve the harness files (exit 0): $out"
grep -qx 'RESOLVED: FEATURES.json' <<<"$out" || fail "must report FEATURES.json resolved: $out"
grep -qx 'RESOLVED: PROGRESS.md' <<<"$out" || fail "must report PROGRESS.md merged: $out"
[ "$(jq -c '[.features[] | [.id, .status]]' "$R/FEATURES.json")" = '[["M0-001","passing"],["M1-001","passing"],["M2-001","passing"]]' ] \
  || fail "FEATURES.json must hold both entries, main's first, both passing: $(jq -c '.features' "$R/FEATURES.json")"
[ "$(jq -c '.milestones | keys' "$R/FEATURES.json")" = '["0","1","2"]' ] || fail "both milestones kept"
cat > "$WORK/want" <<'P'
# PROGRESS

Newest-first.

## 2026-11-23 -- session 2 (M2-001)

- Branch: b
- Done: M2-001.
- Gate: GREEN.

## 2026-11-23 -- session 2 (M1-001)

- Branch: a
- Done: M1-001.
- Gate: GREEN.

## 2026-11-22 -- session 1 (M0-001)

- Done: M0-001.
- Gate: GREEN.
P
diff "$WORK/want" "$R/PROGRESS.md" >&2 || fail "PROGRESS.md must hold every entry whole, the branch's (newest) on top"
! grep -q '^<<<<<<<\|^>>>>>>>\|^|||||||' "$R/PROGRESS.md" "$R/FEATURES.json" || fail "no conflict markers"
[ -z "$(g status --porcelain)" ] || fail "tree must be clean"
[ "$(git -C "$O" rev-parse b)" = "$(g rev-parse HEAD)" ] || fail "--push must push the synced branch"
out="$(sync b)" || fail "an up-to-date branch exits 0"
grep -qx 'UP TO DATE: b' <<<"$out" || fail "must say up to date: $out"
land b || fail "the synced branch must merge into main with no conflict"
# main archives a feature and trims the oldest log entry while a PR adds its own
feat h2 M2-002 2
g checkout -q -b h1 main
jq 'del(.features[] | select(.id == "M0-001"))' "$R/FEATURES.json" > "$WORK/f"; mv "$WORK/f" "$R/FEATURES.json"
sed '/^## 2026-11-22/,$d' "$R/PROGRESS.md" > "$WORK/p"; mv "$WORK/p" "$R/PROGRESS.md"; g commit -qam archive; g checkout -q main
land h1
out="$(sync h2)" || fail "archive on main + a new feature must sync: $out"
[ "$(jq -c '[.features[].id]' "$R/FEATURES.json")" = '["M1-001","M2-001","M2-002"]' ] || fail "an archived entry must stay archived: $(jq -c '[.features[].id]' "$R/FEATURES.json")"
[ "$(grep '^## ' "$R/PROGRESS.md" | sed 's/.*(//')" = "$(printf 'M2-002)\nM2-001)\nM1-001)')" ] || fail "trimmed entry must stay trimmed: $(cat "$R/PROGRESS.md")"
! grep -q 'M0-001' "$R/PROGRESS.md" || fail "no piece of the trimmed entry may come back"
land h2
# the branch archives a feature and trims its log entry while main adds one
feat i1 M2-003 2
g checkout -q -b i2 main
jq 'del(.features[] | select(.id == "M1-001"))' "$R/FEATURES.json" > "$WORK/f"; mv "$WORK/f" "$R/FEATURES.json"
awk '/^## .*\(M1-001\)/ { skip = 1; next } /^## / { skip = 0 } !skip' "$R/PROGRESS.md" > "$WORK/p"; mv "$WORK/p" "$R/PROGRESS.md"
g commit -qam archive; g checkout -q main
land i1
out="$(sync i2)" || fail "archive on the branch + a new feature on main must sync: $out"
[ "$(jq -c '[.features[].id]' "$R/FEATURES.json")" = '["M2-001","M2-002","M2-003"]' ] || fail "the branch's archive must hold: $(jq -c '[.features[].id]' "$R/FEATURES.json")"
! grep -q '(M1-001)' "$R/PROGRESS.md" || fail "the branch's trimmed entry must stay trimmed"
grep -q '(M2-003)' "$R/PROGRESS.md" || fail "main's new entry must be kept"
land i2

t "M67-001.2 a real conflict stops it @critical"
check_stop() { # <branch> <expected line regex>
  head="$(g rev-parse "$1")"
  set +e; out="$(sync "$1")"; rc=$?; set -e
  [ "$rc" -eq 1 ] || fail "$1: a real conflict must exit 1, got $rc: $out"
  grep -qE "$2" <<<"$out" || fail "$1: must name the conflict ($2): $out"
  [ "$(g rev-parse HEAD)" = "$head" ] || fail "$1: HEAD must be as before"
  [ -z "$(g status --porcelain)" ] || fail "$1: tree must be as before"
}
feat c1 M3-001 3 "same"; feat c2 M3-002 3 "same"
g checkout -q c1; printf 'x = 2\n' > "$R/code.txt"; g commit -qam code
g checkout -q c2; printf 'x = 3\n' > "$R/code.txt"; g commit -qam code
land c1
check_stop c2 '^CONFLICT: code\.txt$'
feat d1 M4-001 4; g checkout -q d1; jq '(.features[-1].title) = "One"' "$R/FEATURES.json" > "$WORK/f"; mv "$WORK/f" "$R/FEATURES.json"; g commit -qam t
feat d2 M4-001 4; g checkout -q d2; jq '(.features[-1].title) = "Two"' "$R/FEATURES.json" > "$WORK/f"; mv "$WORK/f" "$R/FEATURES.json"; g commit -qam t
land d1
check_stop d2 '^CONFLICT: FEATURES\.json at .*M4-001'
feat e1 M5-001 5; g checkout -q e1; jq '(.features[0].notes) = "one"' "$R/FEATURES.json" > "$WORK/f"; mv "$WORK/f" "$R/FEATURES.json"; g commit -qam n
feat e2 M5-002 5; g checkout -q e2; jq '(.features[0].notes) = "two"' "$R/FEATURES.json" > "$WORK/f"; mv "$WORK/f" "$R/FEATURES.json"; g commit -qam n
land e1
check_stop e2 '^CONFLICT: FEATURES\.json at .*M2-001.*notes'
# the branch archives a feature main just changed
feat j1 M5-003 5; g checkout -q j1; jq '(.features[] | select(.id == "M2-002") | .notes) = "changed"' "$R/FEATURES.json" > "$WORK/f"; mv "$WORK/f" "$R/FEATURES.json"; g commit -qam n
feat j2 M5-004 5; g checkout -q j2; jq 'del(.features[] | select(.id == "M2-002"))' "$R/FEATURES.json" > "$WORK/f"; mv "$WORK/f" "$R/FEATURES.json"; g commit -qam n
land j1
check_stop j2 '^CONFLICT: FEATURES\.json at .*M2-002'
# the same id added at different lines: git's text merge is clean, the id merge is not
feat f1 M7-001 7; g checkout -q f1; jq '.features = [.features[-1] | .title = "One"] + .features[:-1]' "$R/FEATURES.json" > "$WORK/f"; mv "$WORK/f" "$R/FEATURES.json"; g commit -qam t
feat f2 M7-001 7; g checkout -q f2; jq '(.features[-1].title) = "Two"' "$R/FEATURES.json" > "$WORK/f"; mv "$WORK/f" "$R/FEATURES.json"; g commit -qam t
land f1
check_stop f2 '^CONFLICT: FEATURES\.json at .*M7-001'
# a shared file that cannot merge as text (binary)
feat k1 M8-001 8; g checkout -q k1; printf 'a\0b\n' > "$R/README.md"; g add README.md; g commit -qm bin
feat k2 M8-002 8; g checkout -q k2; printf 'a\0c\n' > "$R/README.md"; g add README.md; g commit -qm bin
land k1
check_stop k2 '^CONFLICT: README\.md'
# a shared file deleted on one side, edited on the other
feat l1 M9-001 9; g checkout -q l1; g rm -q README.md; g commit -qm del
feat l2 M9-002 9; g checkout -q l2; printf 'text\n' > "$R/README.md"; g commit -qam edit
land l1
check_stop l2 '^CONFLICT: README\.md \(deleted'
# a hook refuses the merge commit
feat m1 M10-001 10; feat m2 M10-002 10; land m1
printf '#!/bin/sh\nexit 1\n' > "$R/.git/hooks/pre-merge-commit"; cp "$R/.git/hooks/pre-merge-commit" "$R/.git/hooks/pre-commit"
chmod +x "$R/.git/hooks/pre-merge-commit" "$R/.git/hooks/pre-commit"
check_stop m2 '^CONFLICT: \(commit refused'
rm "$R/.git/hooks/pre-merge-commit" "$R/.git/hooks/pre-commit"
# an untracked file main starts tracking: refused before merging, the file intact
feat n1 M11-001 11; feat n2 M11-002 11
g checkout -q n1; printf 'tracked\n' > "$R/local.log"; g add local.log; g commit -qm log; g checkout -q main; land n1
g checkout -q n2; printf 'mine\n' > "$R/local.log"; head="$(g rev-parse HEAD)"
set +e; (cd "$R" && bash "$SB" >/dev/null 2>&1); rc=$?; set -e
[ "$rc" -eq 2 ] || fail "an untracked file main tracks must refuse (exit 2), got $rc"
[ "$(cat "$R/local.log")" = mine ] && [ "$(g rev-parse HEAD)" = "$head" ] || fail "the untracked file and HEAD must be untouched"
rm "$R/local.log"

t "M67-001.3 a red gate undoes the merge @critical"
feat r1 M6-001 6; feat r2 M6-002 6
g checkout -q r1; : > "$R/RED"; g add RED; g commit -qm red
land r1
check_stop r2 '^GATE RED'

set +e; (cd "$R" && bash "$SB" --bogus >/dev/null 2>&1); rc=$?; set -e
[ "$rc" -eq 2 ] || fail "bad usage must exit 2"
echo "SYNC-BRANCH TESTS PASS"
