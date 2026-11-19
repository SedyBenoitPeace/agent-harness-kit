#!/usr/bin/env bash
# shellcheck disable=SC2016 # literal backticks in patterns
# Every file an onboarded doc names must exist where the doc says it does
# (M52-002). Setup and upgrade copy the protocol docs and AGENTS.md into a
# repo; a session there can follow a rule only if the file it names is
# either installed in that repo or a kit file the doc says lives in the kit.
# Usage: check-doc-refs.sh [KIT_ROOT]   (default: this repo). Exit 1 on a gap.
#   - `scripts/<x>.sh`: must be a destination in harness-initial-setup's
#     scaffold table, or called optional on the line that names it.
#   - a bare `<x>.sh` / `<x>.tmpl`: must exist in the kit (skills/*/scripts/
#     or the setup templates), and the doc must carry the kit-files note.
#   - a doc saying run state is listed in .gitignore needs setup and upgrade
#     to put `.harness-run/` there.
set -uo pipefail
ROOT="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
TMPL="$ROOT/skills/harness-initial-setup/templates"
SETUP="$ROOT/skills/harness-initial-setup/SKILL.md"
UPGRADE="$ROOT/skills/harness-upgrade-structure/scripts/upgrade.sh"
NOTE='not files in this repo'
gaps=0
gap() { echo "DOC-REFS: $*"; gaps=$((gaps + 1)); }

# repo files setup installs: the destination column of its scaffold table
installed="$(grep -E '^\| `templates/' "$SETUP" | grep -oE '`scripts/[A-Za-z0-9_.-]+\.sh`' | tr -d '`' | sort -u)"
[ -n "$installed" ] || gap "no scripts/*.sh destinations found in $SETUP's scaffold table"

for doc in "$TMPL"/harness-protocol*.md "$TMPL/AGENTS.md.tmpl"; do
  d="$(basename "$doc")"
  # repo paths
  while IFS=: read -r n ref; do
    [ -n "$ref" ] || continue
    grep -qxF "$ref" <<< "$installed" && continue
    sed -n "${n}p" "$doc" | grep -qi 'optional' && continue
    gap "$d:$n names $ref, which setup does not install (add it to the scaffold table or call it optional)"
  done < <(grep -noE '(^|[^A-Za-z0-9_./-])scripts/[A-Za-z0-9_.-]+\.sh' "$doc" | sed -E 's/:[^s]*scripts\//:scripts\//')
  # bare kit file names
  kit=0
  while IFS=: read -r n ref; do
    [ -n "$ref" ] || continue
    if compgen -G "$ROOT/skills/*/scripts/$ref" >/dev/null || [ -f "$TMPL/$ref" ]; then
      kit=1
    else
      gap "$d:$n names $ref, which is neither installed in the repo nor shipped by the kit"
    fi
  done < <(grep -noE '(^|[^A-Za-z0-9_./-])[A-Za-z0-9_][A-Za-z0-9_.-]*\.(sh|tmpl)\b' "$doc" | sed -E 's/:[^A-Za-z0-9_]+/:/')
  if [ "$kit" -eq 1 ] && ! tr '\n' ' ' < "$doc" | tr -s ' ' | grep -qF "$NOTE"; then
    gap "$d names kit scripts or templates but never says they are '$NOTE' (and where they live)"
  fi
done

# run state claimed to be git-ignored must be ignored by setup and upgrade
if cat "$TMPL"/harness-protocol*.md | tr '\n' ' ' | tr -s ' ' | grep -qF 'listed in `.gitignore`'; then
  grep -qF '.harness-run/' <(grep -F '.gitignore' "$SETUP") || gap "a doc says .harness-run/ is listed in .gitignore, but setup's SKILL.md never adds it"
  grep -qE '\.harness-run/.*>> *\.gitignore' "$UPGRADE" || gap "a doc says .harness-run/ is listed in .gitignore, but upgrade.sh never adds it"
fi

[ "$gaps" -eq 0 ] || { echo "DOC-REFS: $gaps gap(s)"; exit 1; }
echo "DOC-REFS OK"
