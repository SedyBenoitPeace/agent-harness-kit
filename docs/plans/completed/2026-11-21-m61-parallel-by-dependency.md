# M61: Lanes by dependency, not milestone 

Owner: Stefano, thread "Fix board timer and harness parallelism", 2026-11-21.
Evidence: on the live M57–M60 plan context.sh found 0 lanes; without the
milestone wall 2; also ignoring README/CHANGELOG 3. an app repo run
2026-11-21: PARALLEL none 6 of 7 times until the owner said "overrule the
harness"; then waves of 4–6 lanes for 6 h, gate green.

## Built
- M61-001 context.sh: `--through N` opens later milestones; `shared_paths`
  (FEATURES.json top level; absent = README.md, CHANGELOG.md) never block; `max_lanes` (default 5, was 3);
  `--busy` line `<id> ready` keeps files, frees the slot; each open feature
  that is not a lane prints `  not a lane: <id> — <reason>` (not with --brief).
- M61-002 merge-lane.sh: --no-ff merge; conflicts only in shared_paths are
  union-merged; any other conflict aborts (exit 1, CONFLICT: lines).

## Also built (after M57–M60 merged)
- M61-003 harness-run / harness-continuous: pass `--through`; a lane from a
  later milestone finishes as `ready` and merges (merge-lane.sh) when its
  milestone branch exists; continuous runs may automerge per can-merge.sh.
- M61-004 owner decision A: a dependency that is `deferred` with notes
  starting `Needs a human: verify` (built, merged, gate green, only a human
  check left) counts as met on continuous runs; a feature whose notes say to
  wait for an approval still waits. Protocol text + context.sh + tests.
- Protocol planning doc: shared_paths, max_lanes; FEATURES template; README,
  CHANGELOG, version bump, sync-template.
