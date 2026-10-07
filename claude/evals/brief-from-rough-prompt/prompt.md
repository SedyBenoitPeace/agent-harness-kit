---
plugins: ["../../.."]
runs: 2
max_turns: 40
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill, Agent, Write, Bash]
---

I want to add CSV export to this invoices CLI: `python -m invoices export --csv out.csv`
writes every invoice as one row (id, date, customer, total), with a header row.
Turn that into a brief I can hand to an agent to build later. Don't ask me
anything, I'm away: pick sensible defaults and say what you picked. Don't build it.
