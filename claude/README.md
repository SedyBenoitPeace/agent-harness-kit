# agent-harness-kit-claude

The Claude Code edition of the agent harness. It adds features only Claude
Code has, on top of the core `agent-harness-kit` plugin, which it depends on.
The protocol, templates and skills all live in the core plugin; this folder
never copies them.

What it adds (see the repo README, "Claude Code edition"):

- agent effort for the builder and evaluator (M24-002);
- an eval suite for the core skills, run with `claude plugin eval` (M24-003);
- mods: a decision register, a done-check supervisor, a budget guard and a
  next-steps band (M25).

Install both:

```
/plugin marketplace add SedyBenoitPeace/agent-harness-kit
/plugin install agent-harness-kit
/plugin install agent-harness-kit-claude
```
