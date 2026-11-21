#!/usr/bin/env bash
# add-ddd.sh: opt a harnessed repo into domain-driven design (M57-002).
# Adds GLOSSARY.md (the ubiquitous language), docs/adr/0000-template.md and
# one AGENTS.md pointer line under the Map's scripts/e2e.sh line (appended
# when that line is missing). Idempotent; never overwrites; commits nothing.
# Usage: add-ddd.sh [TARGET_DIR]    Prints OK: / CHANGED: lines.
set -euo pipefail
T="$(cd "$(dirname "$0")/../templates" && pwd)"
cd "${1:-.}"

copy() { # copy <template> <destination>
  if [ -e "$2" ]; then echo "OK: $2 exists"; return; fi
  mkdir -p "$(dirname "$2")"
  cp "$T/$1" "$2"
  echo "CHANGED: $2 (added for domain-driven design)"
}
copy GLOSSARY.md.tmpl GLOSSARY.md
copy adr-template.md docs/adr/0000-template.md

# shellcheck disable=SC2016 # the backticks are literal markdown
pointer='- `GLOSSARY.md`, `docs/adr/` — domain terms to use in code and docs; one ADR per hard-to-reverse decision'
if [ ! -f AGENTS.md ]; then
  echo "TODO: AGENTS.md is missing — add this line to its map: $pointer"
elif grep -qF 'GLOSSARY.md' AGENTS.md; then
  echo "OK: AGENTS.md points at GLOSSARY.md"
else
  awk -v p="$pointer" '{ print } !done && /^- `scripts\/e2e\.sh`/ { print p; done = 1 }
    END { if (!done) print p }' AGENTS.md > AGENTS.md.ddd && mv AGENTS.md.ddd AGENTS.md
  echo "CHANGED: AGENTS.md (added the GLOSSARY.md / docs/adr/ pointer)"
fi
