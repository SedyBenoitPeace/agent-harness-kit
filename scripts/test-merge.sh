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

# repo <name>: a git repo (its own origin) with FEATURES.json on the base
# branch, a passing gate, and a fake PR #7 from an agent
repo() {
  r="$tmp/$1"; G="$tmp/$1.gh"; mkdir -p "$r/scripts" "$G"; export FAKE_GH_DIR="$G"; : > "$G/log"
  cat > "$r/FEATURES.json" <<'J'
{"features": [
  {"id": "M1-001", "milestone": 1, "title": "Book", "status": "passing", "automerge": true},
  {"id": "M1-002", "milestone": 1, "title": "Cancel", "status": "passing"}
]}
J
  printf '#!/usr/bin/env bash\nexit 0\n' > "$r/scripts/e2e.sh"
  (cd "$r" && git init -q && git add -A && git -c user.name=t -c user.email=t@t commit -qm init \
    && git remote add origin "$r" && git fetch -q origin)
  jq -n --arg sha "$(git -C "$r" rev-parse HEAD)" --arg base "$(git -C "$r" branch --show-current)" '{number: 7, state: "OPEN",
    mergeable: "MERGEABLE", title: "Book a session (M1-001)", body: "Builds M1-001 test-first.", labels: [{name: "harness:agent"}],
    baseRefName: $base, headRefOid: $sha, statusCheckRollup: [{name: "gate", status: "COMPLETED", conclusion: "SUCCESS"}]}' > "$G/pr.json"
  jq -n '[{filename: "src/book.ts", status: "modified", additions: 1, deletions: 0, patch: "@@ -1 +1,2 @@\n x\n+y"},
    {filename: "e2e/booking.spec.ts", status: "added", additions: 1, deletions: 0, patch: "@@ -0,0 +1 @@\n+test(\u0027first booking\u0027, () => {});"}]' > "$G/files.json"
  git -C "$r" branch --show-current > "$G/default"
  cp "$r/FEATURES.json" "$G/base.json"
}
files() { jq "$1" "$FAKE_GH_DIR/files.json" > "$FAKE_GH_DIR/x" && mv "$FAKE_GH_DIR/x" "$FAKE_GH_DIR/files.json"; }
pr_head() {  # pr_head <jq expr>: the PR's own commit changes FEATURES.json (base unchanged)
  (cd "$r" && git checkout -qb pr && jq "$1" FEATURES.json > x && mv x FEATURES.json \
    && git -c user.name=t -c user.email=t@t commit -qam pr && git checkout -q -)
  pr ".headRefOid = \"$(git -C "$r" rev-parse pr)\""
  files '. + [{filename: "FEATURES.json", status: "modified", additions: 1, deletions: 1}]'
}
base() {  # base <jq expr>: change FEATURES.json on the base branch (the owner's policy)
  jq "$1" "$r/FEATURES.json" > "$r/x" && mv "$r/x" "$r/FEATURES.json"
  (cd "$r" && git -c user.name=t -c user.email=t@t commit -qam policy && git fetch -q origin)
  cp "$r/FEATURES.json" "$G/base.json"
  pr ".headRefOid = \"$(git -C "$r" rev-parse HEAD)\""
}
pr() { jq "$1" "$FAKE_GH_DIR/pr.json" > "$FAKE_GH_DIR/x" && mv "$FAKE_GH_DIR/x" "$FAKE_GH_DIR/pr.json"; }
run() { (cd "$r" && bash "$CM" 7 "$@" 2>&1); }
merges() { grep -c '^WRITE pr merge' "$FAKE_GH_DIR/log" || true; }

