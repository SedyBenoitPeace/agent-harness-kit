# M48: run board feature context

**Goal:** a board row says what the feature is and how it is proven, not
only its stage, and visibly invites a click.

## M48-001

- Expanded row (`skills/harness-run/scripts/board.sh`), above the
  existing notes / result lines / opinions:
  - `verify` (labelled "Done when"), `depends_on`, `paths`, `effort` and
    `model` from the current FEATURES.json entry; absent fields omitted.
  - The feature's plan section: the `## ` heading in
    `docs/plans/active/*.md` naming the id (then `docs/plans/completed/*.md`)
    up to the next `## `, capped at 40 lines with a "cut at 40 of N" note;
    same matching rule as `skills/harness-run/scripts/feature.sh`. Rendered
    as escaped preformatted text. None found: "no plan section".
  - Links (`file://` absolute paths) to that plan file and to every
    `docs/briefs/*.md` path the plan file mentions that exists.
- Rows look clickable: a ▸ / ▾ marker before the id and `cursor: pointer`
  on the row summary.
- All read in one pass per board refresh; the 60-feature timing limits
  (1.0 s local, 3.0 s with CI=1) still hold with a plan section for every
  feature.
- Tests in `scripts/test-board.sh`: plan section shown and cut at 40 lines,
  completed-plan fallback, brief link only when the file exists, verify /
  depends_on / paths shown, HTML in a plan line escaped, marker present,
  timing with plans.
