# Efficient Coding Sessions — Design

## Problem

The plugin covers harness setup, audit, status, and handoff, but has no skill that owns the coding-session loop. When a user asks an agent to implement a feature such as `M1-003`, the agent must manually recover context from the installed protocol, parse repository state, decide whether the worktree represents a clean start or interrupted work, and consume the project's gate output directly.

A field session on Appointly exposed four costs:

1. entire harness documents and feature histories were loaded instead of a bounded session view;
2. an untracked partial implementation was mistaken for a clean start and sent through the full baseline gate;
3. local-service and unrelated integration lifecycle failures were explored repeatedly despite being outside the selected feature;
4. successful gates streamed thousands of low-value warning lines into agent context.

The result was correct but materially slower and more token-intensive than the feature justified.

## Goal

Add a plugin-owned `harness-session` workflow that deterministically prepares and executes one coding session with bounded context, explicit interrupted-work handling, optional project preflight, and concise gate reporting, without copying generic orchestration scripts into every target repository.

## Non-goals

- Do not weaken the one-feature-per-session rule.
- Do not skip the final full gate.
- Do not infer whether ambiguous dirty files belong to the selected feature.
- Do not encode stack-specific knowledge such as PostgreSQL, Redis, Bull, Docker, NestJS, or Jest in the plugin.
- Do not replace the target repository's `scripts/e2e.sh`; it remains the health contract.
- Do not make `harness-status` writable or duplicate its feature-selection logic.
- Do not change `harness-handoff` semantics.

## User-facing lifecycle

```text
harness-setup    create the harness
harness-audit    validate and repair harness structure
harness-status   report where the project stands
harness-session  execute exactly one selected feature efficiently
harness-handoff  verify closeout and package the next-agent prompt
```

The new skill triggers on requests to implement, continue, carry on, or execute a feature in a harnessed repository, including prompts such as `Implement M1-004 following the harness`.

## Architecture

The skill follows the repository's established two-layer pattern:

```text
skills/harness-session/
├── SKILL.md                 judgment and coding-session workflow
└── scripts/
    ├── context.sh           deterministic bounded recovery
    └── run-gate.sh          deterministic gate capture/reporting

scripts/test-session.sh      isolated fixture tests for both scripts
```

### `context.sh`

Usage:

```bash
bash context.sh [TARGET_DIR]
```

The script:

1. delegates milestone totals, next-feature selection, verify text, and newest progress extraction to the existing `harness-status/scripts/status.sh`;
2. adds `git log -5 --oneline`;
3. prints the current branch and `git status --short`;
4. lists active plan files containing the selected feature id, without dumping their contents;
5. reports whether an executable target-owned `scripts/preflight.sh` exists.

It performs no writes and no prompts. It uses the existing exit-code contract: `0` report produced, `2` broken harness, `3` uninitialized harness.

### Interrupted-work judgment

`SKILL.md`, not the script, owns classification:

```text
clean worktree
  run baseline gate

dirty worktree, changes clearly match selected feature and its plan
  report CONTINUING INTERRUPTED FEATURE
  inspect the focused diff
  run the feature's focused verification first
  do not claim a clean baseline existed

dirty worktree, unrelated or ambiguous ownership
  stop and ask the human before modifying anything
```

A selected-feature continuation still requires the final full gate and normal closeout. The exception changes only the impossible clean-baseline step; it does not lower completion evidence.

### Optional project preflight

Stack-specific dependency checks remain target-owned. If an executable `scripts/preflight.sh` exists, `harness-session` runs it before the baseline/focused test. A non-zero result blocks work with the script's output. If the file is absent, the session continues; the plugin never guesses required services.

The setup templates do not scaffold a meaningless generic preflight file. Projects add it only when their environment has a useful deterministic readiness check.

### `run-gate.sh`

Usage:

```bash
bash run-gate.sh baseline [TARGET_DIR]
bash run-gate.sh final [TARGET_DIR]
```

The wrapper executes the target's existing `bash scripts/e2e.sh`, captures complete stdout/stderr in `${TMPDIR:-/tmp}/agent-harness-kit-gate-<phase>-<timestamp>.log`, and preserves the gate's exit code.

On success it prints only:

```text
GATE: green (baseline|final)
DURATION_SECONDS: <integer>
FULL_LOG: <path>
<last meaningful summary lines, capped at 20>
```

On failure it prints `GATE: red`, duration, full-log path, and the final 80 lines before returning the original non-zero status. The skill reads more of the saved log only when those lines do not expose the failure.

This is presentation-layer compression, not test reduction: the target gate runs unchanged and the complete evidence remains available during the session.

### Known non-blocking warnings

When a command exits zero, the session does not branch into fixing a warning that is explicitly tracked by another failing or deferred feature, unless the selected feature's `verify` criterion requires eliminating it. The warning is recorded in `PROGRESS.md`. Non-zero commands remain blockers regardless of backlog status.

## Closeout

The skill preserves the current protocol:

1. run the final full gate through `run-gate.sh final`;
2. flip only the selected feature to `passing` when its verify criterion is proven;
3. update architecture when technical shape changed;
4. commit explicit paths with the feature id;
5. prepend a `PROGRESS.md` entry;
6. use `harness-handoff` when switching agents.

## Testing

`scripts/test-session.sh` uses temporary git repositories and fake gates to prove:

- uninitialized and malformed harnesses preserve exit codes `3` and `2`;
- next-feature selection comes from `harness-status` output;
- only the newest progress entry and five recent commits are printed;
- clean and dirty worktrees are reported without modifying them;
- active plans mentioning the selected id are listed;
- optional preflight presence is reported;
- successful gates produce bounded output while retaining the full noisy log;
- failed gates show the failure tail and preserve the underlying exit code;
- baseline and final phase labels are validated.

The root gate shellchecks both scripts, runs `test-session.sh`, validates `SKILL.md` frontmatter, and confirms protocol/README coverage.

## Decisions

- **New skill rather than extending `harness-status`:** status is deliberately read-only and user-facing; a coding session has different triggers, writes, and judgment. `harness-session` delegates selection to status instead of duplicating it.
- **Plugin-owned wrapper rather than target `e2e.sh --summary`:** existing repositories gain the behavior when the plugin updates, and the target's gate contract stays unchanged.
- **No generic preflight template:** service requirements are project-specific; only the optional executable contract is portable.
- **Dirty-state classification stays in `SKILL.md`:** filenames alone cannot safely prove ownership. The script reports facts; the agent applies the plan and asks when ambiguous.
- **Final gate remains mandatory:** optimization targets context and redundant work, not confidence.
- **Release as 1.6.0:** the new lifecycle skill is additive functionality and plugin caches are version-keyed.
