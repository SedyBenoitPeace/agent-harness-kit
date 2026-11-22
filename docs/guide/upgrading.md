# Upgrading

Part of the [agent-harness-kit guide](../../README.md).

## Upgrading existing repos

After updating the plugin, bring each repo that already has a harness up to
date with `harness-upgrade-structure` (new repos use
`harness-initial-setup`); the full checklist is in "Upgrading after every
release" below. It recopies the protocol, adds the missing harness-run line
to `AGENTS.md`, regenerates your agent files, adds `.harness-run/` to
`.gitignore`, prints the release notes you still need, and lists what still
needs you (an unbounded gate,
`depends_on`/`paths`). It refuses a dirty tree, creates `harness-upgrade`
when you are on the default branch, and commits nothing.

With the plugin: `/agent-harness-kit:harness-upgrade-structure`. Or by
hand, no agent needed, from your repo (adjust the plugin folder to your
CLI and version):

```
bash ~/.claude/plugins/cache/agent-harness-kit/agent-harness-kit/<version>/skills/harness-upgrade-structure/scripts/upgrade.sh .
```

(Codex keeps its copy under `~/.codex/plugins/cache/agent-harness-kit/`; or
run the script from a clone of this repository.) Review `git diff`, then
commit it as its own commit.

**Domain-driven design (opt-in):** an existing repo opts in with
`upgrade.sh --ddd .`; without `--ddd` the upgrade never adds it. See
[Domain-driven design](planning.md#domain-driven-design).

**Upgrading to 3.0.0:** `harness-setup` was renamed
`harness-initial-setup`; the old slash command no longer exists.

## Upgrading after every release

Do this in every harnessed repo each time the kit releases (watch the repo or
read [CHANGELOG.md](../../CHANGELOG.md)). It takes a few minutes and is the same
every time:

1. **Update the plugins**: `claude plugin update agent-harness-kit` (and
   `agent-harness-kit-claude` if you use it), `codex plugin marketplace
   upgrade agent-harness-kit`, or `copilot plugin update agent-harness-kit`.
2. In the repo, start from a clean default branch; the upgrade makes its own
   branch, `harness-upgrade`.
3. Run **harness-upgrade-structure** (or `upgrade.sh` by hand, above). It
   recopies the protocol, regenerates your agent files, records the kit
   version in `docs/agents/harness-kit-version`, and lists what is left.
   It also re-checks plans not yet built against the current protocol:
   open features missing `depends_on` or `paths`, and a chain where each
   open feature depends only on the one before it
   (`depends_on may be order only`), so a plan written under an older copy
   is fixed before a run, not after.
4. Read every `UPGRADE-NOTE: <version>: …` line it prints: the Upgrade steps
   from the CHANGELOG for each release since your last upgrade, oldest first.
   Do them.
5. Run **harness-audit** and fix any FAIL.
6. Run the gate: `bash scripts/e2e.sh` must be green.
7. Review `git diff`, then commit the upgrade as its own commit.
8. Open a pull request and merge it before the next feature.

## Upgrading a repo and running continuously

Do the steps in order. The upgrade is once per repo.

**Upgrade**

1. Update the plugin (`claude plugin update agent-harness-kit`,
   `codex plugin marketplace upgrade agent-harness-kit`, or
   `copilot plugin update agent-harness-kit`). In your repo, create a
   branch (`git checkout -b harness-upgrade`) and confirm a green gate:
   `bash scripts/e2e.sh`.
2. Run `/agent-harness-kit:harness-upgrade-structure` (a harness session
   points you to it with an `UPGRADE: offer`; see
   [Upgrading existing repos](#upgrading-existing-repos)). This release
   adds the continuous-run rules to protocol section 2.8, so every existing
   repo's protocol copy is outdated; the upgrade is its own small commit.
3. Run `/agent-harness-kit:harness-audit` and approve its `depends_on` and
   `paths` proposals. This step is essential: without declared `depends_on`,
   a skipped feature stops the run instead of letting it continue.
4. The upgrade already generated the builder and evaluator agent files
   (`scripts/gen-agents.sh <repo>` regenerates them); restart Copilot CLI
   afterwards if you use it, so it loads them.

**Run**

5. Make sure the tree is clean on the branch you want built, then invoke
   `/agent-harness-kit:harness-continuous` (or ask your agent to run
   harness-continuous), adding `cap 20` and/or `through M22` if you want
   them. See [Unattended runs](unattended-runs.md#unattended-runs) for what it does.
6. To stop early: `mkdir -p .harness-run && touch .harness-run/STOP`. It
   finishes the current feature, writes the report and stops.

**Afterwards**

7. Read `docs/runs/<date>.md`: what was done, skipped and not started.
8. For each skipped feature, answer the question recorded in its `notes`
   in FEATURES.json (fix the cause, or reword the feature). A later run
   starts with an empty skip list and retries them.
9. `git stash list` shows any stashed work, labelled
   `harness-run skip <id>`; `git stash show -p stash@{n}` to inspect,
   `git stash pop` to resume it.
10. Review the branch — or branches, if the run crossed milestones.
    Nothing is pushed; merging is yours.
