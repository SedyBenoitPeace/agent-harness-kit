#!/usr/bin/env bash
# harness-status: move fully done milestones out of FEATURES.json (M34-010).
# A milestone whose features are all passing or superseded moves, features
# and milestone name, to docs/features-archive.json (same schema, appended),
# so sessions read a short FEATURES.json. Run by harness-continuous End after
# the run report; never by a coding session.
# Usage: archive-features.sh [TARGET_DIR]    (default: current directory)
# Prints "ARCHIVED: M<n> ... (<k> features) -> docs/features-archive.json"
# or "ARCHIVED: none".
# Exit codes: 0 done; 2 FEATURES.json or the archive broken, or an id to
# move is already archived (nothing written).
# shellcheck disable=SC2016 # single-quoted jq programs: $ms, $old, $in are jq variables
set -euo pipefail
cd "${1:-.}"
ARCH=docs/features-archive.json

command -v jq >/dev/null || { echo "ERROR: jq is required" >&2; exit 2; }
jq -e . FEATURES.json >/dev/null 2>&1 || { echo "FEATURES.json missing or not valid JSON" >&2; exit 2; }
[ ! -f "$ARCH" ] || jq -e . "$ARCH" >/dev/null 2>&1 || { echo "$ARCH is not valid JSON" >&2; exit 2; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
if [ -f "$ARCH" ]; then cp "$ARCH" "$tmp/old.json"; else
  echo '{ "_instructions": "Milestones moved out of FEATURES.json by archive-features.sh once every feature was passing or superseded. History only: never edit; ids stay unique across both files.", "milestones": {}, "features": [] }' > "$tmp/old.json"
fi

# done milestones, as strings (the milestones map is keyed by string)
DONE='([.features | group_by(.milestone)[]
  | select(all(.[]; .status == "passing" or .status == "superseded")) | .[0].milestone | tostring]) as $ms
  | def moving: .milestone | tostring | IN($ms[]); '
summary="$(jq -r --slurpfile old "$tmp/old.json" "$DONE"'
  [.features[] | select(moving) | .id] as $mv
  | if ($mv | length) == 0 then "ARCHIVED: none"
    else ([$mv[] | select(IN($old[0].features[].id))] | join(" ")) as $dup
      | if $dup != "" then "DUP: \($dup)"
        else "ARCHIVED: \($ms | map("M" + .) | join(" ")) (\($mv | length) features) -> docs/features-archive.json" end
    end' FEATURES.json)"
case "$summary" in
  "ARCHIVED: none") echo "$summary"; exit 0 ;;
  DUP:*) echo "already in $ARCH:${summary#DUP:} — nothing archived" >&2; exit 2 ;;
esac

jq --slurpfile old "$tmp/old.json" "$DONE"'
  . as $in | $old[0]
  | .milestones += ($in.milestones // {} | with_entries(select(.key | IN($ms[]))))
  | .features += [$in.features[] | select(moving)]' FEATURES.json > "$tmp/arch.json"
jq "$DONE"'
  .milestones = (.milestones // {} | with_entries(select(.key | IN($ms[]) | not)))
  | .features |= map(select(moving | not))' FEATURES.json > "$tmp/features.json"
mkdir -p docs
cat "$tmp/arch.json" > "$ARCH"     # cat, not mv: keep the files' modes
cat "$tmp/features.json" > FEATURES.json
echo "$summary"
