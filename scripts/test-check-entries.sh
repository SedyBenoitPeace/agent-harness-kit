#!/usr/bin/env bash
# Proves check-entries.sh (M65-001): a run refuses to start while an open
# feature is missing depends_on/paths or claims a whole top-level folder,
# and while the kit scripts are older than the repo's recorded kit version.
# Exit 0 = green.
set -euo pipefail
cd "$(dirname "$0")/.."
KIT="$PWD"
fail() { echo "CHECK-ENTRIES TEST FAIL: $*" >&2; exit 1; }
t() { echo "-- $1"; }
export HARNESS_BOARD_OPEN=0
CHK="$KIT/skills/harness-run/scripts/check-entries.sh"
START_SH="$KIT/skills/harness-run/scripts/run-start.sh"
CTX="$KIT/skills/harness-session/scripts/context.sh"
AUDIT="$KIT/skills/harness-audit/scripts/check.sh"
[ -f "$CHK" ] || fail "check-entries.sh missing"
KIT_V="$(jq -r .version "$KIT/.claude-plugin/plugin.json")"

WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
R="$WORK/repo"; mkdir -p "$R/qa/src" "$R/web" "$R/docs/agents"
g() { git -C "$R" -c user.email=t@t -c user.name=t "$@"; }
g init -q -b main
echo x > "$R/qa/src/a.py"; echo x > "$R/qa/src/b.py"; echo x > "$R/web/app.js"; printf '# P\n' > "$R/PROGRESS.md"
f() { # id deps-json-or-absent paths-json-or-absent [status]
  local d="" p=""
  [ "$2" = - ] || d=",\"depends_on\":$2"
  [ "$3" = - ] || p=",\"paths\":$3"
  printf '{"id":"%s","milestone":5,"title":"t","status":"%s","verify":"v"%s%s}' "$1" "${4:-failing}" "$d" "$p"
}
write() { { echo '{"milestones":{"5":"m"},"features":['; local first=1; for e in "$@"; do [ $first = 1 ] || echo ,; first=0; echo "$e"; done; echo ']}'; } > "$R/FEATURES.json"; g add -A; g commit -qm "fx $RANDOM"; }

t "M65-001.1 bad entries refuse the run @critical"
# --- the post-mortem case: broad qa/, no depends_on, order-only chain ------
write "$(f M5-012 '[]' '["qa/src/a.py"]' passing)" \
      "$(f M5-013 - '["qa/"]')" \
      "$(f M5-014 '["M5-012"]' '["qa/"]')" \
      "$(f M5-015 '["M5-014"]' '["qa/src/b.py"]')" \
      "$(f M5-016 '["M5-015"]' '["web/app.js"]')"
rc=0; out="$(bash "$CHK" "$R")" || rc=$?
[ "$rc" = 1 ] || fail "bad entries must exit 1, got $rc: $out"
echo "$out" | grep -q '^ENTRY: M5-013 — no depends_on' || fail "missing depends_on not named: $out"
echo "$out" | grep -q '^ENTRY: M5-013 — paths qa/ is the whole top-level folder qa/' || fail "broad qa/ not named: $out"
echo "$out" | grep -q '^ENTRY: M5-014 — paths qa/ is the whole' || fail "broad qa/ on M5-014 not named"
echo "$out" | grep -q 'ENTRY: M5-015' && fail "narrow file path must pass: $out"
echo "$out" | grep -q '^ORDER?: M5-016 — depends only on M5-015' || fail "order-only chain not flagged: $out"
echo "$out" | grep -q '^ORDER?: M5-015' || fail "M5-015 chain not flagged"
echo "$out" | grep -q '^RULE: ' || fail "rule must be quoted inline"
echo "$out" | grep -q '^ENTRIES: blocked' || fail "blocked verdict missing"
echo "$out" | grep -q '^LANES: 1 of 4 open features can start now: M5-014$' || fail "up-front lane count wrong: $out"

# run-start refuses and writes no run state
rc=0; out="$(bash "$START_SH" "$R" 2>&1)" || rc=$?
[ "$rc" = 1 ] || fail "run-start must refuse bad entries, got $rc"
echo "$out" | grep -q '^ENTRY: M5-013' || fail "run-start must print the ENTRY lines"
[ ! -e "$R/.harness-run/start" ] || fail "run-start must not write run state when blocked"

