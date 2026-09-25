# M17: Orchestrated multi-feature runs — Implementation Plan

Each task below is one harness coding session: use harness-session if
installed, else protocol §2. Never another workflow skill.

**Goal:** A `harness-run` skill lets one agent conversation work through
many features without its context growing per feature: the main chat
orchestrates, each feature runs in a fresh built-in subagent, and
independent features can run in parallel as teammates. Released as
plugin 1.8.0.

**Why:** Field use — running several features in one conversation fills
the context (diffs, gate tails, reasoning pile up), so the human runs
every feature by hand with `/clear` in between. Sessions already recover
everything from the repo, so a fresh context per feature is free; what
was missing is something that starts them.

## Tasks

### M17-001 (gate-first): sequential orchestrator
- New `skills/harness-run/SKILL.md`: loop — `context.sh` → NEXT; none →
  done; dispatch the agent's own built-in subagent with "harness-session
  for <id>, inline"; confirm via `status.sh` that <id> flipped and the
  tree is clean; otherwise surface the subagent's blocker to the human
  and stop. Stop at milestone boundary or a cap (default 10).
- No subagent tool → run one normal session and stop.
- harness-session: a fixed end-of-session summary block
  (`SESSION: <id> · <passing|blocked> · gate <green|red> · <commit|reason>`);
  inside a subagent, execution mode is always inline.
- The orchestrator never reads diffs or gate logs itself.
- Gate: harness-run frontmatter; greps for the summary contract,
  `status.sh` verification, the cap and the no-subagent fallback.

### M17-002 (gate-first): parallel lanes
- FEATURES.json gains optional `depends_on` (ids) and `paths` (globs).
- `context.sh` prints `PARALLEL: <id> <id> …` (max 3): failing features
  with no dependency between them and declared, non-overlapping `paths`
  prefixes; otherwise `PARALLEL: none`. Missing fields → sequential.
- harness-run: each teammate in its own git worktree/branch; teammates
  implement + run their own verify + commit, and never touch
  FEATURES.json / PROGRESS.md. The orchestrator merges, runs one full
  gate, flips the statuses, writes one PROGRESS.md entry. Merge conflict
  → redo that feature sequentially after the other lands.
- Gate: `test-session.sh` fixtures — disjoint paths → PARALLEL listed;
  dependency, overlap, or missing fields → none; cap of 3; the gate's
  FEATURES.json check accepts the new optional fields.

### M17-003: documentation and planning interview
- Protocol §1 planning asks the two optional questions (depends on?
  paths touched?); §2 gains "Orchestrated runs". FEATURES.json.tmpl
  `_instructions` documents the fields. README lifecycle adds
  harness-run. AGENTS.md.tmpl names it. Version bump to 1.8.0.
- Existing repos: the recopied protocol (existing `PROTOCOL: outdated`
  upgrade offer) carries the new rules; the same upgrade commit adds the
  harness-run line to AGENTS.md. harness-audit suggests `depends_on` /
  `paths` for the remaining failing features, human approves. Absent
  fields stay legal (sequential). README update section says so.

### Chore (no feature id): drop third-party plan headers
- Remove the `REQUIRED SUB-SKILL` header lines from the four completed
  plans so no agent opening history follows them. Own commit.

## Decision log

- 2026-09-25 — Orchestrator over an outer `claude -p` loop: sessions stay
  inside the agent UI where the human can watch and open them, and
  blockers come back to an interactive chat. No `AGENT_CMD` needed.
- 2026-09-25 — Parallelism is declared at planning time and computed by
  script, never inferred by the agent at runtime; absent fields mean
  sequential, so existing repos are unchanged.
- 2026-09-25 — Only the orchestrator writes FEATURES.json / PROGRESS.md,
  removing the shared-file conflict that ruled out parallel worktrees.
- 2026-09-25 — Outer headless loop deferred until someone needs
  unattended overnight runs.
