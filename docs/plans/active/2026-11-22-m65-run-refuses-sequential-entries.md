# M65 — Runs refuse sequential-only entries

Owner report (2026-11-22): an agent turned an approved outline into
FEATURES.json entries without reading protocol 1.4. It gave every entry
`paths: ["qa/"]` (a whole top-level folder), left `depends_on` off one, and
made one depend on another only for order. The run built one feature at a
time and nothing flagged it. It also ran a cached kit older than the repo's.

## M65-001 — check-entries.sh, enforced at run start

- `skills/harness-run/scripts/check-entries.sh`: `ENTRY:` per open feature
  missing `depends_on`/`paths` or naming the whole repo / a whole tracked
  top-level folder; `KIT: stale` when the kit is older than
  `docs/agents/harness-kit-version`; `ORDER?:` hints (depends only on the
  feature before it); `LANES: n of m` up front; exit 1 when blocked.
- `run-start.sh` runs it first and refuses; `context.sh` prints it under
  `== Run readiness ==` and skips the upgrade offer on a stale kit;
  harness-audit WARNs each line.
- Rule quoted inline: protocol outline paragraph, `context.sh --outline`
  `ENTRY_RULE:`, harness-brief skip note.
- Not blocked: an order-only dependency (a script cannot tell intent), a
  folder not tracked yet (a new feature's own folder), `shared_paths`.
