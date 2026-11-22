# M64 — Private names stay private

Owner report (2026-11-22): session notes and a PR description named the
owner's private app repos in this public repo; two older notes did too.

## M64-001 check-private-names.sh

The list of private repo names lives outside git (`.git/info/private-names`),
written by `refresh-private-names.sh` from `gh repo list --visibility private`
(own and organisation repos). `ci-local.sh`, required before every push,
refreshes it, so a new private repo is covered with no manual step, then
fails on a name in any tracked file or in the commit messages being pushed.
PR bodies: `check-private-names.sh <file>`. Names meant to be public go in
`scripts/private-names-allow.txt`. CI has no list and skips.

## Decision log

- 2026-11-22: The list is never committed (it would leak the names itself).
- 2026-11-22: Whole-word, case-insensitive match; a generic private repo name
  that collides with ordinary words goes in the allow file.
- 2026-11-22: Git history and old PR description revisions are not purged
  here; that needs a history rewrite and GitHub Support (owner's call).
