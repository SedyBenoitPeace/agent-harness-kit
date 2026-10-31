---
name: harness-upgrade-structure
description: Use when a repo that already has a harness (FEATURES.json and PROGRESS.md exist) must be brought up to the structure the installed plugin ships — after a plugin update, or when a session reports the UPGRADE offer. Runs one deterministic script that recopies the protocol and adds the missing AGENTS.md line and evaluator agent files. For a repo with no harness, use harness-initial-setup instead.
---

# Harness Upgrade Structure

Upgrades an existing harnessed repo in place. The work is done by
`scripts/upgrade.sh` (path relative to this skill), which a human can also
run by hand with no agent; this skill runs it, explains the result, and
commits it. It is **not** for new repos: that is harness-initial-setup.

**Announce at start:** "Using harness-upgrade-structure to upgrade this harness."

## Workflow

1. Run `bash scripts/upgrade.sh <target-repo>` from this skill's folder.
   - Exit 3: no harness here. Offer harness-initial-setup and STOP.
   - Exit 2: it refused (dirty tree, `harness-upgrade` branch already
     exists, not a git repo). Relay the reason in one line and STOP; never
     work around it.
   - On the default branch it creates `harness-upgrade` first. It stages
     and commits nothing.
2. Read the `CHANGED:` / `OK:` / `TODO:` lines and tell the human what
   changed in two or three lines: the protocol copy recopied, the
   harness-run line and the read rule (`grep -n` first, then `sed -n` ≤80
   lines; since 3.15.0) and the feature-work scope of the session loop
   (since 3.16.0: small tasks skip it) added to AGENTS.md, the vendor pointer
   files importing AGENTS.md with `@AGENTS.md` and AGENTS.md saying the harness
   applies with or without the plugin (since 3.17.0), agent files regenerated (restart
   Copilot CLI to see them; since 3.14.1 every Copilot agent carries
   `deferred-tool-loading: true`, so it uses tool search instead of loading
   every tool definition per call; since 3.15.0 a builder dispatched with a
   brief starts from `context.sh --brief` and skips SKILL.md and AGENTS.md), the kit version recorded in
   `docs/agents/harness-kit-version`.
3. Relay every `UPGRADE-NOTE: <version>: <note>` line: these are the
   release notes' Upgrade steps for each release since this repo's last
   upgrade, oldest first. Do the ones that only touch harness files once the
   human agrees; list the rest as things the human must do.
4. If the protocol was recopied, check `git diff` for local notes the old
   copy had below the shipped text; re-append them.
5. Handle the `TODO:` lines by offering, never applying silently:
   - unbounded `scripts/e2e.sh` → wrap each command with the `step`
     function from the initial-setup `templates/e2e.sh.tmpl`;
   - `depends_on` / `paths` → offer **harness-audit**, which proposes them
     for the human to approve (without declared `depends_on`, a skipped
     feature stops a continuous run);
   - `effort is now required` → propose a level for each listed feature
     from the protocol §1.4 table (`docs/agents/harness-protocol-planning.md`),
     one line per feature with its reason; once the human approves, write
     them into FEATURES.json in the upgrade commit. Never skip it: until
     every open feature has one, harness-audit fails;
   - `model is now required` → the same, with a size per feature from the
     §1.4 size table (`small`, `medium` or `large`, respecting its floors);
     propose both in one list when both TODOs appear.
6. Commit the upgrade as its own commit, explicit paths, message
   `chore: upgrade harness structure` — never mixed with feature work.
   Never push; the human decides.

## Red flags

| Thought | Reality |
|---|---|
| "No harness yet, I'll just scaffold it here" | That is harness-initial-setup, a different command. |
| "Dirty tree, I'll stash it and carry on" | The script refuses; the human decides what to do with their changes. |
| "I'll fold this into the feature commit" | The upgrade is its own commit. |
| "The TODOs are small, I'll fix them quietly" | Offer them; the human approves. |
