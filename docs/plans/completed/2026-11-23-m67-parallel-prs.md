# M67 — Parallel PRs never stop on FEATURES.json or PROGRESS.md

Owner report (2026-11-23): three features built as separate PRs in parallel
worktrees off the same default branch. Each appended its FEATURES.json entry
and its PROGRESS.md entry the session-loop way; every PR after the first
merge conflicted on exactly those two files, by position, never by content.
Each resolution was mechanical (keep both, validate, re-run the gate).
harness-run lanes never hit this (lanes never touch the two files); separate
PRs do. GitHub's merge button ignores `.gitattributes` merge drivers.

## Options weighed

- A. Fragment files (`features/<id>.json`, `progress/<date>-<id>.md`).
  Prevents the conflict, but every kit script, every downstream repo's own
  checks and every agent without the kit read FEATURES.json; a committed
  generated view conflicts again, an uncommitted one is invisible to
  kit-less agents. Rejected: largest change, breaks the portable format.
- B. Keep the files; a script brings the PR branch up to date and resolves
  only those two files. Chosen (below).
- C. Builder PRs never edit the two files; a post-merge step writes them.
  Rejected: until that step runs, the default branch says a merged feature
  is failing and the next session builds it again; a CI job needs write
  access to a protected default branch.

## M67-001 sync-branch.sh

`sync-branch.sh [<base>] [--push]` (harness-session) merges `origin/<base>`
into the current branch (a merge, not a rebase: one resolution, no force
push). Whenever both sides changed them, conflicting in git or not:

- FEATURES.json: a three-way merge by key: objects key by key, arrays of
  objects with an `id` by id (main's order, then the branch's new ids), any
  other value taken from the side that changed it. Both sides changing the
  same value differently, or adding the same id with different content,
  stops it. A clean text merge is not trusted: the same id added at two
  different lines merges cleanly in git.
- PROGRESS.md: by `## ` entry: the branch's new entries on top, then
  main's, minus the entries the branch removed (trims hold on either side).

A conflict in a `shared_paths` file keeps both sides (`git merge-file
--union --diff3`; without `--diff3` git interleaves two blocks line by
line); a binary or one-side-deleted file stops it.

Any other conflicted file aborts the merge, tree as before. Then the gate
runs; red undoes the merge. `--push` pushes (plain push).

Migration: none for data. harness-upgrade-structure recopies the protocol,
whose §2.6 now says: a PR that cannot merge because the default branch
moved runs `sync-branch.sh`, and after a merge, run it on the other open
harness PRs. Without the kit: the same steps by hand.

## Decision log

- 2026-11-23: B over A and C (above). Merge over rebase: a rebase replays
  each commit that touched the two files (several resolutions) and needs a
  force push.
- 2026-11-23: FEATURES.json is rewritten in jq's format (the format the
  kit's own tools write); a repo formatted differently gets a NOTE.
- 2026-11-23: Independent review (Codex) of the first version found 8
  defects; 7 fixed with a test each (see the M67-001 notes). Not fixed:
  files a red gate writes stay in the tree, as after any gate run.
