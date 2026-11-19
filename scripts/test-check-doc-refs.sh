#!/usr/bin/env bash
# shellcheck disable=SC2015,SC2016 # a && b || fail asserts; literal backticks
# Fixture tests for scripts/check-doc-refs.sh (M52-002). Exit 0 = green.
set -euo pipefail
cd "$(dirname "$0")/.."
CHK="$PWD/scripts/check-doc-refs.sh"
fail() { echo "CHECK-DOC-REFS TEST FAIL: $*" >&2; exit 1; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
T="skills/harness-initial-setup/templates"

fresh() { rm -rf "$W/k"; mkdir -p "$W/k"; cp -R skills "$W/k/"; }
run() { rc=0; out="$(bash "$CHK" "$W/k" 2>&1)" || rc=$?; }

# the real kit is clean
bash "$CHK" >/dev/null || fail "this kit's onboarded docs have gaps: $(bash "$CHK" || true)"

# a script the kit does not ship (the reviewer's quiet.sh finding, generalised)
fresh; printf '\nRun `nosuch.sh` first.\n' >> "$W/k/$T/harness-protocol.md"
run; [ "$rc" -eq 1 ] && grep -q 'harness-protocol.md:.* nosuch.sh, which is neither installed' <<< "$out" || fail "missing kit script not caught: $out"

# a kit script named without saying it lives in the kit
fresh; sed -i.bak 's/not files in this repo/elsewhere/' "$W/k/$T/harness-protocol-runs.md"
run; [ "$rc" -eq 1 ] && grep -q "harness-protocol-runs.md names kit scripts or templates but never says" <<< "$out" || fail "kit script without location note not caught: $out"

# a template named without the note (the FEATURES.json.tmpl finding)
fresh; sed -i.bak 's/not files in this repo/kit files/' "$W/k/$T/harness-protocol-planning.md"
run; [ "$rc" -eq 1 ] && grep -q "harness-protocol-planning.md names kit" <<< "$out" || fail "template without location note not caught: $out"

# a repo script setup never installs, unless the line calls it optional
fresh; printf '\nThen run `scripts/lint.sh`.\n' >> "$W/k/$T/harness-protocol.md"
run; [ "$rc" -eq 1 ] && grep -q 'names scripts/lint.sh, which setup does not install' <<< "$out" || fail "uninstalled repo script not caught: $out"
fresh; printf '\nAn optional `scripts/lint.sh` runs first.\n' >> "$W/k/$T/harness-protocol.md"
run; [ "$rc" -eq 0 ] || fail "optional repo script must pass: $out"

# .gitignore claim without setup/upgrade adding .harness-run/ (the first finding)
fresh; sed -i.bak '/^Append `.harness-run\/` to `.gitignore`/d' "$W/k/skills/harness-initial-setup/SKILL.md"
run; [ "$rc" -eq 1 ] && grep -q "setup's SKILL.md never adds it" <<< "$out" || fail "setup without .gitignore step not caught: $out"
fresh; sed -i.bak 's/echo ".harness-run\/" >> .gitignore/true/' "$W/k/skills/harness-upgrade-structure/scripts/upgrade.sh"
run; [ "$rc" -eq 1 ] && grep -q "upgrade.sh never adds it" <<< "$out" || fail "upgrade without .gitignore step not caught: $out"

echo "CHECK-DOC-REFS TESTS GREEN"
