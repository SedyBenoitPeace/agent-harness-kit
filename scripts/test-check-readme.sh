#!/usr/bin/env bash
# shellcheck disable=SC2015,SC2016 # a && b || fail asserts; literal backticks
# Fixture tests for scripts/check-readme.sh (M50-001). Exit 0 = green.
set -euo pipefail
cd "$(dirname "$0")/.."
CHK="$PWD/scripts/check-readme.sh"
fail() { echo "CHECK-README TEST FAIL: $*" >&2; exit 1; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
printf '# kit\nThe board shows a `Human hint` and Lanes roll.\n' > "$W/README.md"

run() { rc=0; out="$(bash "$CHK" "$W/CHANGELOG.md" "$W/README.md" "$W/none" 2>&1)" || rc=$?; }

printf '## 3.22.0 — x\n\n- thing\n\nREADME: `Human hint`, `Lanes roll`\n\n## 3.16.0 — old\n\n- no line, before the cutoff\n' > "$W/CHANGELOG.md"
run; [ "$rc" -eq 0 ] || fail "covered release: want exit 0, got $rc: $out"

printf '## 3.22.0 — x\n\n- thing\n' > "$W/CHANGELOG.md"
run; [ "$rc" -eq 1 ] && grep -q "3.22.0 has no 'README:' line" <<< "$out" || fail "missing README line not caught: $out"

printf '## 3.22.0 — x\n\nREADME: `Human hint`, `run board`\n' > "$W/CHANGELOG.md"
run; [ "$rc" -eq 1 ] && grep -q "never says 'run board'" <<< "$out" || fail "missing phrase not caught: $out"

printf '## 3.22.0 — x\n\nREADME: board stuff\n' > "$W/CHANGELOG.md"
run; [ "$rc" -eq 1 ] && grep -q 'names no' <<< "$out" || fail "line without phrases not caught: $out"

printf '## 3.22.0 — x\n\nREADME: none (gate-only change)\n' > "$W/CHANGELOG.md"
run; [ "$rc" -eq 0 ] || fail "README: none (reason) must pass: $out"

printf '## 3.22.0 — x\n\nREADME: none\n' > "$W/CHANGELOG.md"
run; [ "$rc" -eq 1 ] || fail "README: none without a reason must fail"

printf '## 3.17.10 — x\n\n- y\n' > "$W/CHANGELOG.md"
run; [ "$rc" -eq 1 ] || fail "3.17.10 is >= 3.17.0 (numeric compare)"

t() { echo "-- $1"; }
t "M57-004.1 credit and local skills list"
credits="$(sed -n '/^## Credits/,/^## /p' README.md)"
grep -qF 'github.com/mattpocock/skills' <<< "$credits" && grep -qF 'MIT' <<< "$credits" || fail "M57-004.1: Credits must link github.com/mattpocock/skills (MIT)"
# one line per bullet: wrapped continuation lines joined onto their bullet
local_skills="$(sed -n '/^## Recommended local skills/,/^## /p' README.md \
  | awk '/^- /{if(b!="")print b; b=$0; next} /^ +[^ ]/{sub(/^ +/," "); b=b $0; next} {if(b!="")print b; b=""} END{if(b!="")print b}')"
for s in grilling improve-codebase-architecture prototype codebase-design teach; do
  grep -qiE "^- \*\*$s\*\* — .*not in the kit" <<< "$local_skills" || fail "M57-004.1: Recommended local skills needs a '- **$s** — … not in the kit …' line"
done

t "M60-004.1 README is a guide under 400 lines @critical"
n="$(wc -l < README.md)"; [ "$n" -lt 400 ] || fail "M60-004.1: README.md has $n lines (want under 400)"
first="$(awk '/^## /{c++} c==1' README.md)"
grep -qi '^## What do I run when' <<< "$first" || fail "M60-004.1: the first section must be '## What do I run when'"
rows="$(grep '^|' <<< "$first" || true)"
[ "$(wc -l <<< "$rows")" -ge 5 ] || fail "M60-004.1: the first section must be a situation -> command table"
for d in skills/*/; do s="$(basename "$d")"
  grep -qF -- "$s" <<< "$rows" || fail "M60-004.1: skill $s missing from the 'What do I run when' table"
done

t "M60-004.2 release phrases found in README.md or docs/guide @critical"
mkdir -p "$W/guide"; printf 'Moved: the `Deep phrase` lives here.\n' > "$W/guide/x.md"
printf '## 3.22.0 — x\n\nREADME: `Human hint`, `Deep phrase`\n' > "$W/CHANGELOG.md"
rc=0; out="$(bash "$CHK" "$W/CHANGELOG.md" "$W/README.md" "$W/guide" 2>&1)" || rc=$?
[ "$rc" -eq 0 ] || fail "M60-004.2: a phrase in the guide dir must count: $out"
rc=0; out="$(bash "$CHK" "$W/CHANGELOG.md" "$W/README.md" "$W/none" 2>&1)" || rc=$?
[ "$rc" -eq 1 ] && grep -q "never says 'Deep phrase'" <<< "$out" || fail "M60-004.2: a phrase in neither place must fail: $out"
[ -d docs/guide ] || fail "M60-004.2: docs/guide/ missing"

t "M62-001.1 README itself explains every FEATURES.json field and opt-in @critical"
# A new field or opt-in must reach the front page, not only docs/guide/: a new
# user reads README.md. Add a field here when FEATURES.json.tmpl gains one.
tmpl="$(sed 's/{{[A-Za-z0-9_]*}}/X/g' skills/harness-initial-setup/templates/FEATURES.json.tmpl | jq -r ._instructions)"
for f in depends_on paths shared_paths max_lanes exclusive evaluate bar eval_attempts effort model second_opinion checks kind automerge source; do
  grep -qF -- "$f" <<< "$tmpl" || fail "M62-001.1: FEATURES.json.tmpl _instructions never mentions $f"
  grep -qF -- "\`$f\`" README.md || fail "M62-001.1: README.md never names \`$f\`"
done
for w in GLOSSARY.md 'upgrade.sh --ddd' 'issues.sh migrate' 'harness:agent' 'not a lane' 'Needs a human' '## Troubleshooting' '## FEATURES.json fields'; do
  grep -qF -- "$w" README.md || fail "M62-001.1: README.md never says '$w'"
done

t "M62-001.2 every guide page is linked from the README"
for g in docs/guide/*.md; do
  grep -qF -- "($g" README.md || fail "M62-001.2: README.md does not link $g"
done

# the real repo
bash "$CHK" >/dev/null || fail "this repo's CHANGELOG/README are not covered: $(bash "$CHK" || true)"
echo "CHECK-README TESTS GREEN"
