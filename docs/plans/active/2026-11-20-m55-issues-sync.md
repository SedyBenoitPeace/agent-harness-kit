# M55: GitHub issues as the place to write features (zero-touch QA phase 1, part 2)

Decisions 4–7 and 10 in `docs/decisions.md`. One script,
`skills/harness-session/scripts/issues.sh`, two commands. Agents and every
other kit script keep reading FEATURES.json; `issues.sh` is the only thing
that talks to GitHub, through `gh`, and spends no model tokens.

Config: FEATURES.json top-level `"source": "issues"` (absent = `features`).
An issue is a feature when its title is `[<feature id>] <title>`.

## M55-001 sync: issues → FEATURES.json

`issues.sh sync`: for each feature issue, the issue owns `title` and
`checks` (parsed by `read-checks.sh` from the text above the generated
block); a new id is appended as `failing` in milestone `M<n>`. Every other
field is the repo's. A broken issue is reported by number and skipped;
exit 1 at the end. With `source` not `issues` it does nothing.

## M55-002 sync: FEATURES.json → issues

Same run, after the pull: each issue's body ends with a generated block
between `<!-- harness:details:start -->` and `<!-- harness:details:end -->`
(the hidden `harness-feature: <id>` marker, status, Done when, depends on,
paths, model and effort, notes, Needs a human, and the plan section).
Only that block is rewritten. Label `harness:<status>`; a passing feature's
issue is closed, a reopened feature's issue reopened. No change, no call.

## M55-003 migrate

`issues.sh migrate`: one issue per `failing` or `deferred` feature that has
none (title `[id] title`, body = checks as markdown + the block, GitHub
milestone `M<n> <name>`), then `"source": "issues"`. Passing, superseded,
`docs/features-archive.json` and PROGRESS.md are untouched. Re-running
creates nothing. `--dry-run` on both commands prints and calls no write.

Tests: `scripts/test-issues.sh` with a stateful fake `gh` on PATH
(`scripts/fixtures/issues/gh`), never a live repo.
