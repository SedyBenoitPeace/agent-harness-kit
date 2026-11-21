# Repository layout

Part of the [agent-harness-kit guide](../../README.md).

## Repository layout

```
.claude-plugin/         plugin + marketplace manifests
skills/
├── harness-initial-setup/
│   ├── SKILL.md        planning/scaffolding orchestration (thin)
│   ├── scripts/add-ddd.sh        opt-in glossary + ADR folder (domain-driven design)
│   └── templates/
│       ├── harness-protocol.md   ★ the agent-neutral manual: session core + index
│       ├── harness-protocol-{planning,runs,maintenance}.md  read only when needed
│       ├── AGENTS.md.tmpl        entry point scaffold (≤100-line map)
│       ├── FEATURES.json.tmpl    scope/status source of truth
│       ├── PROGRESS.md.tmpl      session log
│       ├── ARCHITECTURE.md.tmpl  system diagram + invariants (living doc)
│       ├── dev.sh.tmpl           dev-environment boot
│       ├── e2e.sh.tmpl           the gate
│       ├── GLOSSARY.md.tmpl, adr-template.md  only with domain-driven design
│       └── pointer.md.tmpl       one-line CLAUDE.md/GEMINI.md pointer
├── harness-audit/
│   ├── SKILL.md        audit orchestration: report + offer fixes
│   └── scripts/check.sh          deterministic readiness checker
├── harness-issues/
│   └── scripts/issues.sh
├── harness-status/
│   ├── SKILL.md        status orchestration: read-only report
│   └── scripts/
│       ├── status.sh              deterministic progress/next-feature report
│       └── archive-features.sh    moves fully done milestones to the archive
├── harness-handoff/
│   ├── SKILL.md        handoff orchestration: ritual check + prompt relay
│   └── scripts/handoff.sh        session-end checks + next-agent prompt
├── harness-session/
│   ├── SKILL.md        session orchestration: bounded recovery + gate
│   └── scripts/
│       ├── context.sh             short session brief + PARALLEL lanes (--brief: protocol card)
│       ├── run-gate.sh            concise gate wrapper, full log retained
│       └── quiet.sh               any build/test command: log on disk, capped summary
├── harness-run/
│   ├── SKILL.md        multi-feature orchestrator: one subagent per feature
│   └── scripts/
│       ├── feature.sh             one feature's entry + plan section, pasted into the brief
│       ├── run-report.sh          end-of-run report from git + FEATURES.json
│       ├── run-start.sh           fresh run state, previous run archived
│       └── wait-result.sh         one blocking wait for a builder's result
├── harness-continuous/
│   └── SKILL.md        unattended run: skip what it cannot finish, then report
└── harness-upgrade-structure/
    ├── SKILL.md        runs upgrade.sh, explains, commits as its own commit
    └── scripts/upgrade.sh         idempotent upgrade of an existing harness
agents/
└── src/                neutral harness-builder / harness-evaluator roles
scripts/gen-agents.sh   emits the roles as Claude / Copilot / Codex agent files
```

## Dogfood

This repo is built with its own harness: scope in [`FEATURES.json`](../../FEATURES.json),
sessions in [`PROGRESS.md`](../../PROGRESS.md), plans in [`docs/plans/`](../../docs/plans/),
and a lint gate in [`scripts/e2e.sh`](../../scripts/e2e.sh) that validates the
templates themselves (JSON-after-substitution, shellcheck, agent-neutrality,
line budgets).
