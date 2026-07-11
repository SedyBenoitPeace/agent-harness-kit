---
name: harness-handoff
description: Use when ending a work session, switching to another AI agent (Codex, Cursor, Gemini, another Claude), or asked to "hand off", "prepare the repo for the next agent", or "end the session properly" on a repo using the long-running-agent harness — verifies the session-end ritual (clean tree, green gate, logged session) via a deterministic script and prints a paste-ready prompt telling the next agent exactly which one feature to build.
---

# Harness Handoff

Session-end ritual check + prompt generator for the next agent, whatever
vendor it is. The mechanical checks and the prompt live in
`scripts/handoff.sh` — run it, never re-derive either by hand.

**Announce at start:** "Using harness-handoff to verify the session-end ritual and generate the next agent's prompt."

## Workflow

1. Run `bash scripts/handoff.sh` (path relative to this skill) from the
   target repo root.
   - Exit 3 → harness not initialized: offer the harness-setup skill, STOP.
   - Exit 2 → a harness file is broken: relay the message, suggest the
     harness-audit skill, STOP.
   - Exit 1 → BLOCKED: relay each BLOCKED line and help the human finish
     the ritual (commit the tree, fix the gate, log the session), then
     re-run. Never hand off around a blocker.
2. Exit 0 → relay the prompt **verbatim** in a fenced code block so the
   human can copy-paste it into the next agent. Do not embellish it.
3. Tell them how to feed it: paste into any agent chat, or from a
   terminal `codex "<prompt>"` / `codex exec "<prompt>"` — Codex and
   most CLIs also read AGENTS.md natively, so the prompt is sufficient.
4. Offer `--skip-gate` only when the human explicitly accepts an
   unverified baseline (it prints a WARNING; the next agent must run the
   gate first).
5. Handoff is read-only. Fixing blockers is the human's call — offer,
   don't act unilaterally.

## Red flags

| Thought | Reality |
|---|---|
| "I'll write a nicer prompt myself" | The script's prompt is the contract. Relay it verbatim. |
| "Tree is dirty but it's just docs" | Blocked means blocked. Commit first. |
| "I'll quietly commit their changes to unblock" | Surface the blocker; the human decides. |
| "The next agent is Codex, let me add vendor tips to the prompt" | The prompt stays agent-neutral; feeding instructions go in your chat reply. |
| "Status already showed the next feature" | Status reports; handoff proves the ritual AND packages the prompt. |
