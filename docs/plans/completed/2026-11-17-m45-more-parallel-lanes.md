# M45-002: more features qualify as parallel lanes

**Goal:** plans declare `depends_on` and `paths` tightly enough that
`context.sh` can prove two features independent, and shared folders alone no
longer keep features apart.

## Evidence (private harnessed repos, numbers only)

- The orchestrator does run lanes concurrently: in one run, three lane
  builders started within 15 s and finished 2–5 min later. Lanes are rare
  because `context.sh` rarely proves two features independent.
- Same-milestone pairs that do not depend on each other, counted as
  overlapping by the glob-prefix check: 526/779, 64/75 and 11/11 in three
  repos whose `paths` list whole folders (`app/test/`, `api/`); 4/65 in the
  one repo with narrow paths, which is where lanes fired.
- Repos planned before lanes existed (M17) have no `paths` at all, or
  `depends_on` on a minority of features; the audit warned only when a plan
  declared neither field, so half-filled plans passed silently.
- `depends_on` was used for order: a build-script feature depended on an
  unrelated screen feature only to run after it.

## M45-002

- Overlap check: only a named file blocks (both list it, or one sits inside
  the other's folder or glob); two folders never block. A real conflict is
  still caught at merge (lane dropped, redone sequentially).
- Protocol 1.4 and the FEATURES template: record both fields on every
  feature; `depends_on` only for code the feature cannot build or test
  without; `paths` = files or the narrowest owned folder, shared files named.
- harness-audit WARNs naming every failing feature that lacks either field.
- Tests: test-session.sh (folders don't block, a file in a folder or a
  shared file does; red on the old check), test-audit.sh (WARN names the
  features, not ones with both fields or passing ones).
