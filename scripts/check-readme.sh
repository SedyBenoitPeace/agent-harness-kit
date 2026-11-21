#!/usr/bin/env bash
# shellcheck disable=SC2016 # backticks are literal
# README coverage per release (M50-001). Every CHANGELOG release from
# 3.17.0 on carries one line `README: `phrase`, `phrase`` naming phrases the
# README uses to document it, or `README: none (<reason>)` for a release with
# nothing user-facing. Each phrase must appear verbatim in README.md or in a
# docs/guide/ page (M60-004: deep detail moved out of the README).
# Usage: check-readme.sh [CHANGELOG.md] [README.md] [docs/guide]   exit 0 = covered
set -euo pipefail
changelog="${1:-CHANGELOG.md}"; readme="${2:-README.md}"; guide="${3:-docs/guide}"
MIN="3.17.0"
[ -f "$changelog" ] || { echo "check-readme: no $changelog" >&2; exit 2; }
[ -f "$readme" ] || { echo "check-readme: no $readme" >&2; exit 2; }

# ver_ge A B: A >= B for X.Y.Z (no sort -V: macOS)
ver_ge() { awk -v a="$1" -v b="$2" 'BEGIN { split(a, x, "."); split(b, y, ".");
  for (i = 1; i <= 3; i++) { if (x[i] + 0 > y[i] + 0) exit 0; if (x[i] + 0 < y[i] + 0) exit 1 } exit 0 }'; }

bad=0
# one line per release: "<version>\t<README line or empty>"
while IFS="$(printf '\t')" read -r ver line; do
  ver_ge "$ver" "$MIN" || continue
  if [ -z "$line" ]; then echo "README-CHECK: $ver has no 'README:' line"; bad=1; continue; fi
  case "$line" in "README: none ("*")"*) continue ;; esac
  terms="$(printf '%s\n' "$line" | grep -oE '`[^`]+`' | sed 's/^`//; s/`$//' || true)"
  if [ -z "$terms" ]; then echo "README-CHECK: $ver 'README:' line names no \`phrase\`"; bad=1; continue; fi
  while IFS= read -r t; do
    { grep -qF -- "$t" "$readme" || { [ -d "$guide" ] && grep -rqF -- "$t" "$guide"; }; } \
      || { echo "README-CHECK: $ver: README.md (or $guide/) never says '$t'"; bad=1; }
  done <<< "$terms"
done < <(awk '
  /^## [0-9]+\.[0-9]+\.[0-9]+/ { if (v != "") print v "\t" r; v = $2; r = ""; next }
  v != "" && r == "" && /^README: / { r = $0 }
  END { if (v != "") print v "\t" r }' "$changelog")

[ "$bad" -eq 0 ] && echo "README-CHECK: covered (releases >= $MIN)"
exit "$bad"
