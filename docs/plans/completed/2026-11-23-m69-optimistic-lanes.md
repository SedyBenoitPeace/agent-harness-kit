# M69 · Lanes like a merge queue; builders across providers by script

Owner report (2026-11-23, a desktop-app repo, kit 3.29.0): `context.sh`
printed `PARALLEL: none` for nine features because eight named the same
app delegate file; the orchestrator overruled it and guessed its own
lanes and waits. Every builder was dispatched as the named Claude agent,
although the host ran child tasks on three providers: the round-robin
rule was prose only. A "move every timing into one file" feature listed
whole source folders and "goes last" lived only in the plan's prose.

## M69-001 · Shared files never keep lanes apart

Like a merge queue (optimistic concurrency): lanes run whenever
`depends_on` is met, merge one at a time through the full gate, and a
conflict is handled at merge. Only paths inside the new top-level
`exclusive_paths` (absent = none) block, plus `exclusive` as before.

## M69-002 · A conflict is resolved in the lane

`merge-lane.sh <target> <id> --into-lane` merges the run's branch into
the lane's worktree. Clean or shared-only → `SYNCED:`. Otherwise the
merge stays in progress there with `RESOLVE:` files and a `BRIEF:` line;
the lane's builder resolves it keeping both sides and runs the gate; the
run merges again. A second conflict → sequential redo (old behaviour).

## M69-003 · Sweeps say what they wait for

`check-entries.sh` prints `SWEEP?:` (hint, never blocks) for an open
feature whose folders hold files that 2+ other open features change and
that is not ordered against them by `depends_on`. Protocol §1.4: such a
feature lists them in `depends_on` and splits out what need not wait.

## M69-004 · Providers assigned by script

`run-start.sh --providers a,b,c` writes `.harness-run/providers`. With 2+,
every `dispatch.sh` prints `VIA: <provider>` (round-robin after the one
last used) and logs it; `--via` may name another listed provider (the
next failed to start); an unlisted one exits 4.

## Verify

`bash scripts/e2e.sh` green: test-session.sh (shared file / nested file
lanes, exclusive_paths blocks), test-merge-lane.sh 3c (--into-lane exit
codes, RESOLVE/BRIEF, run branch untouched, resolution lands, SYNCED),
test-check-entries.sh M69-003.1, test-board.sh M69-004.1/2. On the
owner's live FEATURES.json: `PARALLEL: none` → 5 lanes; `SWEEP?:` names
the sweep feature.
