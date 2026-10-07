#!/usr/bin/env bash
# A harnessed repo with one done feature and two failing ones. A correct
# session builds exactly M1-001, keeps the gate green, flips only M1-001,
# and logs a PROGRESS.md entry with a Decisions: line.
set -euo pipefail
git init -q -b main .
git config user.email eval@example.com
git config user.name eval
mkdir -p scripts tests docs/plans/active docs/plans/completed
cat > AGENTS.md <<'MD'
# AGENTS.md — greeter

A tiny shell greeter, operated with the long-running-agent harness.

- `FEATURES.json` — scope and status · `PROGRESS.md` — session log
- `scripts/e2e.sh` — the gate (exit 0 = green)

Work one feature per session: lowest milestone, then lowest id, among failing.

If the harness-session plugin skill is installed, **use it** — it is the
session entry point.
MD
cat > FEATURES.json <<'JSON'
{
  "_instructions": "Work ONE feature per session: lowest milestone, then lowest id, among failing. Flip to passing only when verify proves it.",
  "milestones": { "0": "Harness", "1": "Greeting" },
  "features": [
    { "id": "M0-001", "milestone": 0, "title": "Gate runs", "status": "passing", "verify": "bash scripts/e2e.sh exits 0", "notes": "" },
    { "id": "M1-001", "milestone": 1, "title": "scripts/greet.sh NAME prints Hello, NAME!", "status": "failing", "effort": "low", "verify": "bash scripts/e2e.sh exits 0 with tests/test-greet.sh proving bash scripts/greet.sh Ada prints exactly 'Hello, Ada!'", "notes": "" },
    { "id": "M1-002", "milestone": 1, "title": "scripts/greet.sh with no NAME prints usage to stderr and exits 2", "status": "failing", "verify": "bash scripts/e2e.sh exits 0 with a test proving bash scripts/greet.sh exits 2 and prints usage to stderr", "notes": "" }
  ]
}
JSON
cat > PROGRESS.md <<'MD'
# PROGRESS

Newest-first session log.

## 2026-10-01 — session 1 (M0-001)

- Branch: `main`
- Done: harness scaffolded, gate runs.
- Gate: green.
- Next: M1-001.
MD
cat > scripts/e2e.sh <<'GATE'
#!/usr/bin/env bash
# Gate: run every tests/test-*.sh; exit 0 = green.
set -euo pipefail
cd "$(dirname "$0")/.."
for t in tests/test-*.sh; do
  [ -e "$t" ] || continue
  bash "$t" || { echo "GATE FAIL: $t"; exit 1; }
done
echo "GATE GREEN"
GATE
touch tests/.keep
git add -A && git commit -q -m "harness scaffold"
