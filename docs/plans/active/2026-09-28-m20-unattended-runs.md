> **For agentic workers:** each task below is one harness coding session.
> Run it with the harness-session skill if it is installed; otherwise
> follow docs/agents/harness-protocol.md section 2. Do not load any other
> workflow skill or plugin to execute this plan.

# M20: Unattended runs — keep going past problems, then report

**Goal:** The human invokes the dedicated `harness-continuous` command
and walks away. The run keeps going past features it cannot finish instead of
stopping at the first one, and when it ends it leaves a script-built
run report: what got done, what was skipped and the question each skip
needs answered, what was not started and why. Works in Claude Code,
Codex CLI and Copilot CLI with their normal permission settings — no
--yolo / skip-all-permissions flags. Released as plugin 1.11.0.

**Why:** Today harness-run stops at the first blocked feature, at the
milestone boundary, or at 10 features. Unattended, one blocked feature
wastes the rest of the run, and the human has to reconstruct what
happened from PROGRESS.md and git log.

**Out of scope:** containers, sandboxes, scheduling, API-key handling,
cost caps beyond the feature cap. Permission setup stays each CLI's own
(documented in M20-004, never automated).

## M20-001 — status.sh --skip

- `status.sh --skip FILE` (one id per line) excludes from NEXT:
  - the listed ids;
  - every failing feature that declares a listed id in `depends_on`,
    transitively;
  - every failing feature WITHOUT `depends_on` that comes after a
    listed id in selection order (unknown dependencies are assumed —
    so repos without `depends_on` behave exactly like today's stop).
- Prints one `SKIPPED: <id> — <why>` line per excluded id (listed, or
  "depends on <id>"). `NEXT: none` when nothing eligible is left.
- `context.sh` accepts and passes `--skip` through.
- Without `--skip`, output is byte-identical to today (fixture-proven).

## M20-002 — harness-continuous: its own command

A new skill, `skills/harness-continuous/`, so a continuous run is its
own command — no trigger word, no mode flag. Invoking it starts the
run; the human may add a cap ("cap 20") or a milestone range
("through M21"). It reuses harness-run's dispatch/verify steps by
reference and adds only the continuous rules below. `harness-run` stays
interactive and unchanged, and points to harness-continuous.

- Never asks the human anything during the run.
- Run state lives in `.git/harness-run/` (never committed, no
  .gitignore needed): `skip` (ids), `STOP` (the human creates it to end
  the run gracefully after the current feature), `start` (start commit).
- **Skip, don't stop,** when a feature's session is `blocked`, its gate
  is red, or (after M18) the evaluator returns NEEDS_WORK twice:
  1. leftover changes → `git stash push -u -m "harness-run skip <id>"`
     (never discarded; recoverable);
  2. append to the feature's `notes`: "Unattended <date>: skipped —
     <reason>. Question for the human: <one question>";
  3. commit FEATURES.json only ("harness-run: skip <id>");
  4. add the id to `.git/harness-run/skip`; loop using
     `status.sh --skip`.
- **Stop** (then write the report) when: NEXT none after skips · the
  feature cap (default 10, the human may name another) · the STOP file
  exists · a baseline problem (dirty tree at start, exit 2/3,
  UPGRADE offer, PREFLIGHT line, red baseline gate) · a dispatch that
  produced neither a commit nor a recorded skip.
- **Milestone boundary:** stop there by default. If the start
  instruction names a range ("through M21"), at each boundary create
  the next milestone's branch from the current one (stacked branches,
  no push) and continue.
- Parallel lanes keep working; a blocked lane becomes a skip.

## M20-003 — run-report.sh

- `skills/harness-run/scripts/run-report.sh <start-commit>
  [--skip FILE] [--stop-reason TEXT]` writes
  `docs/runs/<YYYY-MM-DD-HHMM>.md` and prints its path.
- Built only from git log (commits since start naming ids),
  FEATURES.json (titles, statuses, notes), the skip file and the stop
  reason — no model calls, zero tokens. harness-continuous runs it as
  the last step of every run and commits it.
- Sections: **Summary** (start, end, stop reason, counts) · **Done**
  (id, title, commit) · **Skipped** (id, reason, the question) · **Not
  started** (id, and why: depends on a skipped id, cap, milestone
  boundary) · **Branches** (created/used).

## M20-004 — Docs and release 1.11.0

- Protocol section 2 documents continuous runs: the harness-continuous
  command, skip and stop rules, the STOP file, the report.
- README lists harness-continuous among the skills. "Unattended runs"
  section: how to invoke it in each CLI (syntax field-tested, not
  assumed) and how to set permissions per CLI so it does not stall on
  prompts, without --yolo,
  --dangerously-skip-permissions or --allow-all:
  - Claude Code: pre-approve the gate, test, git add/commit commands;
    deny push and destructive commands.
  - Codex CLI: `--sandbox workspace-write --ask-for-approval never`
    (writes limited to the repo; blocked actions fail instead of
    prompting).
  - Copilot CLI: `--allow-tool` for the specific commands,
    `--deny-tool` for push; `--no-ask-user`.
- Versions 1.11.0.

## Decision log

- 2026-09-28 — Owner: unattended runs now, without a sandbox, a
  generated report file name, or "night" naming; no skip-all-permissions
  flags. Safety comes from the CLI's own permission settings, a branch,
  and never discarding work (stash, not reset).
- 2026-09-28 — Skip needs dependency knowledge. Features without
  `depends_on` are assumed to depend on everything before them, so a
  repo that never declared dependencies stops exactly as today — safe
  by default, and declaring `depends_on` is what unlocks continuing.
- 2026-09-28 — Run state in `.git/harness-run/`: invisible to git, no
  .gitignore changes in target repos, survives across sessions.
- 2026-09-28 — The report is committed under docs/runs/ so it travels
  with the branch and shows up in review; it is script-built so reading
  a run costs nothing.
- 2026-09-28 — M20-002 depends on M18-002 so "evaluator said
  NEEDS_WORK twice" is a skip reason from day one.
- 2026-09-29 — Owner: a dedicated command instead of a trigger word.
  A separate skill is also the most portable command form: all three
  CLIs load skills, so one SKILL.md serves Claude Code, Codex CLI and
  Copilot CLI. The exact invocation syntax per CLI is field-tested in
  M20-004 rather than assumed.
- 2026-10-01 — M20-002: each run starts with an empty `skip` file and
  deletes a leftover `STOP`, so a rerun retries earlier skips (their
  notes carry the question; stashes stay recoverable). The cap counts
  every dispatched feature, skips included.
