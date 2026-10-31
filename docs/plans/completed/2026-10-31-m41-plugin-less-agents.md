# M41: harnessed repos work without the kit plugin

**Goal:** an agent with no kit plugin (an ADE built on Claude Code, Gemini
CLI) knows a repo is harnessed and follows it, without the human saying so.

## Evidence

In HumanLayer (built on Claude Code, no kit plugin) the owner had to say the
repo used the harness before the agent followed it; afterwards it did well.
The repo's `CLAUDE.md` said "See [AGENTS.md](./AGENTS.md)…". Claude Code docs
(code.claude.com/docs/en/memory, "AGENTS.md"): Claude reads AGENTS.md only
when no CLAUDE.md exists, and a CLAUDE.md that tells Claude in words to read
AGENTS.md means "Claude sees AGENTS.md only if it decides to open the file";
the fix is an `@AGENTS.md` import. The kit's `pointer.md.tmpl` was that
link. With the plugin the skill descriptions hid the gap. The M40 plan's
"read by Claude Code through the CLAUDE.md pointer" was wrong for the same
reason. That repo's AGENTS.md, adapted by hand, also never said "harness".

## M41-001 — import, declare, allow a skip

- pointer.md.tmpl: `@AGENTS.md` plus one line (CLAUDE.md and GEMINI.md).
- AGENTS.md.tmpl (70/70): the declaration says "plugin or not"; the plugin
  paragraph says the six steps are the protocol and the plugin speeds them
  up; a skip line after the feature-work paragraph: "just build it" means no
  brief or plan, but FEATURES.json and its archive stay the source of truth.
- upgrade.sh: kit one-liner → template; custom pointer → `@AGENTS.md`
  prepended, text kept; CLAUDE.md created when missing. AGENTS.md: old
  declaration and plugin paragraph replaced when unedited, declaration
  inserted under the title otherwise; skip line after "always apply.".
- harness-audit: WARN when CLAUDE.md/GEMINI.md does not import AGENTS.md.
- Verify: e2e.sh asserts; test-upgrade.sh 4e; test-audit.sh 1b.

## Decision log

- 2026-10-31: import, not delete CLAUDE.md: native AGENTS.md reading needs
  Claude Code ≥ 2.1.277 and fails in some sessions; ADEs pin their own SDK
  version. The docs say the import never loads AGENTS.md twice.
- A custom CLAUDE.md gets the import prepended rather than a TODO (proposal
  said TODO): it keeps every line, and the owner wants upgrade to fix repos
  with hand-written pointers.
- Skip line per owner: "just build it" can exist, but FEATURES.json (and the
  archive, for ids) stays the source of truth even with no plan.
- Shipping the session scripts or project skills inside each repo was not
  done: two copies and name clashes with the plugin. Revisit only with
  evidence that plugin-less sessions get the loop wrong.
- test-audit expect_fail uses here-strings: echo | grep -q under pipefail
  failed spuriously once the audit printed more lines.
