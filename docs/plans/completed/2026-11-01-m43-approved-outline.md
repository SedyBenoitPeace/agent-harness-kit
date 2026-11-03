# M43: approved outlines skip the brief

**Goal:** when the task already points to a plan or outline the human
approved in another workflow, the kit does not brief or plan it again.

## Evidence (one private run, 2026-10-31, numbers only)

- Planning was 64% of $23.54 for 2 features: the kit ran harness-brief and
  planned again on top of an already approved structure outline.
- Build plus evaluation alone was in line with past kit-only runs, so the
  waste is the duplicated planning, not the build.

## M43-001 — skip rule and hint

- Planning protocol 1.1: "Already have an approved plan or outline?" —
  no harness-brief, no re-plan; FEATURES.json entries plus a plan section
  keeping its phases, order and checks; add only `verify`, `effort` and the
  gate where missing; then harness-run.
- AGENTS.md.tmpl: one two-line rule under the "just build it" line.
  harness-brief and harness-session SKILL.md: one line each.
- `context.sh --outline FILE`: `== Approved outline ==`, `OUTLINE:` and a
  `SKIP_BRIEF:` hint; a missing file prints `OUTLINE: not found — <path>`
  and no hint, so a typo never skips the brief.
- upgrade.sh: adds the AGENTS.md line to existing repos once.
- Verify: test-session.sh (section 12), test-upgrade.sh, e2e greps.

## Decision log

- 2026-11-01: rule in planning protocol 1.1, not the session core (150/150).
- AGENTS.md.tmpl kept at its 70-line cap by shortening step 4 and the
  "only interface" rule; upgrade.sh rewrites those only when unedited, so
  an upgraded template-shaped AGENTS.md still equals the template.
- The hint names the path, never prints the outline: the session reads it
  on demand like any other file.
