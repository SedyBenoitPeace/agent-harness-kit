#!/usr/bin/env bash
# check-coverage.sh — every acceptance check has exactly one test (M53).
#   check-coverage.sh [--features FEATURES.json] PATH...   (files or folders of tests)
# A test names a check when a quoted string starts with the check id and a
# space ('M3-002.1 cancel before cutoff @critical'). Fails when a check of a
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
# lines with a quoted string starting with a check-shaped id (<feature id>.<n>,
# the feature id holding a dash) and a space; comment lines never count
lines="$(grep -rIhE --exclude-dir=node_modules --exclude-dir=.git \
  "[\"'\`][A-Z][A-Za-z0-9]*-[A-Za-z0-9-]*\.[0-9]+ " "$@" | grep -vE '^\s*(//|#|\*)' || true)"

gaps="$(printf '%s\n' "$lines" | jq -R . | jq -rs --argjson all "$all" --argjson req "$req" '
  # the title runs to the matching closing quote; @critical in the title or
  # in a Playwright tag option (tag: '\''@critical'\'' or tag: [..., '\''@critical'\''])
  map(select(. != "") | . as $line
      | [match("([\"'\''`])([A-Z][A-Za-z0-9]*-[A-Za-z0-9-]*\\.[0-9]+ [^\"'\''`]*(?:(?!\\1)[\"'\''`][^\"'\''`]*)*)\\1").captures[1].string][0] as $title
      | select($title != null)
      | {id: ($title | split(" ")[0]),
         critical: (($title | test("(^|\\s)@critical(\\s|$)")) or ($line | test("tag:\\s*(\\[[^\\]]*)?[\"'\''`]@critical[\"'\''`]")))}) as $t
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