t "M56-001.1 a granted, green, agent PR inside the rules merges @critical"
repo ok
out="$(run --merge)" || fail "exit non-zero: $out"
[ "$(head -1 <<< "$out")" = MERGE ] || fail "first line must be MERGE: $out"
{ [ "$(merges)" = 1 ] && grep -q "^WRITE pr merge 7 .*--match-head-commit $(jq -r .headRefOid "$FAKE_GH_DIR/pr.json")" "$FAKE_GH_DIR/log"; } || fail "want one gh pr merge 7 pinned to the checked head: $(cat "$FAKE_GH_DIR/log")"

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
hold off 'automerge is off for this repo' "base '. + {automerge: {enabled: false}}'"
hold self-grant 'M1-002: not granted automerge' "pr '.title = \"Cancel (M1-002)\" | .body = \"\"'; jq '.features[1].automerge = true' \"\$r/FEATURES.json\" > \"\$r/x\" && mv \"\$r/x\" \"\$r/FEATURES.json\""
hold red-check 'check gate: FAILURE' "pr '.statusCheckRollup[0].conclusion = \"FAILURE\"'"
hold conflict 'not mergeable (CONFLICTING)' "pr '.mergeable = \"CONFLICTING\"'"
hold workflow 'protected path: .github/workflows/ci.yml' "files '.[0].filename = \".github/workflows/ci.yml\"'"
hold deps 'protected path: package.json' "files '.[0].filename = \"package.json\"'"
hold migration 'protected path: db/migrations/002_add.sql' "files '.[0].filename = \"db/migrations/002_add.sql\"'"
hold spaced 'protected path: config/secrets file.json' "files '.[0].filename = \"config/secrets file.json\"'"
hold gate-file 'protected path: scripts/e2e.sh' "base '. + {automerge: {protected: [\"^docs/\"]}}'; files '.[0].filename = \"scripts/e2e.sh\"'"
hold deleted-test 'test deleted: e2e/old.spec.ts' "files '. + [{filename: \"e2e/old.spec.ts\", status: \"removed\"}]'"
hold renamed-test 'test deleted: e2e/old.spec.ts' "files '. + [{filename: \"src/old.ts\", previous_filename: \"e2e/old.spec.ts\", status: \"renamed\"}]'"
hold skipped-test 'test weakened in e2e/booking.spec.ts' "files '.[1].patch |= sub(\"test\\\\(\"; \"test.skip(\")'"
for w in "t.SkipNow()" "xit \\\"books\\\" do" "#[ignore]" "@Disabled" "it.skip.each(rows)"; do
  hold "weak-$(printf '%s' "$w" | tr -cd 'a-zA-Z')" 'test weakened in e2e/booking.spec.ts' "files '.[1].patch += \"\\n+$w\"'"
done
hold gutted-test 'test shrank: e2e/booking.spec.ts' "files '.[1].status = \"modified\" | .[1].deletions = 5'"
hold grant-in-pr 'PR changes automerge settings in FEATURES.json' "pr_head '.features[1].automerge = true'"
hold policy-in-pr 'PR changes automerge settings in FEATURES.json' "pr_head '. + {automerge: {protected: [\"^\$\"]}}'"
for f in .claude/settings.json AGENTS.md CLAUDE.md docs/agents/harness-protocol.md CODEOWNERS .npmrc db/migrate/001_init.rb db/schema.rb alembic/versions/1.py uv.lock src/Auth/login.ts config/Secrets.yml wrangler.toml .gitlab-ci.yml playwright.config.ts; do
  hold "prot-$(printf '%s' "$f" | tr -cd 'a-zA-Z')" "protected path: $f" "files '.[0].filename = \"$f\"'"
done
hold bad-regex 'invalid protected pattern' "base '. + {automerge: {protected: [\"^infra/(\"]}}'"
hold draft 'PR is a draft' "pr '.isDraft = true'"
hold other-base 'base is evil, not the default branch' "pr '.baseRefName = \"evil\"'"
hold origin-differs 'M1-002: not granted automerge' "pr '.title = \"Cancel (M1-002)\" | .body = \"\"'; jq '.features[1].automerge = true' \"\$r/FEATURES.json\" > \"\$r/x\" && mv \"\$r/x\" \"\$r/FEATURES.json\"; (cd \"\$r\" && git -c user.name=t -c user.email=t@t commit -qam local && git fetch -q origin); pr \".headRefOid = \\\"\$(git -C \"\$r\" rev-parse HEAD)\\\"\""
hold one-context 'local gate (scripts/e2e.sh) failed' "pr '.statusCheckRollup = [{context: \"vercel\", state: \"SUCCESS\"}]'; printf '#!/usr/bin/env bash\\nexit 1\\n' > \"\$r/scripts/e2e.sh\"; (cd \"\$r\" && git -c user.name=t -c user.email=t@t commit -qam red); pr \".headRefOid = \\\"\$(git -C \"\$r\" rev-parse HEAD)\\\"\""
hold renamed-in-dir 'test renamed: e2e/old.spec.ts' "files '. + [{filename: \"e2e/old.spec.ts.bak\", previous_filename: \"e2e/old.spec.ts\", status: \"renamed\"}]'"
hold kit-test 'test shrank: scripts/test-merge.sh' "files '. + [{filename: \"scripts/test-merge.sh\", status: \"modified\", additions: 1, deletions: 90, patch: \"@@ -1 +1 @@\\n+exit 0\"}]'"
hold csharp 'test deleted: App.Tests/BookingTests.cs' "files '. + [{filename: \"App.Tests/BookingTests.cs\", status: \"removed\"}]'"
hold rust-inline 'test weakened in src/lib.rs' "files '.[0].filename = \"src/lib.rs\" | .[0].patch += \"\\n+#[ignore]\"'"
hold ctrl-name 'control character in a file name' "files '.[0].filename = \"src/a\\nb.ts\"'"
for w in "self.skipTest(\\\"x\\\")" "@unittest.skipIf(True, 1)" "skip \\\"later\\\"" "\$this->markTestSkipped();" "@tag :skip" "test.fail(" "it.skip(\\\"x\\\")"; do
  hold "weak2-$(printf '%s' "$w" | tr -cd 'a-zA-Z')" 'test weakened in e2e/booking.spec.ts' "files '.[1].patch += \"\\n+  $w\"'"
