> **For agentic workers:** this single task is one harness coding session.

# M22: Strict-YAML-safe skill frontmatter

**Goal:** Copilot CLI and Codex CLI discover every skill. **Why:** two skills
(harness-continuous, harness-upgrade-structure) were skipped by Copilot because
an unquoted `: ` in their `description:` is invalid YAML; Claude Code is lenient
so no gate or session caught it.

## M22-001 — fix, gate check, release 3.0.1

- Reword the two descriptions so they contain no `: `.
- Gate: fail when any `skills/*/SKILL.md` or `agents/src/*.md` has `: ` inside
  an unquoted `name:`/`description:` line.
- Release 3.0.1 (plugin caches are keyed by version, so the fix only reaches
  users with a new version).

## Decision log

- 2026-10-01 — Fix by rewording, not quoting: the other skills are plain
  scalars and a grep is a sufficient gate; no YAML library is a dependency here.