# context.sh surfaces it; harness-audit warns (never fails)
out="$(bash "$CTX" "$R")"
echo "$out" | grep -q '^ENTRIES: blocked' || fail "context.sh must print the entries verdict"
out="$(bash "$AUDIT" "$R" || true)"
echo "$out" | grep -q '^WARN  ENTRY: M5-013 — no depends_on' || fail "audit must WARN on bad entries: $out"
echo "$out" | grep -q '^FAIL  ENTRY' && fail "audit must warn, not fail, on entries"

# --- other broad shapes -----------------------------------------------------
for p in '"."' '"**"' '"qa/**"' '"qa"' ; do
  write "$(f M5-020 '[]' "[$p]")"
  rc=0; out="$(bash "$CHK" "$R")" || rc=$?
  [ "$rc" = 1 ] || fail "paths [$p] must be too broad: $out"
done
write "$(f M5-020 '[]' '[]')"
out="$(bash "$CHK" "$R" || true)"; echo "$out" | grep -q '^ENTRY: M5-020 — no paths' || fail "empty paths must be named"

# a new top-level folder (not tracked yet) and shared files are fine
write "$(f M5-021 '[]' '["newagent/", "README.md"]')" "$(f M5-022 '[]' '["qa/src/", "CHANGELOG.md"]')" \
      "$(f M5-023 '["M5-021"]' '["web/app.js"]' deferred)"
out="$(bash "$CHK" "$R")" || fail "good entries must exit 0: $out"
echo "$out" | grep -q '^ENTRIES: ok' || fail "ok verdict missing: $out"
echo "$out" | grep -q '^RULE: ' && fail "no rule noise when ok"
bash "$START_SH" "$R" >/dev/null || fail "run-start must start with good entries"
[ -s "$R/.harness-run/start" ] || fail "run-start wrote no start"
rm -rf "$R/.harness-run"

# archived ids count as known dependencies, never as order-only links
mkdir -p "$R/docs"; echo '{"features":[{"id":"M4-001","status":"passing"}]}' > "$R/docs/features-archive.json"
write "$(f M5-030 '["M4-001"]' '["web/app.js"]')"
out="$(bash "$CHK" "$R")" || fail "archived dependency must pass: $out"
echo "$out" | grep -q '^LANES: 1 of 1 open features can start now: M5-030$' || fail "archived dep counts as met: $out"

t "M65-001.2 a stale kit refuses the run @critical"
# --- stale kit: scripts older than the repo's recorded kit version ----------
echo "99.0.0" > "$R/docs/agents/harness-kit-version"; g add -A; g commit -qm stamp
rc=0; out="$(bash "$CHK" "$R")" || rc=$?
[ "$rc" = 1 ] || fail "stale kit must exit 1"
echo "$out" | grep -q "^KIT: stale — these scripts are kit $KIT_V, this repo records 99.0.0" || fail "stale kit line missing: $out"
rc=0; bash "$START_SH" "$R" >/dev/null 2>&1 || rc=$?; [ "$rc" = 1 ] || fail "run-start must refuse a stale kit"
out="$(bash "$CTX" "$R")"
echo "$out" | grep -q '^KIT: stale' || fail "context.sh must print KIT: stale"
echo "$out" | grep -q '^UPGRADE: offer' && fail "context.sh must not offer an upgrade (a downgrade) from a stale kit"
echo "$KIT_V" > "$R/docs/agents/harness-kit-version"; g add -A; g commit -qm stamp2
bash "$CHK" "$R" >/dev/null || fail "matching kit version must pass"
echo "1.0.0" > "$R/docs/agents/harness-kit-version"; g add -A; g commit -qm stamp3
bash "$CHK" "$R" >/dev/null || fail "older repo stamp (newer kit) must pass"

t "M65-001.3 the rule is quoted where entries are written"
# --- the rule reaches the planner, inline, where entries are written -------
echo '# outline' > "$WORK/outline.md"
out="$(bash "$CTX" --outline "$WORK/outline.md" "$R")"
echo "$out" | grep -q '^ENTRY_RULE: every entry records depends_on .*never a whole src/' || fail "--outline must quote the entry rule"
P="$KIT/skills/harness-initial-setup/templates/harness-protocol-planning.md"
grep -q 'the outline.s order is not a dependency' "$P" || fail "protocol: outline paragraph must quote the rule inline"
grep -q 'refuses to start a run' "$P" || fail "protocol 1.4: run-start refusal missing"
grep -q 'ENTRY:' "$KIT/skills/harness-run/SKILL.md" || fail "harness-run SKILL: ENTRY handling missing"
grep -q 'KIT: stale' "$KIT/skills/harness-continuous/SKILL.md" || fail "harness-continuous SKILL: KIT stale handling missing"

echo "check-entries: all checks passed"
