# M68-003 — upgrade-all.sh no longer stops at an existing upgrade branch; single repos by argument

Owner (2026-11-23): a repo with a `harness-upgrade` branch is skipped, so a
merged upgrade whose branch was not deleted, or an upgrade PR still open
when the next kit release lands, costs a manual step every time. And there
is no way to run one repo without editing the list.

## Behaviour

Paths as arguments: `upgrade-all.sh [--dry-run] PATH...` runs those paths
(a repo, or a folder of repos, exactly as list lines) and does not read or
need the list, and never prompts.

The existing-branch rules, per repo, replacing `skipped: harness-upgrade
branch exists`:

- A local `harness-upgrade` branch is ignored and left alone: the temp
  worktree is detached (`git worktree add --detach`) and the push is
  `HEAD:refs/heads/harness-upgrade`. The script creates and deletes no
  local branch.
- `origin/harness-upgrade` absent: as today, from `origin/<default>`.
- `origin/harness-upgrade` present, an open PR has it as head: start the
  worktree from `origin/harness-upgrade`, run `upgrade.sh`; changed →
  commit on top, push (a plain fast-forward push, never forced) →
  `PR <url> (updated)`; nothing changed → `PR <url> (already open)`.
  Commits already on the branch (resolved TODOs) are kept.
- Present, no open PR, and the newest PR for that head is merged with the
  branch tip equal to that PR's head commit: the branch is stale. Delete
  it on origin, then run as if absent.
- Present, anything else (no PR was opened, the PR was closed, commits
  were added after the merge): start from `origin/harness-upgrade`, run
  `upgrade.sh`, commit if changed, open a PR → `PR <url>`. With nothing
  changed and no commits ahead of the default branch: delete the branch on
  origin → `up to date`.
- `--dry-run` deletes and pushes nothing, on origin or locally: `would
  update PR <url> (<n> changed, <m> todo)`, `would open a PR (...)`, or
  the same result lines as a real run where nothing would change.

PR state comes from `gh pr list --head harness-upgrade --state all --json
number,state,url,headRefOid` (newest first). A `gh` failure there is a
failure for that repo (`failed: ...`), not a guess.

## Test (`scripts/test-upgrade-all.sh`)

The stub `gh` answers `pr list` from a per-repo fixture file. Case 2
(same repo again → skipped) is replaced by 11.

11. Open PR, repo then made outdated again (a kit-side change simulated
    the way the existing fixtures do it) → `PR <url> (updated)`; origin's
    branch has the earlier commit plus one more; no force push needed.
12. Open PR, nothing new → `PR <url> (already open)`; branch tip unchanged.
13. Merged PR, tip equal to its head, branch left on origin, repo outdated
    again → the old branch is replaced: `PR <url>`, the new branch has
    exactly one commit on top of the default branch.
14. Branch on origin with no PR at all → a PR is opened from it.
15. A local `harness-upgrade` branch (not on origin) → the run proceeds;
    the local branch still exists afterwards and points where it did.
16. `--dry-run` in the case-13 setup → origin's branch is still there.
17. `upgrade-all.sh --dry-run <repo>` with no list file → one result line
    for that repo, exit 0, no prompt, no list created.

## Decision log

- 2026-11-23: update the open PR in place rather than cherry-picking onto
  a new branch: one PR per repo, resolved TODOs stay, no force push.
- 2026-11-23: stale = merged PR whose head commit is the branch tip, asked
  from `gh`: a squash merge leaves no ancestry for git to see.
- 2026-11-23: a closed PR is not special: the repo is still outdated and
  listed, so it would get a fresh PR after the branch is deleted anyway.
- 2026-11-23: `upgrade.sh` itself still refuses an existing branch when
  run by hand on the default branch; that is shipped behaviour and a
  separate change. `upgrade-all.sh <repo>` avoids it.
