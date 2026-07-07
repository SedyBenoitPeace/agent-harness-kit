# agent-harness-kit — plugin packaging + harness audit

**Date:** 2026-07-07
**Status:** approved design, pending implementation plan

## Summary

Evolve this project from "a skill you copy into `~/.claude/skills`" into
**agent-harness-kit**: a Claude Code **plugin** that is the canonical home of
the full harness tool — the scaffolding skill, a new **harness-audit** skill
with a deterministic checker script, the agent-neutral protocol and templates,
and README guidance on feeding an existing PRD into the planning interview.

## Decisions (from brainstorm, 2026-07-07)

| Decision | Choice |
|---|---|
| Distribution | Claude Code plugin (marketplace + `/plugin install`) |
| Plugin / repo name | **agent-harness-kit** — "we are not planning anymore, we are giving a full harness tool"; room to grow (e.g. UX specs) later |
| Canonical home | The plugin repo **becomes canonical**: skills, templates, dogfood harness, and CI gate all live there. This repo stops being the source of truth. |
| Audit behavior | **Report + offer fix** — never fixes uninvited; fixing hands off to the setup skill's retrofit workflow |
| Audit checker reuse | **Plugin-only for now** — the checker is not copied into target repos; CI reuse is future work |
| PRD input | README + protocol must explain how to feed existing requirements (markdown, PDF, or HTML) into the planning interview |

## 1. Repository migration

**Mechanic (recommended): rename, don't recreate.** Rename
`SedyBenoitPeace/harness-planning-skill` → `SedyBenoitPeace/agent-harness-kit`
on GitHub. This preserves full history, PRs #1–#2, and GitHub auto-redirects
the old URLs (including the `agent-harness-template` README link, which still
gets updated to the new name). Creating a fresh repo and deprecating this one
achieves the same end state with more debris; only choose it if the old name
must remain visible.

> ✅ Confirmed by user 2026-07-07: rename on GitHub. **The local working-copy
> directory is NOT renamed** — it stays `~/Source/harness-planning-skill` so
> Claude Code conversation history (keyed by path) survives. Locally only
> `git remote set-url origin` changes (and GitHub redirects the old URL
> regardless).

After the rename, all remaining work happens in `agent-harness-kit` via the
normal harness loop (branch per milestone, PR integration).

## 2. Plugin packaging (milestone M7)

### Layout changes

```
agent-harness-kit/
├── .claude-plugin/
│   ├── plugin.json          ← new
│   └── marketplace.json     ← new (repo doubles as its own marketplace)
├── skills/                  ← renamed from skill/
│   ├── harness-setup/       ← renamed from harness-planning (see below)
│   │   ├── SKILL.md
│   │   └── templates/       (unchanged content)
│   └── harness-audit/       ← new (milestone M8)
│       ├── SKILL.md
│       └── scripts/check.sh
└── (everything else unchanged: docs/, scripts/e2e.sh, FEATURES.json, …)
```

### Skill rename: `harness-planning` → `harness-setup`

Consistent with the "full tool, not just planning" positioning. The skill
still runs the planning interview first — setup includes planning. All
references update: SKILL.md `name:`, README, FEATURES.json notes, the
announce line ("Using harness-setup to set up the agent harness").

### `plugin.json`

```json
{
  "name": "agent-harness-kit",
  "description": "Full long-running-agent harness toolkit: scaffold FEATURES.json / PROGRESS.md / plans / e2e gate into any repo, and audit repos for harness-readiness.",
  "version": "1.0.0",
  "author": { "name": "Stefano Rifici" },
  "homepage": "https://github.com/SedyBenoitPeace/agent-harness-kit",
  "repository": "https://github.com/SedyBenoitPeace/agent-harness-kit",
  "license": "MIT",
  "keywords": ["harness", "planning", "agents", "scaffolding", "audit"]
}
```

### `marketplace.json`

Single-plugin marketplace, `source: "./"` (repo root is the plugin root),
matching the format observed in installed plugins (engram, superpowers).

```json
{
  "$schema": "https://anthropic.com/claude-code/marketplace.schema.json",
  "name": "agent-harness-kit",
  "description": "Long-running-agent harness toolkit",
  "owner": { "name": "Stefano Rifici" },
  "plugins": [
    {
      "name": "agent-harness-kit",
      "source": "./",
      "description": "Scaffold and audit the long-running-agent harness",
      "version": "1.0.0",
      "category": "productivity"
    }
  ]
}
```

### Path fallout

`scripts/e2e.sh` (the repo gate) lints templates by path — update
`skill/harness-planning/…` → `skills/harness-setup/…` everywhere. README
layout diagram and quickstarts likewise.

### Install story (README quickstart, recommended path)

```
/plugin marketplace add SedyBenoitPeace/agent-harness-kit
/plugin install agent-harness-kit
```

Fallbacks stay: manual copy of `skills/harness-setup` into
`~/.claude/skills/`, the agent-harness-template repo, and the bare
`harness-protocol.md` for non-Claude agents.

