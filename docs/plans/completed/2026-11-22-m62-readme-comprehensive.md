# M62 — README a new user can work from

Owner report (2026-11-22): after M60-004 cut the README to 210 lines, a new
user could not learn GitHub issues, domain-driven design, bug intake,
automerge, acceptance checks or parallel lanes from it; the detail existed
only in `docs/guide/`. M60-004's test checked line count and the skills
table, not whether features are explained.

## M62-001 README explains every field and opt-in

README gains: what setup puts in the repo, install for every agent, a
first-hour walkthrough, skill sections that say what each changes, an
"Opt-in features" section, a FEATURES.json field table and troubleshooting.
Domain-driven design moves from the upgrade guide to the planning guide.
FEATURES.json.tmpl `_instructions` names checks, kind, automerge, source.
Test: every field named in the template appears in README.md in backticks,
the key opt-ins are named, and every guide page is linked.

## Decision log

- 2026-11-22: Keep the 400-line cap (M60-004.1): one line per idea plus a
  guide link beats a long page; raise it only if a needed section cannot fit.
- 2026-11-22: The field list in the test is hardcoded (with a comment) rather
  than parsed from `_instructions` prose, which has no stable format.
