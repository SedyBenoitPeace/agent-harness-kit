# M60: Lean retro, wizard, README as a guide

> **For agentic workers:** each task below is one harness coding session.
> Run it with the harness-session skill if it is installed; otherwise
> follow docs/agents/harness-protocol.md section 2. Do not load any other
> workflow skill or plugin to execute this plan.

Goal: take the best rules from github.com/mattpocock/skills (MIT) into the
kit's own files, without adding his skills to the kit. Skills that overlap
or need a human present (grilling, improve-codebase-architecture,
prototype, codebase-design, teach) are installed locally by the owner, not
shipped. Owner review: thread "Map Matt Pocock skills onto the kit",
2026-11-21.

Every feature that changes behaviour updates README.md in the same commit
(check-readme.sh enforces it per release). M60-004 then restructures the
README into a guide.

Part of M57–M60 (ideas borrowed from mattpocock/skills).

## Before the run

Nothing: every verify is provable from the repo.

## M60-001 retro-facts.sh

Deterministic, no model: reads the run report, PROGRESS Decisions lines and
`.harness-run/logs/`; prints at most 80 lines. Includes the TDD-order check
(did each check's test fail in a logged run before it passed).

## M60-002 harness-retro skill

Runs retro-facts.sh and reads only its page (target: under 30k tokens per
retro). At most 5 fixes, ranked, in fixed categories; each is a gate check
or a dated AGENTS.md rule (protocol 3.4). Offers, never applies. Raw CLI
session logs stay with the private Harness Superfan project.

## M60-003 Wizard for Needs a human

From his wizard: on a blocked Needs-a-human feature or a Before-the-run
item, write `scripts/wizard-<id>.sh` from a template: one prompt per step,
a check at the end, no secret values.

## M60-004 README as a guide

"What do I run when" table first, one short section per skill, deep detail
moved to `docs/guide/`. Under 400 lines (today 857). check-readme.sh also
searches `docs/guide/`.

## Decision log

- 2026-11-21: Distil rules into kit files; never invoke external skills
  from builders (protocol 2.4; runs must not differ by what is installed).
- 2026-11-21: Skipped from his repo: to-spec, to-tickets, implement,
  implement-spec, research, handoff, to-questionnaire (overlap or not kit
  scope). Triage is covered by M59 bug intake.
- 2026-11-21: Keep the word "session" (his vocabulary avoids it).
- 2026-11-21: DDD opt-in, off by default; mandatory only on the owner's repos.
