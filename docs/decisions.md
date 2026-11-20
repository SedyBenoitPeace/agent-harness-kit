# Decisions

Owner decisions that shape the kit. Newest first. Each entry: date, decision, why.

## 2026-11-20 — Zero-touch QA chain

Goal: acceptance checks are written at refinement, before code; each check becomes a
test; CI runs the tests and ticks a checklist on the PR; agents fix what is red; green,
low-risk PRs merge themselves.

1. **Borrow from cenci, don't adopt it.** Ideas from github.com/matteobortolazzo/cenci
   (checks as acceptance criteria, a per-check reviewer table, a script verdict,
   up-front merge grant, babysit until merge) are rebuilt inside the kit.
2. **Auto-merge is a CI job.** CI merges a PR when it is green, its feature was granted
   `automerge` in the brief, and it touches nothing on the repo's committed safe list
   (auth, migrations, secrets, dependencies, `.github/`, deploy config, deleted or
   weakened tests). Why a job: private repos on GitHub's free plan cannot use branch
   protection or native auto-merge (HTTP 403).
3. **The merge job gets `contents: write` + `pull-requests: write`, nothing more.**
4. **Checks live in FEATURES.json or in GitHub issues; the repo's config picks one.**
   Same check format in both. Every other piece reads checks through one reader.
5. **Issue-backed repos keep a committed FEATURES.json mirror.** A deterministic sync
   script (`gh` + `jq`, no model tokens) writes issues into FEATURES.json, same schema.
   All kit scripts and agents read the file, so agents without GitHub access still work
   and reads cost what they cost today. Why not a live `gh` reader: online-only, and a
   network call plus tokens on every read.
6. **One owner per field, so sync never conflicts.** The issue owns title, checks and
   automerge. The repo owns `status`, because a flip to passing lands in the same commit
   as its proof. Sync pushes status back as a label and closes the issue on passing.
7. **Migration moves only open work.** `failing` and `deferred` features become issues
   (one issue per feature; kit milestones map to GitHub milestones). Passing and
   superseded features, `docs/features-archive.json` and PROGRESS.md stay in git
   untouched. Ids never change: the issue title is `[<id>] <title>` plus a hidden marker.
8. **Check format.** `{id, title, critical, steps, pass_if, evidence}`, evidence one of
   `test | screenshot | human` (a checklist's "Needs you: yes" maps to `human`). Check
   ids are `<feature id>.<n>` (e.g. `M50-001.1`), unique repo-wide; each has exactly one
   test titled with the id. `bar` stays as the live proof.
9. **The script decides, not the model.** The evaluator writes one row per check
   (covered | partial | missing | unrequested); a script turns the table into PASS or
   NEEDS_WORK.
10. **Issues show what the run board shows.** Sync writes a generated details
    block into each issue body, between hidden markers, below the owner's text
    and checks: Done when (`verify`), `paths`, model and effort, `depends_on`,
    the plan section, `notes`, Needs a human, and live status. Sync rewrites only
    that block; edits inside it are overwritten (change the plan or
    FEATURES.json instead). Built with `sync-issues` (M54).
