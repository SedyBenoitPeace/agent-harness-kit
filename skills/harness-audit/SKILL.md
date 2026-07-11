---
name: harness-audit
description: Use when asked whether a repo is harness-ready, to audit or check a repository's long-running-agent harness (AGENTS.md, FEATURES.json, PROGRESS.md, plans, e2e gate), or before starting harnessed work in an unfamiliar repo — runs a deterministic checker and reports findings, offering fixes without applying them.
---

# Harness Audit

Check whether the current repository is harness-ready. The mechanical
checks live in `scripts/check.sh` — run it, never re-derive it by hand.

**Announce at start:** "Using harness-audit to check harness-readiness."

## Workflow

1. Run `bash scripts/check.sh` (path relative to this skill) from the
   target repo root. Add `--run-gate` only if the human agrees — gates can
   be slow.
2. Relay the PASS/FAIL/WARN report verbatim.
3. Do the one check the script can't: read every `verify` field in
   FEATURES.json and flag unfalsifiable ones ("works correctly"-style).
   The standard is §1.4 of `../harness-setup/templates/harness-protocol.md`
   (worked GOOD/BAD examples inside).
4. Give the verdict: harness-ready, or the ordered list of gaps.
5. **Offer — never auto-apply — fixes:**
   - Structural gaps (no FEATURES.json, no gate, no AGENTS.md): offer to
     run the harness-setup skill in retrofit mode.
   - Trivial gaps (missing plans dirs, drifted or missing protocol doc):
     offer the exact one-liner (mkdir -p / re-copy from harness-setup
     templates).
   - Unfalsifiable verify fields: propose a falsifiable rewrite for each;
     apply only on approval.

## Missing ARCHITECTURE.md — repair flow

When check.sh warns that `ARCHITECTURE.md` is missing, don't just relay
the warning: offer the human a choice of repair and follow their pick.

- **(a) Derive it** — read the codebase (entry points, module layout,
  schema/migrations, queues/jobs), draft `ARCHITECTURE.md` from
  `../harness-setup/templates/ARCHITECTURE.md.tmpl`'s sections, and show
  it for review before committing. Mark anything uncertain with a
  question to the human — never present a guess as an invariant.
- **(b) Interview** — ask the human directly: what are the layers and
  modules, the key entities, and above all the cross-cutting invariants
  no feature may violate? Write the doc from their answers.
- **(c) Skip** — legal (repos harnessed before 1.4.0 lack the doc);
  note in the verdict that sessions will keep re-deriving the shape
  from code until it exists.

A blend of (a)+(b) is often best: derive a draft, then interview only
the gaps and uncertainties — same pattern as §1.1's PRD rule.

## Red flags

| Thought | Reality |
|---|---|
| "I'll eyeball the repo instead of running the script" | The script is the audit. Run it. |
| "I'll fix the gaps while I'm here" | Report + offer. Fixing is the human's call. |
| "verify says 'works correctly' — close enough" | That is the exact failure §1.4 exists to stop. Flag it. |
| "WARNs are fine to omit from the summary" | Relay everything; the human decides what matters. |
