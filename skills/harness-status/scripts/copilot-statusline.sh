#!/usr/bin/env bash
# copilot-statusline (M37-001): the harness line on Copilot CLI's status line,
# beside the user's own (never replacing it). Experimental: Copilot's
# statusLine is behind its STATUS_LINE feature flag.
# Usage: copilot-statusline.sh              render (Copilot pipes session JSON on stdin)
#        copilot-statusline.sh --install    point Copilot's statusLine at a copy of this script
#        copilot-statusline.sh --uninstall  put back the user's statusLine and feature flags
# Render: runs the user's original statusLine command with the same stdin and
# prints its output, then " · " and `status.sh --line` for the session's cwd.
# With no original command, a short Copilot line instead: model, context used,
# tokens (no dollars). Outside a harnessed repo the harness part is empty.
# Install copies this script and status.sh to $COPILOT_HOME/agent-harness-kit/
# (so a plugin update cannot break the path; re-run --install to refresh) and
# keeps the replaced statusLine in original.json there. Installing twice keeps
# the first original. COPILOT_HOME defaults to ~/.copilot.
# Exit codes: 0 ok; 2 settings.json is not valid JSON (nothing written).
set -euo pipefail

HOME_DIR="${COPILOT_HOME:-$HOME/.copilot}"
SETTINGS="$HOME_DIR/settings.json"
DEST="$HOME_DIR/agent-harness-kit"
HERE="$(cd "$(dirname "$0")" && pwd)"

write_settings() { # $1 = new JSON; cat > keeps the file's mode
  printf '%s\n' "$1" > "$SETTINGS.tmp" && cat "$SETTINGS.tmp" > "$SETTINGS" && rm -f "$SETTINGS.tmp"
}

read_settings() {
  [ -s "$SETTINGS" ] || { mkdir -p "$HOME_DIR"; echo '{}' > "$SETTINGS"; }
  jq -e 'type == "object"' "$SETTINGS" >/dev/null 2>&1 \
    || { echo "copilot-statusline: $SETTINGS is not a JSON object; nothing changed" >&2; exit 2; }
}

case "${1:-}" in
  --install)
    read_settings
    mkdir -p "$DEST"
    cp "$HERE/copilot-statusline.sh" "$HERE/status.sh" "$DEST/"
    cmd="bash \"$DEST/copilot-statusline.sh\""
    cur="$(jq -c '.statusLine // null' "$SETTINGS")"
    if [ "$(jq -r '.statusLine.command // ""' "$SETTINGS")" != "$cmd" ]; then
      flag="$(jq -r '(.feature_flags.enabled // []) | index("STATUS_LINE") == null' "$SETTINGS")"
      jq -n --argjson s "$cur" --argjson f "$flag" '{statusLine: $s, added_flag: $f}' > "$DEST/original.json"
    fi
    new="$(jq --arg c "$cmd" '
      .statusLine = {type: "command", command: $c, padding: (.statusLine.padding // 1)}
      | .feature_flags.enabled = (((.feature_flags.enabled // []) - ["STATUS_LINE"]) + ["STATUS_LINE"])' "$SETTINGS")"
    write_settings "$new"
    echo "copilot-statusline: installed in $SETTINGS; restart Copilot CLI"
    exit 0 ;;
  --uninstall)
    read_settings
    [ -f "$DEST/original.json" ] || { echo "copilot-statusline: not installed"; exit 0; }
    new="$(jq --slurpfile o "$DEST/original.json" '
      ($o[0]) as $o
      | (if $o.statusLine == null then del(.statusLine) else .statusLine = $o.statusLine end)
      | if $o.added_flag and .feature_flags.enabled then .feature_flags.enabled -= ["STATUS_LINE"] else . end' "$SETTINGS")"
    write_settings "$new"
    rm -f "$DEST/original.json" "$DEST/copilot-statusline.sh" "$DEST/status.sh"
    rmdir "$DEST" 2>/dev/null || true
    echo "copilot-statusline: removed; your status line is back. Restart Copilot CLI"
    exit 0 ;;
esac

input="$(cat)"
own=""
orig="$(jq -r '.statusLine.command // ""' "$HERE/original.json" 2>/dev/null || true)"
if [ -n "$orig" ]; then
  own="$(printf '%s' "$input" | bash -c "$orig" 2>/dev/null || true)"
else
  own="$(printf '%s' "$input" | jq -r '
    def k: if . >= 1000 then "\((. / 1000) | floor)k" else tostring end;
    [ .model.display_name // .model.id,
      (.context_window.current_context_used_percentage // .context_window.used_percentage
        | if . then "ctx \(. | floor)%" else empty end),
      (.context_window.total_tokens | if . then "\(k) tokens" else empty end)
    ] | map(select(. != null and . != "")) | join(" · ")' 2>/dev/null || true)"
fi
dir="$(printf '%s' "$input" | jq -r '.cwd // .workspace.current_dir // empty' 2>/dev/null || true)"
dir="$(git -C "${dir:-.}" rev-parse --show-toplevel 2>/dev/null || echo "${dir:-.}")"
harness="$(bash "$HERE/status.sh" --line "$dir" 2>/dev/null || true)"

if [ -n "$own" ] && [ -n "$harness" ]; then
  printf '%s · %s\n' "$own" "$harness"
elif [ -n "$own$harness" ]; then
  printf '%s\n' "$own$harness"
fi
