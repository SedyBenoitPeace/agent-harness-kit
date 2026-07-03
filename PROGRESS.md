# PROGRESS

Newest-first session log. One entry per working session. Read this (plus
`git log -20` and FEATURES.json) at the start of every session.

## 2026-07-03 — session 1

- Branch: `m0-harness-scaffolding`
- Done: M0-001 — gate script, FEATURES.json, PROGRESS.md scaffolded.
- Done: M0-002 — LICENSE (MIT), .gitignore, README stub, AGENTS.md refreshed.
  Gate fix along the way: LICENSE check rewritten to avoid shellcheck SC2015.
- Done: M1-001 — FEATURES.json.tmpl + PROGRESS.md.tmpl; gate now validates
  templates (JSON-after-substitution, placeholder presence).
- Done: M1-002 — AGENTS.md.tmpl (40 lines, map + session loop + rules) and
  pointer.md.tmpl (one-liner for CLAUDE.md/GEMINI.md).
- Done: M1-003 — dev.sh.tmpl + e2e.sh.tmpl; gate shellchecks all *.sh.tmpl
  after substituting {{placeholders}} with `true`. Milestone 1 complete.
- Done: M2-001 — harness-protocol.md created: intro (core principle, pillar
  links, layout diagram) + full §1 Planning protocol (interview, PRODUCT.md,
  milestones, verify-field examples, plan, gate, retrofit rules). Gate
  enforces agent-neutrality (no 'claude' string) — it caught the layout
  diagram mentioning a vendor entry-file by name; wording made neutral.
- Gate: green (`bash scripts/e2e.sh`).
- Next: M2-002 — §2 Coding-session protocol.
