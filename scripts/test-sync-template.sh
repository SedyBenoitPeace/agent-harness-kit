#!/usr/bin/env bash
# Fixture tests for scripts/sync-template.sh (M27-005). Exit 0 = green.
# shellcheck disable=SC2015 # a && b || fail asserts
set -euo pipefail
cd "$(dirname "$0")/.."
SYNC="$PWD/scripts/sync-template.sh"
T="skills/harness-initial-setup/templates"
fail() { echo "SYNC-TEMPLATE TEST FAIL: $*" >&2; exit 1; }
[ -f "$SYNC" ] || fail "sync-template.sh missing"

W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
M="$W/mirror"; mkdir -p "$M/docs/agents" "$M/scripts"
# a stale mirror: old files, its own banner, README and PRODUCT skeleton
printf '# AGENTS.md — {{PROJECT_NAME}}\n\n> **UNINITIALIZED TEMPLATE.** Plan first.\n>\n> Then delete this banner.\n\nold body\n' > "$M/AGENTS.md"
printf 'mirror readme\n' > "$M/README.md"
mkdir -p "$M/docs"; printf 'product skeleton\n' > "$M/docs/PRODUCT.md"
printf 'old protocol\n' > "$M/docs/agents/harness-protocol.md"

rc=0; bash "$SYNC" "$M" --check >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 1 ] || fail "--check on a stale mirror: want exit 1, got $rc"

bash "$SYNC" "$M" >/dev/null || fail "sync: expected exit 0"
cmp -s "$T/harness-protocol.md" "$M/docs/agents/harness-protocol.md" || fail "protocol not synced"
for p in FEATURES.json PROGRESS.md ARCHITECTURE.md; do cmp -s "$T/$p.tmpl" "$M/$p" || fail "$p not synced"; done
cmp -s "$T/dev.sh.tmpl" "$M/scripts/dev.sh" && cmp -s "$T/e2e.sh.tmpl" "$M/scripts/e2e.sh" || fail "scripts not synced"
[ -x "$M/scripts/e2e.sh" ] || fail "scripts/e2e.sh must be executable"
cmp -s "$T/pointer.md.tmpl" "$M/CLAUDE.md" && cmp -s "$T/pointer.md.tmpl" "$M/GEMINI.md" || fail "pointers not synced"
grep -q '^> \*\*UNINITIALIZED TEMPLATE.\*\* Plan first.$' "$M/AGENTS.md" || fail "AGENTS.md: mirror banner lost"
grep -q '^> Then delete this banner.$' "$M/AGENTS.md" || fail "AGENTS.md: banner cut at its bare > line"
grep -q '^## Needs a human' "$M/AGENTS.md" || fail "AGENTS.md: template body missing"
grep -q 'old body' "$M/AGENTS.md" && fail "AGENTS.md: old body kept"
[ "$(head -1 "$M/AGENTS.md")" = "$(head -1 "$T/AGENTS.md.tmpl")" ] || fail "AGENTS.md: title line wrong"
[ "$(cat "$M/README.md")" = "mirror readme" ] && [ "$(cat "$M/docs/PRODUCT.md")" = "product skeleton" ] || fail "README/PRODUCT must be left alone"

before="$(cd "$M" && find . -type f -exec cksum {} + | sort)"
bash "$SYNC" "$M" >/dev/null
[ "$before" = "$(cd "$M" && find . -type f -exec cksum {} + | sort)" ] || fail "sync is not idempotent"
bash "$SYNC" "$M" --check >/dev/null || fail "--check on a synced mirror: want exit 0"

echo "SYNC-TEMPLATE TESTS GREEN"
