#!/usr/bin/env bash
# Run the CI gate locally, the way .github/workflows/gate.yml runs it: a clean
# clone of the committed HEAD (uncommitted changes are not tested, as on CI),
# in ubuntu:24.04 (ubuntu-latest) with apt's jq and shellcheck, no git
# identity, no personal config. Run it before every push.
# Usage: bash scripts/ci-local.sh [--no-docker]
#   --no-docker  clean clone + no git config on this machine; tool versions are
#                then the local ones, so a version-only difference can slip by.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
[ -z "$(git status --porcelain)" ] || echo "NOTE: uncommitted changes are not tested (CI sees commits only)"

work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
git clone -q --no-hardlinks . "$work/repo"
echo "CI-LOCAL: $(git rev-parse --short HEAD) in a clean clone"

if [ "${1:-}" != "--no-docker" ] && command -v docker >/dev/null && docker info >/dev/null 2>&1; then
  # ponytail: apt on every run (~30s); bake an image if that ever matters
  docker run --rm -v "$work/repo:/repo" -w /repo ubuntu:24.04 bash -c '
    set -e
    apt-get update -qq >/dev/null && apt-get install -y -qq git jq shellcheck >/dev/null
    git config --system safe.directory "*"
    bash scripts/e2e.sh'
else
  echo "NOTE: no Docker, running on this machine (local tool versions)"
  (cd "$work/repo" && HOME="$work/home" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 bash scripts/e2e.sh)
fi
echo "CI-LOCAL GREEN"
