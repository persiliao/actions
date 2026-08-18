#!/usr/bin/env bash
#
# Test every reusable action in this repo locally with `act`.
#
# Usage:
#   ./scripts/test-with-act.sh                 # run the whole test workflow
#   ./scripts/test-with-act.sh --job test-docker-smoke
#
# Prereqs:
#   - act        (brew install act)
#   - docker     (the Docker smoke test needs a working daemon)
#
# macOS note:
#   The Docker credential store (osxkeychain) breaks act's image pull. This
#   script runs act with an isolated, credential-store-free HOME so it reads a
#   ~/.docker/config.json without "credsStore". Your real Docker config is not
#   modified.
#
# Notes:
#   - SSH-deploy and notify jobs use `continue-on-error` because they need a
#     live host / real webhook to fully succeed. They validate input wiring.
#   - Provide secrets for real notify tests:
#       act -s SLACK_WEBHOOK="https://hooks.slack.com/..." \
#           -W .github/workflows/test-actions.yml

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$REPO_ROOT"

if ! command -v act >/dev/null 2>&1; then
  echo "act not found. Install it first: brew install act" >&2
  exit 1
fi

# On macOS, isolate the Docker config so act doesn't hit osxkeychain.
if [[ "$(uname)" == "Darwin" ]]; then
  ACT_HOME="${TMPDIR:-/tmp}/act-home"
  mkdir -p "$ACT_HOME/.docker"
  if [[ ! -f "$ACT_HOME/.docker/config.json" ]]; then
    printf '{"auths":{}}' > "$ACT_HOME/.docker/config.json"
  fi
  export HOME="$ACT_HOME"
  export DOCKER_CONFIG="$ACT_HOME/.docker"
fi

# Default to the dedicated test workflow; allow passing extra args (e.g. --job).
# --bind is required for local `uses: ./.github/actions/...` to resolve.
# --artifact-server-path starts a local artifact server so the upload/download
# wrapper tests (and the orchestrator test) work locally.
exec act -W .github/workflows/test-actions.yml --bind \
  --artifact-server-path "${TMPDIR:-/tmp}/act-artifacts" "$@"
