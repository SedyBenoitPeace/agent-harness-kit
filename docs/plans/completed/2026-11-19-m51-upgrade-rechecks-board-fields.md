# M51: upgrade re-checks open plans; the board shows every field

## Evidence (one private repo, numbers only)

- A plan was committed under the repo's old protocol copy ("leaving the lane
  fields out is always safe") three minutes before the upgrade that brought
  the 3.20 rules. All 12 open features lacked `paths` and formed one chain,
  each depending only on the previous one, so a run had no lanes. The
  upgrade never looked at open features beyond a missing `depends_on`.
- The owner watched that run on a phone: queued rows showed only dashes,
  and an expanded row hid fields such as `exclusive`, `evaluate` and `bar`.

## M51-001

- upgrade.sh: `TODO: run harness-audit … on: <ids>` for each failing feature
  missing `depends_on` or non-empty `paths`; `TODO: depends_on may be order
  only … : <ids>` when two or more open features each depend only on the
  open feature before them. The upgrade skill proposes fixes, applied only
  on approval.

## M51-002

- board.sh: every expanded row ends with **All fields** (each key of the
  FEATURES.json entry as written, escaped, wrapping on a phone; its open
  state survives the 5 s reload). A queued row's agent column shows
  `model <size> · effort <level>` from FEATURES.json.
