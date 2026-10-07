#!/usr/bin/env bash
# Fixture tests for skills/harness-run/scripts/second-opinion.sh (M26-001).
# Stub claude/codex/copilot CLIs on PATH record their arguments and answer
# with a canned reply; a "tamper" stub changes the repo to prove the
# integrity check. Exit 0 = green.
# shellcheck disable=SC2015,SC2016 # a && b || fail asserts; literal backticks and $1
set -euo pipefail
cd "$(dirname "$0")/.."
SO="$PWD/skills/harness-run/scripts/second-opinion.sh"
fail() { echo "SECOND-OPINION TEST FAIL: $*" >&2; exit 1; }

W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
mkdir -p "$W/bin" "$W/repo"

# One stub for all three CLIs: args to $STUB_LOG, reply from $STUB_REPLY,
# codex writes it to its -o file, STUB_TAMPER=1 dirties the repo.
cat > "$W/bin/stub" <<'STUB'
#!/usr/bin/env bash
name="$(basename "$0")"
printf '%s\n' "$name" "$@" > "$STUB_LOG"
[ "${STUB_TAMPER:-0}" = 1 ] && echo tampered > tampered.txt
out=""
while [ $# -gt 0 ]; do [ "$1" = "-o" ] && out="$2"; shift; done
if [ "$name" = codex ] && [ -n "$out" ]; then printf '%s\n' "$STUB_REPLY" > "$out"; echo "codex progress noise"; else printf '%s\n' "$STUB_REPLY"; fi
STUB
chmod +x "$W/bin/stub"
for c in claude codex copilot; do ln -s stub "$W/bin/$c"; done

cd "$W/repo"
git init -q -b main . && git config user.email t@t && git config user.name t
cat > FEATURES.json <<'JSON'
{ "milestones": {"1": "One"}, "features": [
  { "id": "M1-001", "milestone": 1, "title": "greet", "status": "review", "second_opinion": "codex",
    "verify": "bash greet.sh Ada prints Hello, Ada!" } ] }
JSON
echo '# P' > PROGRESS.md && git add -A && git commit -qm base
base="$(git rev-parse HEAD)"
printf 'echo "Hello, $1!"\n' > greet.sh && git add -A && git commit -qm feature
cd - >/dev/null

export STUB_LOG="$W/args"
run() { PATH="$W/bin:$PATH" bash "$SO" "$@" "$W/repo"; }

# 1. each CLI: read-only flags, no model flag; PASS → exit 0, writes nothing
for c in claude codex copilot; do
  rc=0; out="$(STUB_REPLY=$'PASS\n1. greet.sh prints the greeting' run "$c" M1-001 "$base")" || rc=$?
  [ "$rc" -eq 0 ] || fail "$c PASS: expected exit 0, got $rc"
  grep -qx 'VERDICT: PASS' <<< "$out" || fail "$c PASS: missing VERDICT: PASS"
  grep -qx "$c" "$STUB_LOG" || fail "$c: wrong CLI ran"
  grep -Eqx -- '-m|--model' "$STUB_LOG" && fail "$c: must not name a model (M28-001)"
  grep -q '^MODEL:' <<< "$out" && fail "$c: no MODEL line expected"
  case "$c" in
    codex)   grep -qx 'read-only' "$STUB_LOG" && grep -qx -- '--sandbox' "$STUB_LOG" || fail "codex: --sandbox read-only missing" ;;
    claude)  grep -qx -- '--disallowedTools' "$STUB_LOG" && grep -qx 'Write' "$STUB_LOG" && grep -qx 'dontAsk' "$STUB_LOG" || fail "claude: read-only flags missing" ;;
    copilot) grep -qx -- '--deny-tool=write' "$STUB_LOG" && grep -qx -- '--no-ask-user' "$STUB_LOG" || fail "copilot: read-only flags missing" ;;
  esac
  [ -z "$(git -C "$W/repo" status --porcelain)" ] || fail "$c: script left the repo dirty"
done

# 2. the prompt carries the evaluator contract, verify, commit range, effort
prompt="$(cat "$STUB_LOG")"
grep -qF 'exactly `PASS` or `NEEDS_WORK`' <<< "$prompt" || fail "prompt: evaluator contract missing"
grep -qF 'bash greet.sh Ada prints Hello, Ada!' <<< "$prompt" || fail "prompt: verify missing"
grep -qF "$base..HEAD" <<< "$prompt" || grep -qF "${base}..HEAD" <<< "$prompt" || fail "prompt: commit range missing"
grep -qF 'Effort: high.' <<< "$prompt" || fail "prompt: effort line missing"

# 3. NEEDS_WORK and an unrecognised first line → exit 1, NEEDS_WORK
rc=0; out="$(STUB_REPLY=$'NEEDS_WORK\n1. greet.sh:1 no test' run codex M1-001 "$base")" || rc=$?
[ "$rc" -eq 1 ] && grep -qx 'VERDICT: NEEDS_WORK' <<< "$out" && grep -qF 'greet.sh:1 no test' <<< "$out" || fail "NEEDS_WORK: want exit 1 with findings"
rc=0; out="$(STUB_REPLY='Looks fine to me' run claude M1-001 "$base")" || rc=$?
[ "$rc" -eq 1 ] && grep -qx 'VERDICT: NEEDS_WORK' <<< "$out" || fail "unrecognised reply: want exit 1 NEEDS_WORK"

# 4. a CLI that changed the repo → REJECTED, exit 1, change left for the human
rc=0; out="$(STUB_TAMPER=1 STUB_REPLY=PASS run copilot M1-001 "$base")" || rc=$?
[ "$rc" -eq 1 ] && grep -qx 'VERDICT: REJECTED' <<< "$out" && grep -qF 'tampered.txt' <<< "$out" || fail "tamper: want exit 1 REJECTED naming the change"
rm -f "$W/repo/tampered.txt"

# 5. broken invocations → exit 2
rc=0; PATH="$W/bin:$PATH" bash "$SO" gemini M1-001 "$base" "$W/repo" >/dev/null 2>&1 || rc=$?; [ "$rc" -eq 2 ] || fail "unknown CLI: want exit 2, got $rc"
rc=0; STUB_REPLY=PASS run codex M9-999 "$base" >/dev/null 2>&1 || rc=$?; [ "$rc" -eq 2 ] || fail "unknown feature: want exit 2, got $rc"
mkdir "$W/nocli"; for t in bash git jq mktemp cat sed head grep tr dirname basename; do ln -sf "$(command -v "$t")" "$W/nocli/$t"; done
rc=0; PATH="$W/nocli" bash "$SO" codex M1-001 "$base" "$W/repo" >/dev/null 2>&1 || rc=$?; [ "$rc" -eq 2 ] || fail "missing CLI: want exit 2, got $rc"

echo "SECOND-OPINION TESTS GREEN"
