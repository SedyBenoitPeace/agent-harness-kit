# M50: docs stay current

**Goal:** a release cannot ship without its README coverage, and a stale
template mirror is caught. Trigger: #46 (3.18.0) and #47 (3.19.1) changed
user-facing behaviour without touching README.md, and the template mirror sat
at 3.19.1 through 3.21.0 (fixed by kit PR #51 and template PR #10).

## M50-001

- Every CHANGELOG release from 3.17.0 on carries one `README: ` line:
  backticked phrases that the README uses to document the release, or
  `README: none (<reason>)`. `scripts/check-readme.sh` fails on a missing
  line, a line without phrases, `none` without a reason, or a phrase that
  README.md does not contain verbatim. Numeric version compare, no `sort -V`.
- The gate runs `scripts/test-check-readme.sh` (fixtures plus this repo).
- With `HARNESS_TEMPLATE_DIR` set, the gate runs `sync-template.sh --check`
  against that mirror checkout. The mirror is private, so kit CI cannot
  check it out; the mirror's own workflow checks it against the public kit
  instead (template repo, `.github/workflows/sync-check.yml`).
- Release checklist in CHANGELOG.md names the `README:` line.
