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
- Gate: green (`bash scripts/e2e.sh`).
- Next: M1-002 — AGENTS.md.tmpl + pointer.md.tmpl.
