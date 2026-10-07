#!/usr/bin/env bash
# A small invoices CLI repo, enough context for a brief without questions.
set -euo pipefail
git init -q -b main .
git config user.email eval@example.com
git config user.name eval
cat > README.md <<'MD'
# invoices

A Python CLI that stores invoices in `invoices.json` and prints them with
`python -m invoices list`. Tests: `pytest` (tests/ folder).
MD
mkdir -p invoices tests
printf 'def main():\n    print("invoices")\n' > invoices/__main__.py
printf 'def test_placeholder():\n    assert True\n' > tests/test_cli.py
git add -A && git commit -q -m init
