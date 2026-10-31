# M42: brief review converges

**Goal:** a brief review ends in at most 2 rounds, whatever runs the
reviewer, and a brief whose only flaws are nits gets `READY`.

## Evidence (one private run, 2026-10-31, numbers only)

- One brief went through 13 review rounds, every one `GAPS`, with 11, 5,
  5, 4, 4, 2, 1, 3, 2, 3, 2 and 2 gaps found per round; the brief grew from
  about 7 KB to 18.5 KB. About $0.24 and 100k tokens per round.
- All rounds came from one worker with no Agent tool, which started the
  reviewer as a separate CLI process 15 times in 24 minutes. SKILL.md step
  6 already said "After 2 review rounds, stop"; the worker had it in
  context and kept going.

Three causes: the cap is prose only and each reviewer run is stateless;
the reviewer's bar is unbounded (any finding is `GAPS`); every fix adds
lines that the next fresh reviewer audits again, so rounds never converge.

## M42-001 — mechanical cap, severity bar, re-check

- `skills/harness-brief/scripts/review-round.sh <brief>`: keeps
  `<!-- Review rounds: N -->` on line 2 of the brief (above every section,
  so it never lands in Open questions); exits 3 with `STOP: round cap
  reached, show remaining gaps to the human` instead of starting round 3;
  `--ready` marks the brief READY. The human resets by deleting the line.
- check-brief.sh, which step 6 already runs before every round, FAILs with
  the same STOP text at 2 recorded rounds (not once READY), so skipping the
  new script does not skip the cap.
- Reviewer (`agents/src/harness-brief-reviewer.md`): a gap must be
  BLOCKING (two builders differ, self-contradiction, Done-when not
  runnable or observable, missing Needs-a-human); everything else is a
  `NOTE:` that does not prevent `READY`; at most 5 gaps, most severe first.
  From round 2 it gets the previous gap list and only re-checks it, plus
  BLOCKING problems on changed lines.
- SKILL.md step 6: runs both scripts, passes the previous gap list, records
  READY, and copies NOTEs into Open questions as `- NOTE: ` lines;
  check-brief.sh allows those lines (and only those).
- gen-agents.sh copies the source body into all three CLIs' files, so the
  Codex and Copilot reviewers get the same rules; test-agents.sh asserts it
  on each generated file.
- Verify: test-brief.sh (round cap, check-brief STOP, READY, NOTE lines,
  nits-only fixture passes check-brief, step 6 wording); test-agents.sh.

## Decision log

- 2026-10-31: counter in the brief, not a sidecar file: it travels with the
  brief and the check that already runs every round can read it.
- NOTEs go into Open questions as the owner asked, but Open questions had
  to be empty for check-brief.sh; it now allows `- NOTE: ` lines only, so
  a real question still fails the check.
- A READY brief also gets a STOP from review-round.sh: nothing left to review.
