#!/usr/bin/env bash
# acceptance-verdict.sh — the script, not the model, decides (M53).
#   acceptance-verdict.sh [--features FEATURES.json] FEATURE_ID TABLE.md|-
# TABLE.md is the evaluator's markdown table, one row per check:
#   | check | verdict | evidence |   verdict: covered | partial | missing | unrequested
# (an unrequested row names extra behaviour nobody asked for, any first cell).
# First output line is PASS (exit 0) or NEEDS_WORK (exit 1), then one reason
# per line. PASS only when every check has exactly one row and every row is
# covered. Exit 2 = usage, or the feature has no checks.
# shellcheck disable=SC2016 # single-quoted jq program: $c, $f are jq variables
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
features="FEATURES.json"
[ "${1:-}" = "--features" ] && { features="${2:?--features needs a file}"; shift 2; }
fid="${1:?usage: acceptance-verdict.sh [--features F] FEATURE_ID TABLE.md}"
table="${2:?usage: acceptance-verdict.sh [--features F] FEATURE_ID TABLE.md}"
if [ "$table" = - ]; then t="$(mktemp)"; trap 'rm -f "$t"' EXIT; cat > "$t"; table="$t"; fi  # "-" = stdin (a read-only evaluator)
[ -f "$table" ] || { echo "ERROR: $table not found" >&2; exit 2; }

rows="$(bash "$here/read-checks.sh" "$features" 2>&1)" || { printf 'NEEDS_WORK\nchecks unreadable: %s\n' "$rows"; exit 1; }
checks="$(printf '%s\n' "$rows" | jq -s --arg f "$fid" 'map(select(.feature == $f) | .id)')"
[ "$(jq length <<< "$checks")" -gt 0 ] || { echo "ERROR: $fid has no checks in $features" >&2; exit 2; }

reasons="$({ grep -E '^\s*\|' "$table" || true; } | jq -R . | jq -rs --argjson c "$checks" --arg f "$fid" '
  map(split("|")[1:-1] | map(gsub("^\\s+|\\s+$"; "")))
  | map(select(length >= 2 and (.[0] | ascii_downcase) != "check" and (.[0] | test("^:?-+:?$") | not)))
  | map({id: .[0], v: (.[1] | ascii_downcase)}) as $r
  | ($r | group_by(.id) | map(select(length > 1) | "\(.[0].id): \(length) rows, want exactly one")[]),
    ($r[] | select(.v | IN("covered", "partial", "missing", "unrequested") | not) | "\(.id): unknown verdict \"\(.v)\"; use covered, partial, missing or unrequested"),
    ($r[] | select(.v == "partial" or .v == "missing" or .v == "unrequested") | "\(.id): \(.v)"),
    ($r[] | select(.v != "unrequested" and (.id | IN($c[]) | not)) | "\(.id): not a check of \($f)"),
    ($c[] | . as $i | select([$r[] | select(.id == $i)] | length == 0) | "\($i): no row in the table")')"

if [ -n "$reasons" ]; then printf 'NEEDS_WORK\n%s\n' "$reasons"; exit 1; fi
echo PASS
echo "$(jq length <<< "$checks") of $(jq length <<< "$checks") checks covered"
