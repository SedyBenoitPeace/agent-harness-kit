# M61: Lanes by dependency, not milestone (WIP, paused until M57–M60 land)

Owner: Stefano, thread "Fix board timer and harness parallelism", 2026-11-21.
Evidence: on the live M57–M60 plan context.sh found 0 lanes; without the
milestone wall 2; also ignoring README/CHANGELOG 3. quick-calories run
2026-11-21: PARALLEL none 6 of 7 times until the owner said "overrule the
harness"; then waves of 4–6 lanes for 6 h, gate green.

## Done on branch parallel-by-dependency (tests green)
- M61-001 context.sh: `--through N` opens later milestones; `shared_paths`
  (FEATURES.json top level) never block; `max_lanes` (default 5, was 3);
  `--busy` line `<id> ready` keeps files, frees the slot; each open feature
  that is not a lane prints `  not a lane: <id> — <reason>` (not with --brief).
- M61-002 merge-lane.sh: --no-ff merge; conflicts only in shared_paths are
  union-merged; any other conflict aborts (exit 1, CONFLICT: lines).

## To do after M60 merges (rebase first: M59-001 also edits context.sh)
- M61-003 harness-run / harness-continuous: pass `--through`; a lane from a
  later milestone finishes as `ready` and merges (merge-lane.sh) when its
  milestone branch exists; continuous runs may automerge per can-merge.sh.
- M61-004 owner decision A: a dependency that is `deferred` with notes
  starting `Needs a human: verify` (built, merged, gate green, only a human
  check left) counts as met on continuous runs; a feature whose notes say to
  wait for an approval still waits. Protocol text + context.sh + tests.
- Protocol planning doc: shared_paths, max_lanes; FEATURES template; README,
  CHANGELOG, version bump, sync-template.
