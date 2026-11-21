#!/usr/bin/env bash
# Proves can-merge.sh (M56) against a fake gh, never a live repo.
# Each t "<check id> …" line is the one test for that check (check-coverage.sh).
set -euo pipefail
cd "$(dirname "$0")/.."
KIT="$PWD"
CM="$KIT/skills/harness-session/scripts/can-merge.sh"
fail() { echo "MERGE TEST FAIL: $*" >&2; exit 1; }
t() { echo "-- $1"; }
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
export PATH="$KIT/scripts/fixtures/merge:$PATH"

# repo <name>: a git repo with FEATURES.json, a passing gate and a fake PR #7
repo() {
  r="$tmp/$1"; mkdir -p "$r/scripts" "$r/gh"; export FAKE_GH_DIR="$r/gh"; : > "$r/gh/log"
  cat > "$r/FEATURES.json" <<'J'
{"features": [
  {"id": "M1-001", "milestone": 1, "title": "Book", "status": "passing", "automerge": true},
  {"id": "M1-002", "milestone": 1, "title": "Cancel", "status": "passing"}
]}
J
  printf '#!/usr/bin/env bash\nexit 0\n' > "$r/scripts/e2e.sh"
  (cd "$r" && git init -q && git add -A && git -c user.name=t -c user.email=t@t commit -qm init)
  jq -n --arg sha "$(git -C "$r" rev-parse HEAD)" '{number: 7, state: "OPEN", mergeable: "MERGEABLE",
    title: "Book a session (M1-001)", body: "Builds M1-001 test-first.", labels: [{name: "harness:agent"}],
    headRefOid: $sha, statusCheckRollup: [{name: "gate", status: "COMPLETED", conclusion: "SUCCESS"}]}' > "$r/gh/pr.json"
  cat > "$r/gh/pr.diff" <<'D'
diff --git a/src/book.ts b/src/book.ts
index 1..2 100644
--- a/src/book.ts
+++ b/src/book.ts
@@ -1 +1,2 @@
 x
+y
diff --git a/e2e/booking.spec.ts b/e2e/booking.spec.ts
new file mode 100644
--- /dev/null
+++ b/e2e/booking.spec.ts
@@ -0,0 +1 @@
+test('first booking', () => {});
D
}
pr() { jq "$1" "$FAKE_GH_DIR/pr.json" > "$FAKE_GH_DIR/x" && mv "$FAKE_GH_DIR/x" "$FAKE_GH_DIR/pr.json"; }
run() { (cd "$r" && bash "$CM" 7 "$@" 2>&1); }
merges() { grep -c '^WRITE pr merge' "$FAKE_GH_DIR/log" || true; }

t "M56-001.1 a granted, green, agent PR inside the rules merges @critical"
repo ok
out="$(run --merge)" || fail "exit non-zero: $out"
[ "$(head -1 <<< "$out")" = MERGE ] || fail "first line must be MERGE: $out"
{ [ "$(merges)" = 1 ] && grep -q '^WRITE pr merge 7 ' "$FAKE_GH_DIR/log"; } || fail "want one gh pr merge 7 call: $(cat "$FAKE_GH_DIR/log")"

