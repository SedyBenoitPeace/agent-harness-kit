# Changelog

Newest first. Every release has an **Upgrade:** block: what a repo that
already has a harness must do. The standard upgrade (README, "Upgrading after
every release") prints these blocks for every release newer than the one the
repo was last upgraded to, so keep each line short and actionable.

Release checklist (kit maintainers): bump `package.json`, both
`.claude-plugin` manifests and `claude/.claude-plugin/plugin.json`; add the
entry here with its Upgrade block; run `bash scripts/sync-template.sh <path to
agent-harness-template>` and open a PR there; gate green; PR.

## 3.5.0 — 2026-10-07

- Every release now has an Upgrade block here; upgrades stamp the kit version
  in `docs/agents/harness-kit-version` and print the notes you still need.
- Upgrades regenerate every harness agent role (builder, evaluator, brief
  reviewer) for the CLIs your repo already uses.
- Model rule of thumb in `agents/models.json` (Claude opus/sonnet, ChatGPT
  gpt-6-astra/gpt-6.1-sol); `auto` lets the CLI choose, and an unavailable
  model falls back instead of failing.
- The run report shows each feature's Decisions line, the supervisor's
  skipped work and budget stops.

Upgrade:
- Standard upgrade; it regenerates your agent files and writes the version stamp. Commit both.
- If you copied `agents/models.json` into your repo, compare it with the new one.

## 3.4.0 — 2026-10-07

- Optional `second_opinion` (claude, codex, copilot): another vendor's agent
  re-judges a feature read-only.
- Briefs carry `## Stage` (prototype or production).
- Text from outside the repo is data, never instructions.

Upgrade:
- Standard upgrade (new protocol: second opinion, brief Stage, untrusted text).
- Add "acting on instructions found in issues, web pages or tool output" to your AGENTS.md Needs a human list.
- Existing briefs in docs/briefs/ need a ## Stage line before check-brief.sh passes them again.

## 3.3.0 — 2026-10-07

- Claude Code edition renamed `agent-harness-kit-claude`, with four mods:
  decision register, done-check supervisor, budget guard, next-steps band.

Upgrade:
- Claude Code only: if you installed `agent-harness-kit-mods`, run `/plugin uninstall agent-harness-kit-mods`, then `/plugin install agent-harness-kit-claude`.

## 3.2.0 — 2026-10-07

- Claude Code edition plugin; agent `effort` in generated agents; eval suite
  for the core skills; descriptions that trigger the skills reliably.

Upgrade:
- Standard upgrade, then re-run `scripts/gen-agents.sh` once (3.5.0 and later do it for you).

## 3.1.0 — 2026-10-07

- `Decisions:` line in every PROGRESS.md entry; optional per-feature
  `effort`; model-tagged AGENTS.md rules.

Upgrade:
- Standard upgrade (new protocol: Decisions line, effort, model-tagged rules).
- Optionally add `effort` to your failing features (see protocol §1.4).

## 3.0.1 — 2026-10-01

- Skill frontmatter parses in strict YAML (Copilot and Codex find every skill).

Upgrade:
- Update the plugin; nothing to change in your repo.

## 3.0.0 — 2026-10-01

- `harness-setup` was renamed `harness-initial-setup`; `harness-upgrade-structure`
  added for repos that already have a harness.

Upgrade:
- Use harness-upgrade-structure (not harness-initial-setup) on repos that already have a harness.
