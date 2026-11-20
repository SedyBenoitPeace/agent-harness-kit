# Fake gh (M55)

`gh` here is a stateful stand-in for the calls `issues.sh` makes (issue
list/edit/close/reopen/create, label create, milestones through `gh api`).
`scripts/test-issues.sh` puts this folder first on PATH with `FAKE_GH_DIR`
pointing at a temp folder holding `issues.json` and `milestones.json`; every
call is logged there, write calls prefixed `WRITE`. Never a live repo.