**Note:** while the repo is private, marketplace install works only for the
authed owner. Flipping public is a separate, deliberate user decision (still
pending from 2026-07-03).

### M7 verify criteria

- `claude plugin` local install (marketplace add from local path) succeeds;
  both skills appear and are invocable.
- Repo gate `bash scripts/e2e.sh` exits 0 after the path updates.
- `plugin.json` and `marketplace.json` parse as JSON (add to gate).

## 3. harness-audit skill (milestone M8)

Two layers: a deterministic script that produces falsifiable, repeatable
results, and a thin SKILL.md judgment layer on top.

### 3.1 `scripts/check.sh` — the deterministic core

Bash + shellcheck-clean (same toolchain as the existing gate). Runs against
the current working directory. Prints one `PASS` / `FAIL` / `WARN` line per
check; exits non-zero iff any FAIL.

| Check | Severity on miss |
|---|---|
| `AGENTS.md` exists | FAIL |
| `AGENTS.md` ≤ 100 lines | FAIL |
| `FEATURES.json` exists and parses as JSON | FAIL |
| Every feature entry has `id`, `milestone`, `status` ∈ {`passing`,`failing`}, non-empty `verify` | FAIL |
| `PROGRESS.md` exists | FAIL |
| `scripts/e2e.sh` exists and is executable | FAIL |
| `docs/plans/active/` and `docs/plans/completed/` exist | FAIL |
| `docs/agents/harness-protocol.md` exists | FAIL |
| Protocol doc byte-identical to the plugin's shipped copy | WARN (drift) |
| Pointer `CLAUDE.md` exists | WARN |
| `--run-gate` flag: actually run `scripts/e2e.sh` | FAIL if non-zero (opt-in; gates can be slow) |

The script locates the shipped protocol copy relative to its own path
(`$(dirname "$0")/../../harness-setup/templates/harness-protocol.md`), so it
works from the plugin cache without configuration.

### 3.2 `SKILL.md` — the judgment layer

- **Announce:** "Using harness-audit to check harness-readiness."
- Run `check.sh` (ask before adding `--run-gate`), relay the report.
- Do the one check bash can't: read each `verify` field and flag
  unfalsifiable ones ("works correctly"-style), citing protocol §1.4.
- Summarize: ready / not ready, with the finding list.
- **Offer** (never auto-apply) to fix gaps by invoking `harness-setup` in
  retrofit mode. Trivial mechanical fixes (creating empty `docs/plans/*`
  dirs, re-copying the protocol doc) may be listed as one-command
  suggestions, still applied only on user yes.

### 3.3 Testing (wired into the repo gate)

- shellcheck on `check.sh`.
- Fixture tests: a **good fixture** built by scaffolding the templates into a
  temp dir → `check.sh` exits 0; **bad fixtures**, one per defect class
  (oversized AGENTS.md, entry with empty `verify`, missing `e2e.sh`, missing
  plans dirs, drifted protocol doc) → non-zero exit and the expected FAIL
  line. Fixtures generated by the test script, not stored.

### M8 verify criteria

- Gate runs the fixture suite green.
- `/harness-audit` in this repo itself reports the expected findings (this
  repo intentionally lacks `docs/agents/harness-protocol.md` — it is the
  source — so the audit run doubles as a bad-fixture smoke test).

## 4. PRD / requirements input (milestone M9)

Small, additive:

- **README**: new subsection under the quickstarts — "Already have
  requirements?" Explain: drop your PRD (markdown preferred; PDF or HTML also
  fine — the agent reads them) into the repo (e.g. `docs/PRD.md`) or attach
  it to the conversation, then say *"set up the harness using docs/PRD.md as
  the product requirements."* The interview then confirms gaps instead of
  asking from scratch.
- **`harness-protocol.md` §1.1**: one paragraph — if a requirements document
  is provided, extract answers to the interview questions from it and ask the
  human only what is missing or ambiguous; never skip the falsifiable-verify
  rule regardless of source.
- **`harness-setup/SKILL.md` step 2**: one line pointing at the same rule.

### M9 verify criteria

- Gate line-budget checks still pass (protocol addition is ~1 paragraph).
- README section exists and names all three input forms (md / PDF / HTML).

## 5. Out of scope (recorded for later)

- Flipping the repo public (user decision pending).
- Copying the checker into target repos for their CI (revisit if wanted).
- UX-spec templates and other "kit" growth areas the new name leaves room for.
- Updating `agent-harness-template` beyond fixing its README link to the
  renamed repo.

## 6. Milestone map

| Milestone | Content | Repo |
|---|---|---|
| M7 | Rename repo, plugin manifests, `skill/`→`skills/`, `harness-planning`→`harness-setup`, README install story, gate path updates | agent-harness-kit |
| M8 | harness-audit skill: check.sh + SKILL.md + fixture tests in gate | agent-harness-kit |
| M9 | PRD-input guidance: README + protocol §1.1 + SKILL.md line | agent-harness-kit |

One branch per milestone off master, features added in the same commit that
proves them passing, PR integration — per the harness's own rules.
