#!/usr/bin/env bash
# harness-run: block in the shell (not in the model) until a builder's
# .harness-run/results/<id>.txt exists, then print it. One tool call per
# builder. Silent while waiting. No model calls.
# Usage: wait-result.sh <id> [--timeout <seconds>]   (default 3600)
# Exit: 0 printed · 1 timed out · 2 usage
set -euo pipefail
id="${1:-}"; [ -n "$id" ] || { echo "usage: wait-result.sh <id> [--timeout <s>]" >&2; exit 2; }
timeout=3600
[ "${2:-}" = "--timeout" ] && timeout="${3:-}"
case "$timeout" in ''|*[!0-9]*) echo "usage: wait-result.sh <id> [--timeout <s>]" >&2; exit 2;; esac
f=".harness-run/results/$id.txt"
end=$(( $(date +%s) + timeout ))
while [ ! -f "$f" ]; do
  [ "$(date +%s)" -lt "$end" ] || { echo "wait-result: timed out waiting for $f" >&2; exit 1; }
  sleep 1
done
cat "$f"
