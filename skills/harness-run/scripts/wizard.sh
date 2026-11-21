#!/usr/bin/env bash
# harness-run: write scripts/wizard-<id>.sh for a Needs-a-human item (M60-003;
# idea from Matt Pocock's `wizard` skill, in this kit's own words).
# Usage: wizard.sh <target> <id> [--check <cmd>] [step...]
# No steps: the one step is the feature's notes after "Needs a human: ".
# Default check: bash scripts/e2e.sh. Refuses any step or check that looks
# like a secret value: the wizard names secrets, never holds them.
# Exit 0 = written (prints its path), 2 = usage, unknown id or secret found.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
target="${1:-}"; id="${2:-}"
[ -n "$target" ] && [ -n "$id" ] || { echo "usage: wizard.sh <target> <id> [--check <cmd>] [step...]" >&2; exit 2; }
shift 2
check="bash scripts/e2e.sh"
[ "${1:-}" = "--check" ] && { check="${2:?--check needs a command}"; shift 2; }
cd "$target"
if [ $# -eq 0 ]; then
  command -v jq >/dev/null || { echo "ERROR: jq is required" >&2; exit 2; }
  note="$(jq -r --arg i "$id" '[.features[] | select(.id == $i)][0].notes // empty' FEATURES.json 2>/dev/null || true)"
  step="$(printf '%s\n' "$note" | sed -n 's/.*Needs a human: *//p' | head -1)"
  [ -n "$step" ] || { echo "wizard: $id has no 'Needs a human:' note; pass the steps" >&2; exit 2; }
  set -- "$step"
fi
# ponytail: pattern list of common token shapes, not a full secret scanner
secret='(sk|pk|rk)_(live|test)_|gh[pousr]_[A-Za-z0-9]|github_pat_|xox[abpr]-|AKIA[0-9A-Z]{12}|-----BEGIN|[A-Za-z_][A-Za-z0-9_]*=[^[:space:]"$]{8,}'
for s in "$@" "$check"; do
  if printf '%s\n' "$s" | grep -qE "$secret"; then
    echo "wizard: refused, looks like a secret value: name the secret and where to put it instead" >&2; exit 2
  fi
done
sq() { printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"; } # single-quoted, readable in the wizard
shopt -u patsub_replacement 2>/dev/null || true # bash 5.2: '&' in a replacement stays literal
steps=""
for s in "$@"; do steps="$steps  $(sq "$s")"$'\n'; done
steps="${steps%$'\n'}"
out="$(cat "$here/../templates/wizard.sh.tmpl")"
out="${out//\{\{STEPS\}\}/$steps}"
out="${out//\{\{CHECK\}\}/$(sq "$check")}"
out="${out//\{\{ID\}\}/$id}"
mkdir -p scripts
printf '%s\n' "$out" > "scripts/wizard-$id.sh"
chmod +x "scripts/wizard-$id.sh"
echo "WIZARD: scripts/wizard-$id.sh"
