# Brief: tag filter for a notes CLI

## Objective
Add a `--tag <name>` filter to `notes list` that prints only notes carrying that tag.

## Stage
prototype — a demo for one review meeting.

## Context
Node 22 CLI in `app/`; notes live in `app/data/notes.json`, one object per note with a `tags` array.

## Deliverables
- `notes list --tag <name>` in `app/src/list.js`
- a unit test in `app/test/list.test.js`

## Non-goals
- No tag editing, renaming or colours.

## Done when
- `cd app && npm test` exits 0
- `node app/bin/notes list --tag work | grep -c work` prints 2 for the seed data

## Quality bar
Gate is sufficient.

## Needs a human
- None.

## Budget and stop condition
One feature; stop at the first red gate.

## Open questions
