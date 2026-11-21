# M58: Evaluator checks standards; one check at a time

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

## M58-001 Evaluator standards pass

From his code-review: read CODING_STANDARDS.md / CONTRIBUTING.md if
present, plus a fixed smell baseline (mysterious name, duplicated code,
feature envy, data clumps, primitive obsession, speculative generality,
shotgun surgery). Findings are `NOTE:` lines; acceptance-verdict.sh still
decides PASS or NEEDS_WORK.

## M58-002 One check at a time

From his tdd ("horizontal slicing" anti-pattern): one check's test, watch
it fail, make it pass, next check. Builder file and protocol 2.4 only.

## Decision log

- 2026-11-21: Distil rules into kit files; never invoke external skills
  from builders (protocol 2.4; runs must not differ by what is installed).
- 2026-11-21: Skipped from his repo: to-spec, to-tickets, implement,
  implement-spec, research, handoff, to-questionnaire (overlap or not kit
  scope). Triage is covered by M59 bug intake.
- 2026-11-21: Keep the word "session" (his vocabulary avoids it).
- 2026-11-21: DDD opt-in, off by default; mandatory only on the owner's repos.
