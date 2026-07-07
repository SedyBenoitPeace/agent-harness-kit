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

## Red flags

| Thought | Reality |
|---|---|
| "I'll eyeball the repo instead of running the script" | The script is the audit. Run it. |
| "I'll fix the gaps while I'm here" | Report + offer. Fixing is the human's call. |
| "verify says 'works correctly' — close enough" | That is the exact failure §1.4 exists to stop. Flag it. |
| "WARNs are fine to omit from the summary" | Relay everything; the human decides what matters. |
