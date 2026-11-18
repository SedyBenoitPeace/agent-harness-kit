# M49: talk to the run from the board

**Goal:** from the board page the human can ask the run to stop after the
current feature and leave a hint for a feature's next builder, without a
server and without steering a running builder.

**Why no message box:** the page is a static file (no server, cannot write
files), the CLIs take input only from their own terminal, and the kit
never steers a running builder. So the page talks to the *next* step,
through files the run already reads between features, and the human
writes those files with a command the page copies.

## M49-001

- **Hints file:** `.harness-run/hints/<id>.md`, free text written by the
  human. `skills/harness-run/scripts/feature.sh` prints it after the plan
  section as `== Human hint ==` (only when the file exists and is not
  empty), so the hint reaches the next builder brief (first build or
  rework) with no extra orchestrator tool call. The hint stays until the
  human deletes it; `run-start.sh` does not delete or archive `hints/`
  (a hint is about the feature, not one run).
- **STOP in harness-run:** the interactive harness-run's loop step 1 also
  stops (deleting the file) when `.harness-run/STOP` exists, as
  harness-continuous already does. One sentence in
  `skills/harness-run/SKILL.md`.
- **Board (`skills/harness-run/scripts/board.sh`):**
  - Header: a "Stop after current feature" button that copies
    `touch '<abs repo>/.harness-run/STOP'`; when STOP exists the header
    shows "stop requested" instead of the button.
  - Expanded row of a feature that is not `passing` or `skipped`: a
    textarea and a "Copy hint command" button that copies a command
    appending the text to `'<abs repo>/.harness-run/hints/<id>.md'`
    (`mkdir -p` first; the text single-quote-escaped so any input is
    safe in bash/zsh). An existing hint is shown above the box, and the
    row summary gets a "hint" tag.
  - Copy uses `navigator.clipboard.writeText`; when it is unavailable or
    fails, the command is shown selected in a read-only field with "copy
    it yourself". A short "copied, paste it in a terminal" confirmation.
  - The 5 s reload must not wipe a half-typed hint: unsent textarea text
    is saved in `sessionStorage` per id (try/catch) and restored after
    reload, and the reload is skipped while a textarea has focus.
- **Tests (`scripts/test-board.sh`, `scripts/test-run.sh`):** feature.sh
  prints the hint section only with a non-empty hint file; run-start.sh
  keeps `hints/`; board shows the STOP button, "stop requested" with
  STOP present, the hint box only on non-passing rows, an existing
  hint's text escaped, the absolute paths in the copy commands; the
  generated hint command, run through bash with text containing `'`,
  `$(...)`, backticks and a newline, writes that text verbatim;
  harness-run SKILL.md names `.harness-run/STOP`.
- Docs: README board section, the runs protocol template, CHANGELOG
  under the unreleased 3.21.0 entry (no version bump).
