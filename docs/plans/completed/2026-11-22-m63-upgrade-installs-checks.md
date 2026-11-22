# M63 — Upgrades install acceptance checks

Owner report (2026-11-22): 3.23.0 added acceptance checks, but its Upgrade
note told a person to copy `check-coverage.sh`/`read-checks.sh` and edit
`scripts/e2e.sh` by hand. Nobody did; none of the owner's app repos had
checks working. The upgrade must do the whole upgrade on its own.

## M63-001 upgrade.sh installs acceptance checks

- Copy or refresh `scripts/check-coverage.sh` and `scripts/read-checks.sh`;
  remove a kit copy of `scripts/acceptance-verdict.sh` (matched by its
  header line; a repo's own file of that name stays).
- Add `step check-coverage "bash scripts/check-coverage.sh <folders>"` before
  `GATE GREEN`: folders are conventional test folders plus folders holding
  `*.test.*`/`*.spec.*`/`*_test.*` files (dependencies and build output
  pruned, depth 4, nested folded into parents). A gate with a top-level `cd`
  runs it as is; a gate with `ROOT=` gets `cd '$ROOT' && `. The step is added
  only when it passes now; otherwise one TODO with the exact line and why.
- Idempotent; never touches a repo's own QA tooling.
- CHANGELOG 3.23.0/3.25.0 Upgrade notes no longer ask for manual steps.

## Decision log

- 2026-11-22: Verify-then-insert instead of trusting the folder guess: the
  step is added only when `check-coverage.sh` passes on the detected folders,
  so a wrong guess becomes a TODO, never a red gate.
- 2026-11-22: Found while testing: `check-coverage.sh` exited 1 silently when
  no test title matched (grep's no-match under pipefail); fixed at the source.
- 2026-11-22: Found while testing: UPGRADE-NOTE printed only the first line
  of each multi-line note; wrapped lines are now joined.
- 2026-11-22: Released as 3.26.0 together with M57–M62 (Unreleased) so the
  upgrade prints these notes; merging is the owner's go.
