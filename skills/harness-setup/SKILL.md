---
name: harness-setup
description: Use when planning a new application or feature-set, or when a repo needs a durable agent-operable structure — scaffolds the long-running-agent harness (AGENTS.md, FEATURES.json, PROGRESS.md, plans, e2e gate) so any agent can plan and build one feature per session.
---

# Harness Planning

Scaffold the long-running-agent harness into a target repository by
**copying and adapting the shipped templates — never improvise the schema.**
Everything of substance lives in `templates/`; this file only sequences the
work.

**Announce at start:** "Using harness-setup to set up the agent harness."

## Workflow

### 1. Detect the mode

- **Greenfield**: empty or near-empty directory (no meaningful source tree).
- **Retrofit**: existing codebase. The retrofit rules in step 4 apply on top
  of everything else.
- **Already harnessed**: if `FEATURES.json`, `PROGRESS.md`, and
  `docs/agents/harness-protocol.md` all exist, STOP — the harness is
  already set up. Tell the human and point them to **harness-status**
  ("where am I?") or **harness-audit** ("is it well-formed?").
  Re-scaffold only if they explicitly confirm they want that.

### 2. Run the planning protocol

Read `templates/harness-protocol.md` **section 1** and run it exactly — the
skill follows its own shipped manual. In particular:

- Interview the human first (§1.1 has the required questions). Do not
  answer the questions yourself.
- If the human supplied a requirements document (markdown, PDF, or HTML),
  follow §1.1's rule: extract interview answers from it and ask only
  about the gaps.
- Refuse to write a FEATURES.json entry without a falsifiable `verify`
  criterion (§1.4 has good/bad examples).
- Produce `docs/PRODUCT.md`, milestones, and the first execution plan in
  `docs/plans/active/` before scaffolding.
- Produce `ARCHITECTURE.md` per §1.8: greenfield fills it from the
  interview (intended architecture, marked as such); retrofit derives it
  from reading the code and the human reviews it before commit.
- Record the logging/observability approach per §1.9 in
  `ARCHITECTURE.md`'s cross-cutting invariants — or explicitly note that
  none exists yet. The human picks the technology; do not choose for them.

### 3. Scaffold by copying templates

Copy each template and substitute every `{{PLACEHOLDER}}`:

| Template | Destination |
|---|---|
| `templates/AGENTS.md.tmpl` | `AGENTS.md` |
| `templates/pointer.md.tmpl` | `CLAUDE.md` (and `GEMINI.md` etc. if asked) |
| `templates/FEATURES.json.tmpl` | `FEATURES.json` |
| `templates/PROGRESS.md.tmpl` | `PROGRESS.md` |
| `templates/ARCHITECTURE.md.tmpl` | `ARCHITECTURE.md` (content from §1.8, not placeholders) |
| `templates/dev.sh.tmpl` | `scripts/dev.sh` (chmod +x) |
| `templates/e2e.sh.tmpl` | `scripts/e2e.sh` (chmod +x) |
| `templates/harness-protocol.md` | `docs/agents/harness-protocol.md` — **copied whole, never generated or summarized** |

Also create the empty `docs/plans/active/` and `docs/plans/completed/`
directories (the first plan from step 2 goes in `active/`).

### 4. Retrofit rules (existing codebases)

- Existing `AGENTS.md` / `CLAUDE.md` content is **preserved and linked**,
  never clobbered. Merge the harness map into what's there; move displaced
  depth into `docs/`.
- Existing tests become the initial gate: wire `scripts/e2e.sh` to run them.
- Existing code maps to `passing` features **only** when a `verify`
  criterion actually proves it. Otherwise it enters as `failing` with honest
  notes about what's unverified.

### 5. Verify and commit

1. Run `bash scripts/e2e.sh` — must exit 0. If the gate can't run from a
   clean checkout, the scaffolding isn't done.
2. Make the first commit: all scaffolded files plus the plan, message
   like `chore: scaffold long-running-agent harness`.

## Red flags

| Thought | Reality |
|---|---|
| "I'll just write FEATURES.json from memory" | Copy the template. The schema is not yours to improvise. |
| "This feature is obviously done, I'll mark it passing" | Only a verify criterion flips a status. |
| "The verify field can just say 'works correctly'" | Unfalsifiable. Write the test or the manual check. |
| "I'll put the plan in my head / a gist / chat" | If it's not in the repo, it doesn't exist. |
| "Existing AGENTS.md is messy, I'll rewrite it" | Retrofit extends and links; it never clobbers. |
| "I'll summarize the protocol doc to save space" | It ships whole. Other agents depend on the full text. |
