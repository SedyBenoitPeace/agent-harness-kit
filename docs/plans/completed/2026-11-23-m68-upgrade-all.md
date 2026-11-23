# M68 — One command upgrades every harnessed repo

Owner report (2026-11-23): after each kit release, every harnessed repo is
upgraded by hand, one at a time: run `upgrade.sh`, commit, push, open the PR.
`upgrade.sh` is already deterministic and idempotent; only the fan-out is
manual.

## Options weighed

- A. Push: a script in the kit loops over a local list of repos. Chosen.
- B. Pull: a scheduled GitHub Action in each harnessed repo (Dependabot
  style). Deferred: a workflow template, a per-repo setting so Actions may
  open PRs, and CI cannot resolve `TODO:` lines. Worth it when users other
  than the owner ask.

## M68-001 upgrade-all.sh

`scripts/upgrade-all.sh [--list FILE] [--dry-run]` — a tool of this repo
(like `refresh-private-names.sh`), not shipped in the plugin: no version bump.

The list: one absolute repo path per line, `#` comments and blank lines
ignored. Default `.git/info/upgrade-repos` (via `git rev-parse
--git-common-dir`, as `check-private-names.sh` does): git cannot commit it,
so no repo name or path ever enters this public repo. No list: say where to
create it, exit 2.

Per repo, never touching the repo's own checkout (another session may be
working there, the tree may be dirty):

1. Not a git repo, no `origin` remote → `skipped: <reason>`.
2. `git fetch origin`. A local or remote `harness-upgrade` branch exists →
   `skipped: harness-upgrade branch exists` (an earlier upgrade PR is open).
3. `git worktree add -b harness-upgrade <tmp> origin/<default branch>`; run
   `skills/harness-upgrade-structure/scripts/upgrade.sh <tmp>` there.
   Exit 3 → `skipped: no harness`; exit 2 → `skipped: <its reason>`.
4. Nothing changed → `up to date`; remove the worktree and the branch.
5. Changed → commit `chore: upgrade harness structure`, push, `gh pr create`
   with the `CHANGED:` / `UPGRADE-NOTE:` lines and the `TODO:` lines as a
   `- [ ]` checklist in the body; print `PR <url>`. Remove the worktree
   and the local branch (the PR's head is origin's branch; a local one
   would make the next run skip the repo after the PR merges).
6. `--dry-run`: steps 1–4, then `would open a PR (<n> changed, <m> todo)`;
   remove the worktree and the branch; nothing pushed.

One line per repo: `<path>: <result>`. A repo that fails does not stop the
next; exit 1 if any repo failed unexpectedly (a skip is not a failure). The
temp worktree is removed on every path, including a failure (trap).

Output goes to the terminal only; nothing is written inside this repo.

`TODO:` lines stay manual (sizing a feature, true `depends_on` need
judgement): the PR body is the approval surface; an agent session in that
repo resolves them.

AGENTS.md gets one Rules line: after a release PR merges, run
`bash scripts/upgrade-all.sh`. It is a reminder for the next session, not a
trigger.

### Test (`scripts/test-upgrade-all.sh`, in the gate)

Throwaway repos in a temp folder, each with a bare `origin`; a stub `gh` on
PATH that records its arguments and prints a URL. Made-up names only.

1. Outdated harnessed repo, its checkout dirty and on a feature branch →
   `PR <url>`; `origin` has `harness-upgrade` with one commit named
   `chore: upgrade harness structure`; the checkout's branch, dirty file and
   worktree list are unchanged; the PR body has a `- [ ]` line per TODO.
2. The same repo again → `skipped: harness-upgrade branch exists`.
3. An up-to-date repo → `up to date`; no `harness-upgrade` branch left.
4. A git repo with no harness → `skipped: no harness`; a plain folder →
   `skipped: not a git repo`; both between two good repos, which still run.
5. `--dry-run` on an outdated repo → `would open a PR`; nothing pushed, no
   branch left, `gh` not called.
6. No list file → exit 2, the message names the path to create.

## Decision log

- 2026-11-23: A over B (above).
- 2026-11-23: a temp worktree off `origin/<default>` rather than running in
  the repo's checkout: `upgrade.sh` refuses a dirty tree and would switch
  the branch under a session working there.
- 2026-11-23: the list lives under `.git/info/`, not in a gitignored file:
  `git add -f` gets past `.gitignore`, nothing gets past `.git/`.
- 2026-11-23: no post-merge git hook; the AGENTS.md line only (owner asked
  for the line; the hook was offered and not taken).