done
for f in .circleci/config.yml Jenkinsfile azure-pipelines.yml bitbucket-pipelines.yml .travis.yml .buildkite/pipeline.yml .mcp.json src/AGENTS.md packages/web/CLAUDE.md .cursor/rules/a.md .cursorrules .codex/config.toml .gemini/settings.json tox.ini setup.cfg karma.conf.js phpunit.xml Makefile skills/harness-session/scripts/run-gate.sh src/login/oauth.ts; do
  hold "prot2-$(printf '%s' "$f" | tr -cd 'a-zA-Z')" "protected path: $f" "files '.[0].filename = \"$f\"'"
done
hold nested-claude 'protected path: packages/web/.claude/settings.json' "files '.[0].filename = \"packages/web/.claude/settings.json\"'"
hold windsurf 'protected path: .windsurfrules' "files '.[0].filename = \".windsurfrules\"'"
hold pending-call 'test weakened in e2e/booking.spec.ts' "files '.[1].patch += \"\\n+  pending(\\\"later\\\")\"'"
hold spaced-skip 'test weakened in e2e/booking.spec.ts' "files '.[1].patch += \"\\n+  test.skip (\\\"x\\\")\"'"
hold renamed-nopatch 'GitHub sent no patch' "files '. + [{filename: \"e2e/big.spec.ts\", status: \"modified\", additions: 0, deletions: 0}]'"
hold merge-refused 'GitHub refused the merge' "printf 'FAIL\\n' > \"\$FAKE_GH_DIR/merge-fails\""

# routine PRs must still merge (no false holds)
ok_case() {  # ok_case <name> <setup command>
  repo "$1"; eval "$2"
  out="$(run --merge)" || fail "$1: must MERGE: $out"
  [ "$(head -1 <<< "$out")" = MERGE ] || fail "$1: first line must be MERGE: $out"
}
ok_case status-flip "pr_head '.features[0].status = \"review\"'; base '.features += [{id: \"M1-003\", milestone: 1, title: \"New\", status: \"failing\"}] | .features[1].automerge = true'; pr \".headRefOid = \\\"\$(git -C \"\$r\" rev-parse pr)\\\"\"; git -C \"\$r\" checkout -q pr"
ok_case new-feature "pr_head '.features += [{id: \"M1-004\", milestone: 1, title: \"Later\", status: \"failing\"}]'; git -C \"\$r\" checkout -q pr"
ok_case pending-word "files '.[1].patch += \"\\n+expect(order.status).toBe(\\\"pending\\\"); page.click(\\\".skip-link\\\")\"'"
ok_case binary-fixture "files '. + [{filename: \"e2e/fixtures/photo.png\", status: \"added\", additions: 0, deletions: 0}]'"

t "M56-001.3 running checks wait; no checks fall back to the local gate"
repo pending; pr '.statusCheckRollup[0].status = "IN_PROGRESS" | .statusCheckRollup[0].conclusion = null'
rc=0; out="$(run --merge)" || rc=$?
{ [ "$rc" = 3 ] && [ "$(head -1 <<< "$out")" = WAIT ]; } || fail "pending: want WAIT exit 3, got $rc: $out"
[ "$(merges)" = 0 ] || fail "merged while waiting"
repo local; pr '.statusCheckRollup = []'
out="$(run --merge)" || fail "no checks, local gate green: must merge: $out"
[ "$(merges)" = 1 ] || fail "no checks, local gate green: no merge call"
repo localred; pr '.statusCheckRollup = []'; printf '#!/usr/bin/env bash\nexit 1\n' > "$r/scripts/e2e.sh"
(cd "$r" && git -c user.name=t -c user.email=t@t commit -qam red); pr ".headRefOid = \"$(git -C "$r" rev-parse HEAD)\""
out="$(run --merge)" && fail "red local gate merged"
grep -qF 'local gate (scripts/e2e.sh) failed' <<< "$out" || fail "red local gate reason missing: $out"
repo otherhead; pr '.statusCheckRollup = [] | .headRefOid = "0000000"'
out="$(run --merge)" && fail "gate on another HEAD merged"
grep -qF 'check out the PR head' <<< "$out" || fail "HEAD mismatch reason missing: $out"
repo dirty; pr '.statusCheckRollup = []'; printf '#!/usr/bin/env bash\nexit 1\n' > "$r/scripts/e2e.sh"
(cd "$r" && git -c user.name=t -c user.email=t@t commit -qam red); pr ".headRefOid = \"$(git -C "$r" rev-parse HEAD)\""
printf '#!/usr/bin/env bash\nexit 0\n' > "$r/scripts/e2e.sh"
out="$(run --merge)" && fail "a green uncommitted gate over a red committed one merged"
grep -qF 'working tree is not clean' <<< "$out" || fail "dirty tree reason missing: $out"
repo skipped; pr '.statusCheckRollup[0].conclusion = "SKIPPED"'; printf '#!/usr/bin/env bash\nexit 1\n' > "$r/scripts/e2e.sh"
(cd "$r" && git -c user.name=t -c user.email=t@t commit -qam red); pr ".headRefOid = \"$(git -C "$r" rev-parse HEAD)\""
out="$(run --merge)" && fail "only skipped checks and a red gate merged"
grep -qF 'local gate (scripts/e2e.sh) failed' <<< "$out" || fail "skipped-only checks must fall back to the local gate: $out"

