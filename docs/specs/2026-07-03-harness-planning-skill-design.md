# Design: `harness-planning` skill

**Date:** 2026-07-03 · **Status:** approved (option B; template-repo extraction
deferred) · **Pillars:** [Anthropic — Effective harnesses for long-running
agents](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents),
[OpenAI — Harness engineering](https://openai.com/index/harness-engineering/)

## 1. Problem

Planning an application with an AI produces artifacts that die with the
session: plans in `~/.claude/plans/`, decisions in chat scrollback, scope in
the model's head. Any *other* agent (Codex, Gemini, Cursor — or tomorrow's
fresh Claude session) starts blind. The reference project (a Flutter + Node
app built one-feature-per-session over several weeks) proved the fix —
FEATURES.json + PROGRESS.md + AGENTS.md + an e2e gate — but that setup was
hand-rolled once. This skill makes it a repeatable process.

## 2. Core principle

> **The repo is the only interface. If it's not in the repo, it doesn't
> exist.**

The skill is a Claude front-end to a process whose every artifact — including
the instructions for running the process itself — lives in the target
repository. Portability is the queen constraint: a scaffolded repo must be
fully operable by a non-Claude agent with zero context beyond the repo.

## 3. Scope

- **In:** greenfield planning (empty dir → planned, harnessed repo) and
  retrofit (existing repo → harness added around existing code; extend, never
  overwrite).
- **In:** the portable protocol doc (`docs/agents/harness-protocol.md`),
  written as a guided markdown usable by any agent harness — Codex
  AGENTS.md ecosystems, Cursor rules, or pasted raw into a chat model.
- **Out (deferred):** extracting a standalone template repo (option C) —
  designed so `templates/` can be lifted wholesale later.
- **Out:** CI/linter enforcement scaffolding (OpenAI-style mechanical
  invariants) beyond documented maintenance tasks; a later milestone.

## 4. What the skill scaffolds into a target repo

```
AGENTS.md                      ≤100 lines: table of contents + session loop summary
CLAUDE.md                      pointer: "See AGENTS.md" (idem GEMINI.md — pointers, not copies)
FEATURES.json                  source of truth for scope/status (schema §5)
PROGRESS.md                    newest-first session log for context recovery
scripts/dev.sh                 boots the dev environment (stack-adapted stub)
scripts/e2e.sh                 the green gate: tests + analyzers, exit 0 = green
docs/
├── PRODUCT.md                 vision, users, UX concept, roadmap (the "why")
├── plans/
│   ├── active/                execution plans w/ progress + decision logs
│   └── completed/             moved here when done (versioned history)
└── agents/
    └── harness-protocol.md    ★ agent-neutral operating manual (§6)
```

Design rules carried over from the pillars:

- **AGENTS.md is a map, not an encyclopedia** (~100 lines max; deeper truth
  lives in `docs/`). Other agent entry-files are one-line pointers to it.
- **Plans are first-class, versioned, co-located** (`docs/plans/`), with
  decision logs — never external to the repo.
- **FEATURES.json is append-only in spirit**: never delete/renumber; statuses
  `failing | passing | deferred | superseded`; flip to `passing` only when the
  feature's own `verify` criterion proves it.
- **The gate is sacred**: every session starts and ends green via
  `scripts/e2e.sh`.

## 5. FEATURES.json schema

Adopted verbatim from the reference project's proven instance:

```json
{
  "_instructions": "Source of truth for the build. DO NOT delete, edit, or renumber existing ids/titles. Statuses: passing (done+proven), failing (actionable), deferred (postponed; notes say when actionable), superseded (dead, kept for history). Flip failing->passing only when a test or the stated manual check proves it. Append new features with the next id in their milestone. Work ONE feature per session: lowest milestone, then lowest id, among 'failing'.",
  "milestones": { "0": "Harness scaffolding", "1": "..." },
  "features": [
    { "id": "M0-001", "milestone": 0, "title": "...",
      "status": "failing", "verify": "<how an agent proves it>", "notes": "" }
  ]
}
```

The `verify` field is load-bearing: it is the acceptance test an agent must
satisfy before flipping status, and doubles as the estimation unit.

## 6. The portable protocol doc (`harness-protocol.md`)

The portability piece. Plain markdown, zero Claude-isms, structured as a
guided operating manual with copy-paste prompts. Three sections:

