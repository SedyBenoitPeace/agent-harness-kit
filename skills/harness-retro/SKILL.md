---
name: harness-retro
description: Use when a harness-run or harness-continuous run has finished and the human asks for a retro, a retrospective, "what went wrong", or "what should we fix in the harness" — runs a deterministic facts script and proposes at most 5 ranked fixes, each a gate check or a dated AGENTS.md rule, offered and never applied.
---

# Harness Retro

A cheap look back at one finished run, so the next run fails less. The
facts come from `scripts/retro-facts.sh` (path relative to this skill):
run it, never re-derive them by hand. Target: under 30k tokens per retro.

**Announce at start:** "Using harness-retro to review the last run."

## Workflow

1. Run `bash scripts/retro-facts.sh` from the target repo root. It prints
   one page (at most 80 lines): failed gates, retries, verdicts not PASS,
   budget stops, blocked features, cost, Decisions lines and whether each
   check's test failed before it passed. No run report in `docs/runs/`
   → say so and STOP.
2. Read only that page. Never read raw session logs (CLI transcripts are
   out of scope), and never a whole file: when a fact needs its cause,
   `grep -n` the source the page names, then `sed -n` at most 80 lines.
3. Find the causes. One run's bad luck is not a pattern: a fix needs a fact
   on the page behind it.
4. Propose fixes. At most 5 fixes, ranked by severity (most costly first),
   each in one of these categories:
   - **navigation**: the agent looked in the wrong place or read too much
     to find the right one (a missing pointer, an unclear path).
   - **automated check**: a mistake the gate could have caught (a
     check-first test that never failed, a red gate found late).
   - **tool economy**: money, tokens or retries spent for nothing (repeat
     dispatches, a budget stop, a slow command run often).
   - **no-op rule**: a rule that was followed and changed nothing, or was
     ignored and nothing broke: propose removing it.
   - **missing information**: the agent had to guess or wait on a human
     (a blocked feature, a Decisions line full of assumptions).

   Each fix is one of two kinds (protocol 3.4): a gate check (preferred:
   name the script and what it greps or runs), or an AGENTS.md rule ending
   with `(added <YYYY-MM-DD>)`, only for a failure seen more than once.
   Per fix: category, the fact from the page, the change, the file.
5. Offer, never apply. The human picks which fixes to make; each one is
   then its own feature or maintenance branch, not part of the retro.

## Red flags

| Thought | Reality |
|---|---|
| "I'll open the session transcripts to be sure" | Raw logs are out of scope. The page and a grep are enough. |
| "Here are 9 good ideas" | At most 5, ranked. Drop the weakest. |
| "This one doesn't fit a category" | Then it is not a harness fix. Leave it out. |
| "Small fix, I'll just add it to AGENTS.md now" | Offer, never apply. The human decides. |
