---
name: harness-brief
description: Use when the human gives a rough prompt or idea for something to build and wants it turned into an unambiguous brief before planning — asks at most three questions about real ambiguities, then writes docs/briefs/<date>-<slug>.md that a stranger could build from without asking anything.
---

# Harness Brief

Turns a rough prompt into a structured brief so planning (and unattended
runs) never stall on ambiguity nobody is awake to resolve. This skill
runs in the main conversation because it must ask the human questions.

**Announce at start:** "Using harness-brief to write a brief."

## Workflow

1. Read the rough prompt and, if a repo exists, skim `README.md`,
   `AGENTS.md` and the files it names. Look before asking: never ask
   what the repo already answers.
2. Ask at most three questions, one at a time, only about real
   ambiguities that would change what gets built or how it is proven
   (scope, a Done-when you cannot express as a command, a Needs-a-human
   action). No questions about things you can default; state the default
   in the brief instead.
3. Fill `templates/brief.md.tmpl` (path relative to this skill). Sections:
   Objective (one sentence) · Context · Deliverables · Non-goals ·
   Done when (each line a backticked command plus its expected result) ·
   Quality bar (a fetchable reference, or "gate is sufficient") ·
   Needs a human (actions the run must stop for) · Budget and stop
   condition · Open questions (must end up empty).
4. **Stranger test, before saving:** could someone build this without
   asking anything? If not, ask the human instead of saving — that is a
   gap, not an Open question to leave behind.
5. Save to `docs/briefs/<YYYY-MM-DD>-<slug>.md`, then run
   `bash scripts/check-brief.sh <brief>` (path relative to this skill).
   Any FAIL line: fix the brief (or ask the human) and re-run.
6. **Independent review:** dispatch the `harness-brief-reviewer` agent
   (generate it with `../../scripts/gen-agents.sh <target-repo>` if the
   repo lacks it) giving it only the brief path — never your
   conversation. Its first line is exactly `READY` or `GAPS`. On `GAPS`,
   ask the human about the numbered gaps, revise, re-run check-brief.sh
   and review again. After 2 review rounds, stop: show the human the
   remaining gaps instead of looping. No subagent support: apply the same
   checklist yourself, reading only the saved file.
7. Show the human the saved path and hand off to planning
   (harness-setup) — do not start building.

## Red flags

| Thought | Reality |
|---|---|
| "I'll park the unclear bit under Open questions" | Open questions must be empty; ask, or default it visibly. |
| "A fourth question would help" | At most three. Default the rest and say so in the brief. |
| "Done when: it works" | Every line is a command and its expected result. |
| "The check passed, so the brief is good" | The check is mechanical; the stranger test is yours. |
