---
name: harness-issues
description: Use when asked to sync a harness repo's features with GitHub issues, to move or migrate a repo's FEATURES.json features to GitHub issues, or when invoked as harness-issues sync or harness-issues migrate — runs the deterministic issues.sh script (gh + jq, no model work), previews a migration before making it, and commits FEATURES.json.
---

# Harness Issues

GitHub issues as the place to write features; FEATURES.json stays the
committed mirror every agent reads. All the work is in `scripts/issues.sh`
(path relative to this skill), run from the repo root: never re-do by hand
what it does, and never edit issues or FEATURES.json yourself for this.

**Announce at start:** "Using harness-issues to <sync | migrate> with GitHub issues."

Needs `gh` signed in to the repo. Without it, say so and stop: agents keep
working from the committed FEATURES.json.

## sync (default when no argument is given)

1. Run `bash scripts/issues.sh sync`. It pulls each `[M<n>-<nnn>]` issue's
   title and checks into FEATURES.json and writes back the details block,
   a `harness:<status>` label and open/closed state.
2. Relay its lines. Exit 1 means some issues were skipped (a broken check,
   one id in two issues): list them with their numbers so the human can
   fix them on GitHub. Issues from people without write access are skipped
   on purpose.
3. If FEATURES.json changed, commit only that file:
   `git add FEATURES.json && git commit -m "Sync features from GitHub issues"`.

## migrate

1. Preview: run `bash scripts/issues.sh migrate --dry-run` and show the
   human the issues and milestones it would create (only failing and
   deferred features; passing features, the archive and PROGRESS.md stay
   in git).
2. Ask the human to confirm before the real run: it creates issues on
   GitHub, which is visible to everyone on the repo. Do not run it on
   your own.
3. On a yes, run `bash scripts/issues.sh migrate`, then commit FEATURES.json
   (it now says `"source": "issues"`) as in sync step 3.
4. Tell the human: from now on write features as issues titled
   `[<feature id>] <title>` with a `## Checks` section, and run
   `harness-issues sync` (or let sessions run it) to bring them in.
