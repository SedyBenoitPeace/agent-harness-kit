#!/usr/bin/env bash
# Fixture test for skills/harness-status/scripts/copilot-statusline.sh (M37-001).
# A fake COPILOT_HOME: install keeps the user's statusLine and appends the
# harness line to its output, install twice keeps the first original,
# uninstall restores settings.json, and no own line falls back to Copilot's
# model/context/tokens. Exit 0 = green.
set -euo pipefail
cd "$(dirname "$0")/.."
S="$PWD/skills/harness-status/scripts/copilot-statusline.sh"
fail() { echo "COPILOT-STATUSLINE TEST FAIL: $*" >&2; exit 1; }

W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
export COPILOT_HOME="$W/copilot"
mkdir -p "$COPILOT_HOME" "$W/repo/sub" "$W/plain"
git -C "$W/repo" init -q
cat > "$W/repo/FEATURES.json" <<'JSON'
{ "milestones": { "1": "Core" },
  "features": [ { "id": "M1-001", "milestone": 1, "title": "a", "status": "passing", "verify": "x" },
                { "id": "M1-002", "milestone": 1, "title": "b", "status": "failing", "verify": "x" } ] }
JSON
printf '## 2026-01-01 -- session 1\n- Setup.\n' > "$W/repo/PROGRESS.md"
cat > "$COPILOT_HOME/mine.sh" <<'SH'
#!/usr/bin/env bash
echo "mine $(jq -r .model.id)"
SH
cat > "$COPILOT_HOME/settings.json" <<JSON
{ "theme": "dark", "statusLine": { "type": "command", "command": "bash $COPILOT_HOME/mine.sh", "padding": 2 },
  "feature_flags": { "enabled": ["OTHER"] } }
JSON
before="$(jq -S . "$COPILOT_HOME/settings.json")"
payload() { printf '{"cwd":"%s","model":{"id":"gpt-x","display_name":"GPT X"},"context_window":{"current_context_used_percentage":41.7,"total_tokens":12345}}' "$1"; }

bash "$S" --install >/dev/null
bash "$S" --install >/dev/null
I="$COPILOT_HOME/agent-harness-kit/copilot-statusline.sh"
{ [ -f "$I" ] && [ -f "$COPILOT_HOME/agent-harness-kit/status.sh" ]; } || fail "install did not copy the scripts"
jq -e --arg c "bash \"$I\"" '.statusLine == {type: "command", command: $c, padding: 2}
  and .feature_flags.enabled == ["OTHER", "STATUS_LINE"] and .theme == "dark"' \
  "$COPILOT_HOME/settings.json" >/dev/null || fail "settings after install: $(cat "$COPILOT_HOME/settings.json")"
jq -e '.statusLine.command | endswith("mine.sh")' "$COPILOT_HOME/agent-harness-kit/original.json" >/dev/null \
  || fail "second install overwrote the saved original"

out="$(payload "$W/repo/sub" | bash "$I")"
[ "$out" = "mine gpt-x · harness M1-002 · 1/2 passing" ] || fail "own + harness line wrong: $out"
out="$(payload "$W/plain" | bash "$I")"
[ "$out" = "mine gpt-x" ] || fail "outside a harness the line must be the user's only: $out"

bash "$S" --uninstall >/dev/null
[ "$(jq -S . "$COPILOT_HOME/settings.json")" = "$before" ] || fail "uninstall did not restore settings.json"
[ ! -d "$COPILOT_HOME/agent-harness-kit" ] || fail "uninstall left the copies"

# No statusLine and no settings file: Copilot's own facts, tokens only; uninstall removes both again.
rm "$COPILOT_HOME/settings.json"
bash "$S" --install >/dev/null
out="$(payload "$W/repo" | bash "$I")"
[ "$out" = "GPT X · ctx 41% · 12k tokens · harness M1-002 · 1/2 passing" ] || fail "default line wrong: $out"
case "$out" in *'$'*) fail "dollars on a Copilot line: $out" ;; esac
bash "$S" --uninstall >/dev/null
jq -e '.statusLine == null and .feature_flags.enabled == []' "$COPILOT_HOME/settings.json" >/dev/null \
  || fail "uninstall from empty: $(cat "$COPILOT_HOME/settings.json")"

# Broken settings.json: exit 2, file untouched.
echo '{ nope' > "$COPILOT_HOME/settings.json"
rc=0; bash "$S" --install 2>/dev/null || rc=$?
{ [ "$rc" -eq 2 ] && [ "$(cat "$COPILOT_HOME/settings.json")" = '{ nope' ]; } || fail "broken settings.json: rc=$rc"

echo "copilot-statusline: ok"
