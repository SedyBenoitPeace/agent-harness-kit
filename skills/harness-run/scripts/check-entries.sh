#!/usr/bin/env bash
# harness-run: is this repo ready for an orchestrated run? No model calls.
# (M65-001) An open (failing) feature without depends_on or paths, or whose
# paths claim the whole repo or a whole tracked top-level folder (`qa/`,
# `src/**`), always runs one at a time, and nothing else notices: refuse
# the run until the entries say what each feature really needs and owns.
# Also refuses kit scripts older than the repo's recorded kit version
# (docs/agents/harness-kit-version): an old cached plugin misses newer rules.
# Usage: check-entries.sh [TARGET_DIR]
# Prints, one per line:
#   ENTRY: <id> — <problem>        blocks
#   KIT: stale — <versions>         blocks
#   ORDER?: <id> — <hint>           warning: a dependency that may be order only
#   LANES: <n> of <m> open features can start now: <ids>
#   RULE: <protocol 1.4 rule>       only when blocked
#   ENTRIES: ok | ENTRIES: blocked — <what to do>
# Exit codes: 0 ok; 1 blocked; 2 no FEATURES.json.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
cd "${1:-.}"
[ -f FEATURES.json ] || { echo "check-entries: no FEATURES.json" >&2; exit 2; }
blocked=0

# kit version: these scripts vs the version the repo was last upgraded to
kit_v="$(jq -r '.version // empty' "$here/../../../.claude-plugin/plugin.json" 2>/dev/null || true)"
have_v="$(tr -d "[:space:]" 2>/dev/null < docs/agents/harness-kit-version || true)"
vlt() { # A < B, numerically per field
  local a1 a2 a3 b1 b2 b3
  IFS=. read -r a1 a2 a3 <<< "$1"; IFS=. read -r b1 b2 b3 <<< "$2"
  [ "${a1:-0}" -lt "${b1:-0}" ] && return 0; [ "${a1:-0}" -gt "${b1:-0}" ] && return 1
  [ "${a2:-0}" -lt "${b2:-0}" ] && return 0; [ "${a2:-0}" -gt "${b2:-0}" ] && return 1
  [ "${a3:-0}" -lt "${b3:-0}" ]
}
if [ -n "$kit_v" ] && [ -n "$have_v" ] && vlt "$kit_v" "$have_v"; then
  echo "KIT: stale — these scripts are kit $kit_v, this repo records $have_v (docs/agents/harness-kit-version); update the plugin or run the kit $have_v scripts"
  blocked=1
fi

# tracked top-level folders: claiming one whole is too broad
tops="$({ git ls-files 2>/dev/null || true; } | awk -F/ 'NF > 1 { print $1 }' | sort -u)"
ARCH=docs/features-archive.json; [ -f "$ARCH" ] || ARCH=/dev/null
out="$(jq -r --arg tops "$tops" --slurpfile arc "$ARCH" '
  ($tops | split("\n") | map(select(length > 0))) as $top
  | (.shared_paths // ["README.md", "CHANGELOG.md"]) as $shared
  | ([$arc[].features[]?, .features[]] | map({key: .id, value: .status}) | from_entries) as $st
  | [.features[] | select(.status == "failing")] | sort_by(.milestone, .id) as $f
  | def base: sub("[*?\\[].*$"; "") | sub("/+$"; "") | sub("^\\./"; "");
    def broad: . as $p | ($p | base) as $b
      | if $b == "" or $b == "." then "\($p) is the whole repo"
        elif ($b | contains("/") | not) and ($top | index([$b])) then "\($p) is the whole top-level folder \($b)/"
        else null end;
    ( $f[] | . as $e
      | (if (.depends_on | type) != "array" then "ENTRY: \(.id) — no depends_on (use [] when it needs nothing)" else empty end),
        (if (.paths | type) != "array" or (.paths | length) == 0 then "ENTRY: \(.id) — no paths (the files it changes or the narrowest folder it owns)"
         else (.paths[] | select(. as $p | $shared | index([$p]) | not) | broad | select(. != null)
               | "ENTRY: \($e.id) — paths \(.); name the files or the narrowest subfolder it owns") end) ),
    ( range(1; $f | length) | select($f[.].depends_on == [$f[. - 1].id])
      | "ORDER?: \($f[.].id) — depends only on \($f[. - 1].id), the feature before it; keep it only if its code cannot build or test without it (order is not a dependency)" ),
    ( [$f[] | select((.depends_on | type) == "array" and (.paths | type) == "array" and (.paths | length) > 0
                     and all(.depends_on[]; $st[.] == "passing")) | .id] as $now
      | "LANES: \($now | length) of \($f | length) open features can start now\(if $now == [] then "" else ": " + ($now | join(" ")) end)" )
' FEATURES.json)"
[ -z "$out" ] || printf '%s\n' "$out"
printf '%s\n' "$out" | grep -q '^ENTRY: ' && blocked=1

if [ "$blocked" -eq 1 ]; then
  echo 'RULE: every feature records depends_on (ids whose code it cannot build or test without; [] for none; preferred order is not a dependency) and paths (the files it changes or the narrowest folder it owns; never a whole src/ or top-level folder). A feature with either missing always runs sequentially. (protocol 1.4)'
  echo 'ENTRIES: blocked — fix the ENTRY/KIT lines (FEATURES.json entries, or the kit), commit, then start the run again'
  exit 1
fi
echo 'ENTRIES: ok'
