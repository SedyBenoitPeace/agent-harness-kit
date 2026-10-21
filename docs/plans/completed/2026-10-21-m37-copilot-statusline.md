# M37: harness line on Copilot CLI's status line

**Goal:** the Claude Code edition's status line (harness line beside the
user's own) on Copilot CLI too.

## M37-001 — copilot-statusline.sh

- Copilot CLI runs one `statusLine` command from `~/.copilot/settings.json`
  (behind its experimental `STATUS_LINE` flag) and pipes session JSON on
  stdin. It has no plugin API to add a second line, so the kit wraps it.
- `--install` copies the wrapper and status.sh to
  `$COPILOT_HOME/agent-harness-kit/`, saves the user's statusLine and whether
  the flag was already on in `original.json`, points statusLine at the copy
  and turns the flag on. A second install keeps the first original.
- Render: the user's original command with the same stdin, then
  ` · ` + `status.sh --line` for the session's repo root. No original: model,
  context used and tokens from the payload (no dollars, owner rule for
  non-Claude harnesses).
- `--uninstall` restores statusLine and the flag, removes the copies.
- Verify: test-copilot-statusline.sh on a fake COPILOT_HOME.

## Decision log

- 2026-10-21 (owner): Copilot only; Codex's `[tui] status_line` takes
  built-in items only (openai/codex#17827), so nothing to wrap there yet.
  No README or CHANGELOG announcement until the owner has tested it on
  Copilot CLI; the skill documents it as experimental.
- Copies, not the plugin path: a `copilot plugin update` may move the
  plugin, which would break an absolute command path. Re-run `--install`
  to refresh the copies.
- Harness line on the same line as the user's (` · `), not a second line:
  Copilot's multi-line rendering is not documented.
