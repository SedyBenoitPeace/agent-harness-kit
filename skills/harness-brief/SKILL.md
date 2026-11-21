---
name: harness-brief
description: Use when the human gives a rough prompt or idea for something to build and wants it turned into a brief, spec or clear task description before planning or building — always load this skill for that, it holds the required brief format, the check script and the independent reviewer step.
---

# Harness Brief

Turns a rough prompt into a structured brief so planning (and unattended
runs) never stall on ambiguity nobody is awake to resolve. This skill
runs in the main conversation because it must ask the human questions.

**Announce at start:** "Using harness-brief to write a brief."

**Skip it** when the task points to an approved plan or outline from
another workflow: that is the brief already. Turn it into FEATURES.json
entries plus a plan section (protocol 1.1), then go to harness-run.

## Workflow

1. Read the rough prompt and, if a repo exists, skim `README.md`,
   `AGENTS.md` and the files it names. Look before asking: never ask
   what the repo already answers.
2. **Grill until nothing is open.** Facts come from the repo,
   decisions from the human: look up what the code, docs or git history
   can answer (stack, commands, file layout) and never ask it. Put each decision that
   would change what gets built or how it is proven (scope, a Done-when
   you cannot express as a command, a Needs-a-human action) to the human
   in numbered rounds: every question whose prerequisites are settled goes
   in the same round, numbered, each with a recommended answer worded so
   "yes" accepts it ("1. Export only paid invoices? Recommended: yes, drafts
   stay out."). The human may answer by number. Each answer can open new
   decisions; ask those next round. There is no question cap: keep going
   until no open decision remains. If the human says not to ask, take each
   recommended answer as a visible default in the brief.
   Domain terms: if GLOSSARY.md exists, word questions and the brief in its
   terms, add each new term as soon as its meaning is settled (term |
   definition | avoid), and when the human rejects an option for a reason
   later work must keep, offer an ADR in `docs/adr/` (copy `0000-template.md`).
3. Fill `templates/brief.md.tmpl` (path relative to this skill). Sections:
   Objective (one sentence) · Stage (prototype or production, and why in one
   line: it decides how much effort and checking the work deserves; when the
   prompt does not say, it is one of your questions) · Context · Deliverables · Non-goals ·
   Done when (each line a backticked command plus its expected result) ·
   Quality bar (a fetchable reference, or "gate is sufficient") ·
   Needs a human (actions the run must stop for) · Budget and stop
   condition · Automerge (yes or no: may the agent merge its own PR once it
   is green; ask the human, never default it to yes) · Checks (the acceptance checks, written now, before any code:
   one `### C<n> — title` per behaviour with Critical yes/no, numbered Steps,
   a Pass if a stranger can judge, and Evidence test, screenshot or human;
   planning copies each into its feature's `checks` as `<feature id>.<n>`) ·
   Open questions (must end up empty; only the
   reviewer's `- NOTE: ` lines may stay).
4. **Stranger test, before saving:** could someone build this without
   asking anything? If not, ask the human instead of saving — that is a
   gap, not an Open question to leave behind.
5. Save to `docs/briefs/<YYYY-MM-DD>-<slug>.md`, then run
   `bash scripts/check-brief.sh <brief>` (path relative to this skill).
   Any FAIL line: fix the brief (or ask the human) and re-run.
6. **Independent review, at most 2 rounds:** before every dispatch run
   `bash scripts/check-brief.sh <brief>` then `bash scripts/review-round.sh
   <brief>` (it counts rounds in the brief); on a `STOP` line from either,
   do not dispatch: show the human the remaining gaps. The cap holds
   however the reviewer runs (a subagent or a separate CLI process). Dispatch
   the `harness-brief-reviewer` agent (generate it with
   `../../scripts/gen-agents.sh <target-repo>` if the repo lacks it) giving
   it only the brief path — never your conversation (Codex: `spawn_agent`
   with `fork_turns: "none"`) — and, from round 2,
   the previous gap list, so round 2 re-checks those gaps instead of a fresh
   audit. Its first line is exactly `READY` or `GAPS`; only BLOCKING
   findings are gaps. On `GAPS`, ask the human about the numbered gaps,
   revise and go round again. On `READY`, run `review-round.sh --ready
   <brief>`. NOTE lines never start another round: copy them into the
   brief's Open questions, not into another round, as `- NOTE: ` lines.
   After 2 review rounds, stop. No subagent support: apply the same
   checklist yourself, reading only the saved file.
7. Show the human the saved path and hand off to planning
   (harness-initial-setup) — do not start building.

## Red flags

| Thought | Reality |
|---|---|
| "I'll park the unclear bit under Open questions" | Open questions must be empty; ask, or default it visibly. |
| "I'll ask which test runner they use" | That is a fact: read the repo. Ask only decisions. |
| "Enough questions, I'll guess the rest" | Save only when no open decision remains; ask another round. |
| "Done when: it works" | Every line is a command and its expected result. |
| "The check passed, so the brief is good" | The check is mechanical; the stranger test is yours. |
