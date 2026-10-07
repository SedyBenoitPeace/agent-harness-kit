# The Harness Protocol: maintenance

Section 3, read for a maintenance pass. `harness-protocol.md` holds the
coding-session core and the index of the other parts.

## 3. Maintenance protocol

Agent-built codebases accumulate entropy: generated code replicates existing
patterns, including the bad ones, and docs drift from reality. Run this
protocol on a cadence — every few milestones, or whenever sessions start
feeling harder than they should.

### 3.1 Entropy garbage collection

Scan for drift from the repo's documented conventions (naming, structure,
error handling, test patterns). Fix what you find in **small, focused
cleanup branches** — one concern per branch, integrated like any other work.
Never a big-bang rewrite: it destroys the git history's usefulness as
context and is unreviewable.

### 3.2 Doc gardening

- AGENTS.md stays ≤100 lines and current — it must never claim a state the
  repo isn't in.
- ARCHITECTURE.md is read against the code it describes. A section reality
  contradicts gets corrected — or the code does: a violated invariant is a
  defect to fix, not a doc line to soften.
- Stale docs are updated or deleted; a doc that lies is worse than no doc.
- When the agent's model changes, re-test every rule tagged
  `(model: <name>)` (§3.4): drop it, run a session or two, and delete it
  for good if nothing breaks. A rule
  written for one model often over-constrains the next.
- Plans whose work is done move from `docs/plans/active/` to
  `docs/plans/completed/`.

### 3.3 FEATURES.json gardening

- Features that will never happen become `superseded` (never deleted — the
  history is the point).
- `deferred` entries get their notes re-checked: is the blocking condition
  gone? If so, flip to `failing` so the ordinary session loop picks them up.

### 3.4 When something fails, ask "what's missing?"

When a session goes wrong — wrong feature picked, gate skipped, convention
violated — the fix is usually a missing tool, guardrail, or doc, not "try
harder." Add the missing check to the gate, the missing rule to this
protocol, or the missing pointer to AGENTS.md. Feed every failure back into
the repo.

Prefer a check in the gate over a rule in prose, and start lean: add an
AGENTS.md rule only for a failure you have seen more than once. A rule
that fixes one model's repeated failure ends with `(model: <name>)`, so
maintenance knows to re-test it when the model changes (§3.2).

Copy-paste maintenance prompt:

```
Read AGENTS.md, then docs/agents/harness-protocol-maintenance.md, and
perform one maintenance pass. Open one cleanup branch per concern found.
```
