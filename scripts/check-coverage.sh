#!/usr/bin/env bash
# check-coverage.sh — every acceptance check has exactly one test (M53).
#   check-coverage.sh [--features FEATURES.json] PATH...   (files or folders of tests)
# A test names a check when a quoted string starts with the check id and a
# space ('M3-002.1 cancel before cutoff @critical'; ids of features not in
# FEATURES.json are ignored, so 'GPT-4.1 mini' is no test). Fails when a check of a
# passing or review feature has no test, any check has two, a test names an
# unknown check id, or @critical disagrees with the check's critical.
# Checks come from read-checks.sh (next to this script), never FEATURES.json.
# Exit 0 = covered; 1 = gaps, one per line on stderr; 2 = usage.
# shellcheck disable=SC2016 # single-quoted jq program: $all, $req are jq variables
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
features="FEATURES.json"
[ "${1:-}" = "--features" ] && { features="${2:?--features needs a file}"; shift 2; }
[ $# -gt 0 ] || { echo "usage: check-coverage.sh [--features FEATURES.json] PATH..." >&2; exit 2; }

all="$(bash "$here/read-checks.sh" "$features" | jq -s .)"
req="$(bash "$here/read-checks.sh" --status passing,review "$features" | jq -s .)"
# each file holding a quoted string that starts with an id of a feature in
# FEATURES.json and a space, comment lines dropped; read whole, so a
# Playwright tag option on the lines after the title still counts
idre="[\"'\`][A-Z][A-Za-z0-9]*-[A-Za-z0-9-]*\.[0-9]+ "
texts="$({ grep -rIlE --exclude-dir=node_modules --exclude-dir=.git "$idre" "$@" 2>/dev/null || true; } \
  | while IFS= read -r f; do { grep -vE '^\s*(//|#|\*|/\*)' "$f" || true; } | jq -Rs .; done | jq -s .)"

gaps="$(jq -rn --slurpfile texts <(printf "%s" "$texts") --argjson all "$all" --argjson req "$req" '
  ($all | map(.feature) | unique) as $features
  # the title runs to its matching closing quote; @critical in the title, or
  # in a tag option (tag: '\''@critical'\'' or tag: [..]) before the test body (=>)
  | [$texts[0][] | . as $text
      | [match("([\"'\''`])([A-Z][A-Za-z0-9]*-[A-Za-z0-9-]*\\.[0-9]+ [^\"'\''`\\n]*(?:(?!\\1)[\"'\''`][^\"'\''`\\n]*)*)\\1"; "g")] as $ms
      | range(0; $ms | length) as $k
      | $ms[$k] as $m
      | $m.captures[1].string as $title
      | ($title | split(" ")[0]) as $id
      | select($id | sub("\\.[0-9]+$"; "") | IN($features[]))
      | ($text[($m.offset + $m.length):(if $k + 1 < ($ms | length) then $ms[$k + 1].offset else ($text | length) end)] | split("=>")[0]) as $after
      | {id: $id,
         critical: (($title | test("(^|\\s)@critical(\\s|$)")) or ($after | test("tag:\\s*(\\[[^\\]]*)?[\"'\''`]@critical[\"'\''`]")))}] as $t
  | ($all | map({(.id): .critical}) | add // {}) as $known
  | ($t | group_by(.id) | map(select(length > 1) | "\(.[0].id): \(length) tests, want exactly one")[]),
    ($t[] | select(.id as $i | $known | has($i) | not) | "\(.id): no such check in FEATURES.json"),
    ($t | unique_by(.id)[] | select(.id as $i | $known | has($i)) | . as $x
       | if $known[$x.id] and ($x.critical | not) then "\($x.id): critical check, test lacks @critical"
         elif ($known[$x.id] | not) and $x.critical then "\($x.id): test tagged @critical, check is not critical"
         else empty end),
    ($req[] | .id as $i | select([$t[] | select(.id == $i)] | length == 0) | "\($i): no test (title must start with \($i))")')"

if [ -n "$gaps" ]; then printf '%s\n' "$gaps" >&2; exit 1; fi
echo "check-coverage: $(jq length <<< "$req") checks covered"