t "M56-001.2 each broken rule holds the PR with its reason @critical"
hold() {  # hold <name> <reason text> <setup command>
  repo "$1"; eval "$3"
  local rc=0; out="$(run --merge)" || rc=$?
  [ "$rc" = 1 ] || fail "$1: want exit 1, got $rc: $out"
  [ "$(head -1 <<< "$out")" = HOLD ] || fail "$1: first line must be HOLD: $out"
  grep -qF -- "$2" <<< "$out" || fail "$1: reason '$2' missing: $out"
  [ "$(merges)" = 0 ] || fail "$1: merged on HOLD"
}
hold not-granted 'M1-002: not granted automerge' "pr '.title = \"Cancel (M1-002)\" | .body = \"\"'"
hold no-id 'names no feature' "pr '.title = \"Tidy\" | .body = \"\"'"
hold unknown-id 'M9-001: no such feature' "pr '.body += \" Also M9-001.\"'"
hold no-label 'not labelled harness:agent' "pr '.labels = []'"
hold off 'automerge is off for this repo' "jq '. + {automerge: {enabled: false}}' \"\$r/FEATURES.json\" > \"\$r/x\" && mv \"\$r/x\" \"\$r/FEATURES.json\""
hold red-check 'check gate: FAILURE' "pr '.statusCheckRollup[0].conclusion = \"FAILURE\"'"
hold conflict 'not mergeable (CONFLICTING)' "pr '.mergeable = \"CONFLICTING\"'"
hold workflow 'protected path: .github/workflows/ci.yml' "sed -i.b 's#src/book.ts#.github/workflows/ci.yml#g' \"\$FAKE_GH_DIR/pr.diff\""
hold deps 'protected path: package.json' "sed -i.b 's#src/book.ts#package.json#g' \"\$FAKE_GH_DIR/pr.diff\""
hold migration 'protected path: db/migrations/002_add.sql' "sed -i.b 's#src/book.ts#db/migrations/002_add.sql#g' \"\$FAKE_GH_DIR/pr.diff\""
hold deleted-test 'test deleted: e2e/old.spec.ts' "printf 'diff --git a/e2e/old.spec.ts b/e2e/old.spec.ts\ndeleted file mode 100644\n--- a/e2e/old.spec.ts\n+++ /dev/null\n@@ -1 +0,0 @@\n-x\n' >> \"\$FAKE_GH_DIR/pr.diff\""
hold skipped-test 'test weakened in e2e/booking.spec.ts' "sed -i.b 's#^+test(#+test.skip(#' \"\$FAKE_GH_DIR/pr.diff\""

t "M56-001.3 running checks wait; no checks fall back to the local gate"
repo pending; pr '.statusCheckRollup[0].status = "IN_PROGRESS" | .statusCheckRollup[0].conclusion = null'
rc=0; out="$(run --merge)" || rc=$?
{ [ "$rc" = 3 ] && [ "$(head -1 <<< "$out")" = WAIT ]; } || fail "pending: want WAIT exit 3, got $rc: $out"
[ "$(merges)" = 0 ] || fail "merged while waiting"
repo local; pr '.statusCheckRollup = []'
out="$(run --merge)" || fail "no checks, local gate green: must merge: $out"
[ "$(merges)" = 1 ] || fail "no checks, local gate green: no merge call"
repo localred; pr '.statusCheckRollup = []'; printf '#!/usr/bin/env bash\nexit 1\n' > "$r/scripts/e2e.sh"
out="$(run --merge)" && fail "red local gate merged"
grep -qF 'local gate (scripts/e2e.sh) failed' <<< "$out" || fail "red local gate reason missing: $out"
repo otherhead; pr '.statusCheckRollup = [] | .headRefOid = "0000000"'
out="$(run --merge)" && fail "gate on another HEAD merged"
grep -qF 'check out the PR head' <<< "$out" || fail "HEAD mismatch reason missing: $out"

t "M56-001.4 the protected list is printable and overridable"
repo list
out="$(cd "$r" && bash "$CM" --list)" || fail "--list failed"
for w in '.github/' 'migrations' 'auth' 'secret' 'package-lock' 'Dockerfile'; do grep -qF -- "$w" <<< "$out" || fail "default list lacks $w: $out"; done
jq '. + {automerge: {protected: ["^docs/legal/"]}}' "$r/FEATURES.json" > "$r/x" && mv "$r/x" "$r/FEATURES.json"
[ "$(cd "$r" && bash "$CM" --list)" = '^docs/legal/' ] || fail "a configured list must replace the default"
sed -i.b 's#src/book.ts#package.json#g' "$FAKE_GH_DIR/pr.diff"
out="$(run)" || fail "package.json is not protected under the configured list: $out"

echo "MERGE TESTS GREEN"
