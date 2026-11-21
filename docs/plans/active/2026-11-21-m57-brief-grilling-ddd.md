# M57: Brief grills; domain-driven design opt-in

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

## M57-001 Brief grills until nothing is open

Rewrite harness-brief step 2: drop the three-question cap (M19, no
recorded reason). Ask in numbered rounds; each question has a recommended
answer worded so "yes" accepts it; ask every question whose prerequisites
are settled in one round. Facts come from the repo, decisions from the
human. Save only when no open decision remains. Keep the stranger test,
check-brief.sh and the 2-round reviewer cap unchanged.

## M57-002 Domain-driven design opt-in

Setup asks once: "Use domain-driven design (glossary + ADRs)?" Default no.
Yes: `GLOSSARY.md` (term, definition, avoid), `docs/adr/0000-template.md`,
one AGENTS.md pointer line (template stays within 70 lines). upgrade.sh
adds the same only with an explicit flag. The owner turns it on for his
own repos.

## M57-003 Glossary used by brief, builder, evaluator

Conditional lines only ("if GLOSSARY.md exists"). Brief adds settled terms
and offers an ADR for a load-bearing rejected option. Builder uses glossary
terms in test titles and names. Evaluator reports a contradicting term as a
NOTE. Protocol core stays at or under 150 lines.

## M57-004 README credit and recommended local skills

Credits: mattpocock/skills as inspiration. New short section: the five
local skills, one line each on when to call them and why they are not in
the kit.

## Decision log

- 2026-11-21: Distil rules into kit files; never invoke external skills
  from builders (protocol 2.4; runs must not differ by what is installed).
- 2026-11-21: Skipped from his repo: to-spec, to-tickets, implement,
  implement-spec, research, handoff, to-questionnaire (overlap or not kit
  scope). Triage is covered by M59 bug intake.
- 2026-11-21: Keep the word "session" (his vocabulary avoids it).
- 2026-11-21: DDD opt-in, off by default; mandatory only on the owner's repos.