1. **Planning protocol** (initializer phase): interview the human →
   PRODUCT.md → milestones → FEATURES.json entries with per-feature `verify`
   → first execution plan in `docs/plans/active/` → scaffold/adapt the gate.
   Includes the interview question list and worked examples of good vs bad
   feature entries (good: testable verify; bad: vague "works correctly").
2. **Coding-session protocol**: read `git log -20` + PROGRESS.md +
   FEATURES.json → pick highest-priority `failing` (skip
   deferred/superseded) → run gate, confirm green baseline → implement that
   ONE feature test-first → re-run gate → flip status → commit → append
   PROGRESS.md note. Branch off the default branch; one branch per
   milestone-chunk; integrate via PR.
3. **Maintenance protocol** (entropy GC, from OpenAI): on a cadence, scan for
   drift from the repo's documented conventions and open small cleanup PRs;
   keep AGENTS.md ≤100 lines; garden stale docs.

**Acceptance test for this doc:** hand a scaffolded repo to a non-Claude
agent whose only instruction is "read AGENTS.md and do one session" — it
must complete a correct one-feature session (right feature picked, gate run,
status flipped legally, PROGRESS.md updated).

## 7. Skill anatomy

Canonical source lives in this repository under `skill/harness-planning/`;
Claude users install it by copying (or symlinking) that directory into
`~/.claude/skills/`. Non-Claude users need only
`skill/harness-planning/templates/harness-protocol.md`. Plugin/marketplace
packaging can come later without restructuring.

```
skill/harness-planning/
├── SKILL.md                       trigger description + workflow + red-flags table
└── templates/
    ├── AGENTS.md.tmpl
    ├── FEATURES.json.tmpl
    ├── PROGRESS.md.tmpl
    ├── harness-protocol.md        (shipped whole; copied, not generated)
    ├── dev.sh.tmpl · e2e.sh.tmpl
    └── pointer.md.tmpl            (CLAUDE.md / GEMINI.md one-liner)
```

- SKILL.md instructs: **copy and adapt templates; never improvise the
  schema.** Templates are the single source of truth — this is what makes
  option C (standalone template repo) a later extraction rather than a
  rewrite.
- Workflow in SKILL.md: detect greenfield vs retrofit → run the planning
  protocol (the same one in harness-protocol.md — the skill follows its own
  shipped manual) → scaffold → verify by running `scripts/e2e.sh` → first
  commit.
- Retrofit rules: existing AGENTS.md/CLAUDE.md content is preserved and
  linked, not clobbered; existing tests become the initial gate; existing
  code maps to `passing` features only when a verify criterion actually
  proves them (otherwise they enter as `failing` with honest notes).

## 8. Dogfood

This repo (`harness-planning-skill`) is built with its own harness: the
implementation plan lives in `docs/plans/active/`, scope in FEATURES.json,
sessions logged in PROGRESS.md. The gate for a docs/templates repo is a
lint script (`scripts/e2e.sh`): template placeholders resolved, JSON valid,
AGENTS.md line count ≤100, protocol doc contains all three sections, plus
shellcheck on script templates.

## 9. Open source packaging

The repo is public from the first commit, so hygiene is structural, not an
afterthought:

- **MIT LICENSE** and a README.md covering: what the harness approach is (with
  links to both pillar articles), quickstart for Claude users (install the
  skill) and for any-other-agent users (point your agent at
  `harness-protocol.md`), and the dogfood note (§8).
- **No sensitive or personal content anywhere**: templates use
  `{{placeholders}}` only; docs reference no private repos, keys, local
  paths, or third-party names beyond the published articles. `.gitignore`
  covers OS/editor droppings. Spec/plan docs describe the reference project
  generically.
- **Attribution**: the pillar articles are linked, not reproduced —
  original text stays with its owners.

## 10. Risks / open edges

- **Skill-format lock-in:** SKILL.md frontmatter is Claude's; mitigated by
  keeping all substance in the templates (portable markdown), with SKILL.md
  as thin orchestration.
- **Template drift vs pillar drift:** the pillars are blog posts frozen in
  time; the templates encode our *practice*, which this repo's own
  PROGRESS.md will evolve.
- **Verify-criterion quality** is the whole game: a weak `verify` field
  produces unfalsifiable features. The protocol doc's worked examples exist
  to teach this; the skill should refuse to write a feature without one.