t "M56-001.4 the protected list is printable and overridable"
repo list
out="$(cd "$r" && bash "$CM" --list)" || fail "--list failed"
for w in '.github/' 'migrations' 'auth' 'secret' 'package-lock' 'Dockerfile'; do grep -qF -- "$w" <<< "$out" || fail "default list lacks $w: $out"; done
base '. + {automerge: {protected: ["^docs/legal/"]}}'
out="$(cd "$r" && bash "$CM" --list)"
{ grep -qxF '^docs/legal/' <<< "$out" && ! grep -qF 'package' <<< "$out"; } || fail "a configured list must replace the default: $out"
grep -qF 'e2e' <<< "$out" || fail "the gate and merge scripts stay protected under any list: $out"
files '.[0].filename = "package.json"'
out="$(run)" || fail "package.json is not protected under the configured list: $out"

BRIEF="$KIT/skills/harness-brief/scripts/check-brief.sh"
t "M56-002.1 the brief asks for the merge grant @critical"
cp "$KIT/scripts/fixtures/brief/nits-only.md" "$tmp/b.md"
grep -qx '## Automerge' "$tmp/b.md" || fail "fixture brief must carry ## Automerge"
bash "$BRIEF" "$tmp/b.md" >/dev/null || fail "the fixture brief must pass"
for v in yes no; do
  sed "/^## Automerge$/{n;s/.*/$v/;}" "$tmp/b.md" > "$tmp/$v.md"
  bash "$BRIEF" "$tmp/$v.md" >/dev/null || fail "Automerge: $v must pass"
done
sed "/^## Automerge$/{n;s/.*/maybe/;}" "$tmp/b.md" > "$tmp/maybe.md"
out="$(bash "$BRIEF" "$tmp/maybe.md")" && fail "Automerge: maybe passed"
grep -q '^FAIL.*Automerge' <<< "$out" || fail "no FAIL naming Automerge: $out"
sed '/^## Automerge$/,/^$/d' "$tmp/b.md" > "$tmp/none.md"
out="$(bash "$BRIEF" "$tmp/none.md")" && fail "a brief without ## Automerge passed"
grep -q '^FAIL.*Automerge' <<< "$out" || fail "no FAIL naming a missing Automerge: $out"

t "M56-002.2 agents are told the merge rules"
TM="$KIT/skills/harness-initial-setup/templates"
# shellcheck disable=SC2016 # literal backticks
{ grep -qF '`automerge`' "$TM/harness-protocol-planning.md" && grep -qF '## Automerge' "$TM/harness-protocol-planning.md"; } || fail "planning must record automerge from the brief's ## Automerge"
sec26="$(sed -n '/^### 2\.6/,/^Copy-paste/p' "$TM/harness-protocol.md")"
mkdir -p "$tmp/gen" && bash "$KIT/scripts/gen-agents.sh" "$tmp/gen" >/dev/null
n=0
while IFS= read -r f; do
  n=$((n + 1))
  for w in 'harness:agent' 'can-merge.sh --list' 'can-merge.sh <pr> --merge' 'never merge'; do
    grep -qF -- "$w" "$f" || fail "$f: must say $w"
  done
done < <({ echo "$KIT/agents/src/harness-builder.md"; find "$tmp/gen" -type f -name 'harness-builder*'; })
[ "$n" -ge 4 ] || fail "expected the source plus generated builders, found $n"
for w in 'harness:agent' 'can-merge.sh --list' 'can-merge.sh <pr> --merge' 'never merge otherwise' 'update the local default branch'; do grep -qF -- "$w" <<< "$sec26" || fail "protocol 2.6 must say $w"; done

echo "MERGE TESTS GREEN"
