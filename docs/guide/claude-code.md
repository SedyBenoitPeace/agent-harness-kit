# Claude Code plugin in depth

Part of the [agent-harness-kit guide](../../README.md).

## Quickstart — Claude Code (plugin, recommended)

```
/plugin marketplace add SedyBenoitPeace/agent-harness-kit
/plugin install agent-harness-kit
```

These skills come with it — invoke each as a slash command or in plain
English:

- **harness-initial-setup** — interview → PRODUCT.md + FEATURES.json → scaffold the
  whole harness. `/agent-harness-kit:harness-initial-setup` or _"set up the agent
  harness in this repo"_.
- **harness-session** — run one coding session with bounded, non-mutating
  context recovery and a concise gate report. `/agent-harness-kit:harness-session`,
  _"Implement M1-004 following the harness."_, or _"Continue the current
  harness feature."_ Only feature work runs the session: moving a file,
  formatting or an ordinary doc edit is a small task the agent does,
  checks once and stops (AGENTS.md says what counts). The session starts from a short brief (`context.sh`:
  the current milestone, the next feature's full entry and plan section,
  the newest PROGRESS entry, under 80 lines); FEATURES.json, PROGRESS.md,
  plans and docs are then read on demand with `grep` or `sed -n`, never
  whole. One read rule for every file: `grep -n` first, then `sed -n` ≤80
  lines; never `cat` a source file over 200 lines; one read per command, never
  chained. Builds, simulators and tests run through `quiet.sh <name> --
  <command>`, which keeps the full log in `.harness-run/logs/` and prints
  only the exit code, the log path, up to 40 error/fail/warning lines and
  the last 20 lines; `run-gate.sh` prints the same shape. A session that
  passes about 60 tool calls or 150k tokens of context commits what is
  safe, notes where to resume and ends `blocked · session budget`.
  Project-specific readiness checks are optional and live in the target
  repo's own `scripts/preflight.sh`.
- **harness-run** — work through many features in one conversation
  without its context growing: each feature runs as a harness-session in
  a fresh subagent, verified from the repo before the next starts;
  script-proven independent features run as parallel lanes. A step only
  you can do (a `Needs a human` note, a plan's `Before the run`) comes
  back as `scripts/wizard-<id>.sh`: it walks you through each step, then
  runs a check; it names secrets, never holds them.
  `/agent-harness-kit:harness-run` or _"Run the rest of milestone 3."_
- **harness-upgrade-structure** — for repos that already have a harness:
  bring them up to the structure the installed plugin ships, in one
  deterministic step. `/agent-harness-kit:harness-upgrade-structure`. See
  [Upgrading existing repos](upgrading.md#upgrading-existing-repos).
- **harness-continuous** — an unattended run: like harness-run, but a
  feature it cannot finish is skipped (work stashed, question recorded)
  instead of ending the run, and it finishes with a report in
  `docs/runs/`. Invoked by name: `/agent-harness-kit:harness-continuous`.
  See [Unattended runs](unattended-runs.md#unattended-runs).
  Both run skills open a live run board (`.harness-run/board.html`, the
  `BOARD:` line they print): one row per open feature with stage, agent, gate,
  time and cost. `HARNESS_BOARD_OPEN=0` stops it opening;
  `HARNESS_BOARD_OPEN_CMD` sets the opener. Click a row to expand it: its
  "Done when" (`verify`), `depends_on`, `paths`, effort and model, the
  feature's plan section (cut at 40 lines) and links to that plan and the
  briefs it mentions, then **All fields**: every key of the feature's
  FEATURES.json entry as written. A queued row's agent column shows its
  planned model and effort. The board can also talk back: it
  copies a `touch .harness-run/STOP` command (stop after the current feature;
  both run skills honour it) and, per open feature, a command that saves a
  hint to `.harness-run/hints/<id>.md`, which the next builder brief prints
  under `== Human hint ==`.
- **Independent evaluator** — features that opt in (`evaluate: "ui"` and a
  `bar` in FEATURES.json) end their session in `review`; harness-run then
  dispatches a separate, read-only `harness-evaluator` agent that returns
  `PASS` or `NEEDS_WORK` with evidence before the feature can become
  `passing`, and records `docs/verification/<id>.md`. It also checks the
  diff against `CODING_STANDARDS.md` / `CONTRIBUTING.md` when present and a
  fixed code-smell list, as `NOTE:` lines that never change the verdict.
  The builder and evaluator agents are generated for Claude Code, Copilot
  CLI and Codex CLI by `scripts/gen-agents.sh` from one source in
  `agents/`, at setup and by the upgrade; harness-run dispatches the builder by name, never a stand-in.
- **harness-issues** — GitHub issues as the place to write features:
  `/agent-harness-kit:harness-issues migrate` moves open features to issues,
  `… sync` brings them back into FEATURES.json (see Features in GitHub issues).
- **harness-status** — where the project stands: progress per milestone,
  last session, exact next feature. `/agent-harness-kit:harness-status` or
  _"what's the harness status?"_.
- **harness-retro** — after a run, one page of facts from
  `retro-facts.sh` and at most 5 ranked fixes (a gate check or a dated
  AGENTS.md rule), offered, never applied. _"retro the last run"_.
- **harness-audit** — check any repo's harness-readiness.
  `/agent-harness-kit:harness-audit` or _"audit this repo's harness"_.
  It also warns when a failing feature's `verify` needs something only you
  can give (a live session, your machine, a device, a push, a PR, an
  answer: that belongs in the plan's `## Before the run`), when a failing
  feature lacks `depends_on` or `paths` (it can never run as a parallel
  lane; the WARN names each one), and, for information only, when your global Codex, Claude
  Code or Copilot setup has a memory or workflow server or plugin that may
  add its own instructions to every session. It never edits your setup.
- **harness-handoff** — verify the session-end ritual (clean tree, gate
  status, logged session) and get a paste-ready prompt for the next agent,
  any vendor. It reuses the last green gate run (`GATE: green (last green
  run, unchanged)`), notes when the tree changed since, and runs the full
  gate only with `--run-gate`. `/agent-harness-kit:harness-handoff` or _"prepare the
  handoff for the next agent"_.

Update to the latest release:

```
claude plugin update agent-harness-kit
```

After an update, the next harness-session context report checks the
target repo against the shipped templates: an unbounded gate
(`GATE_OUTPUT: unbounded`) or an older protocol copy (`PROTOCOL: outdated`)
ends the report with `UPGRADE: offer`, and the agent proposes the
five-minute upgrade as its own commit before starting the feature.
Recopying the protocol brings in the orchestrated-run rules (§2.7), and
the same commit adds the harness-run line to AGENTS.md. The new
`depends_on` / `paths` fields in FEATURES.json are optional — absent fields stay sequential,
so existing repos keep working unchanged; harness-audit can propose
values for the remaining failing features, applied only on approval.
Give every feature both, with `paths` as narrow as you can: only a file
both features name (or one inside the other's folder or glob) keeps two
features out of parallel lanes, so a shared folder such as `test/` no
longer blocks them.
The evaluator is opt-in too: `evaluate` / `bar` are optional, and
harness-audit warns when features opt in but no evaluator agent file
exists (run `scripts/gen-agents.sh` to create them).

Manual fallback (no plugin): copy `skills/harness-initial-setup` into
`~/.claude/skills/`.
