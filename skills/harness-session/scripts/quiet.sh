#!/usr/bin/env bash
# harness-session: run any build/test/simulator command with the full output
# on disk and a capped summary on screen (M34-008).
# Usage: quiet.sh <name> -- <command...>   full log: .harness-run/logs/<name>-<time>.log
#        quiet.sh --summary <logfile>      print just the capped summary of a log
# Prints: EXIT, FULL_LOG, up to 40 lines matching error|fail|warning, the last
# 20 lines; every line cut to 300 characters. Exit: the command's own code
# (2 on bad usage). Read the log by searching it (grep, sed -n), never whole.
set -uo pipefail

summary() {
  echo "--- matches (max 40) ---"
  grep -iE 'error|fail|warning' "$1" | head -n 40 | cut -c1-300
  echo "--- last 20 lines ---"
  tail -n 20 "$1" | cut -c1-300
}

if [ "${1:-}" = "--summary" ] && [ -f "${2:-}" ]; then summary "$2"; exit 0; fi
if [ $# -lt 3 ] || [ "$2" != "--" ]; then
  echo "usage: quiet.sh <name> -- <command...>" >&2
  exit 2
fi
name="$1"; shift 2
mkdir -p .harness-run/logs
log=".harness-run/logs/${name}-$(date +%Y%m%d-%H%M%S)-$$.log"
"$@" >"$log" 2>&1
status=$?
echo "EXIT: $status"
echo "FULL_LOG: $log"
summary "$log"
exit "$status"
