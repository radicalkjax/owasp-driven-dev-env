#!/usr/bin/env bash
set -euo pipefail

# ASI04 — Agentic Supply Chain: the dev toolchain itself must be
# hash-pinned via flake.lock, not resolved fresh (and potentially
# differently) on every machine that builds the devcontainer.

BASE="${BASE_SHA:-origin/main}"
changed=$(git diff --name-only "${BASE}"...HEAD || true)

if echo "$changed" | grep -q '^flake\.nix$'; then
  if ! echo "$changed" | grep -q '^flake\.lock$'; then
    echo "::error::flake.nix changed but flake.lock was not updated in the same PR."
    echo "Run 'nix flake lock' locally, commit the result, and push again."
    exit 1
  fi
fi

if [ ! -f "flake.lock" ]; then
  echo "::error::flake.lock is missing — the dev toolchain isn't hash-pinned."
  echo "Run 'nix flake lock' (with network access) and commit the result."
  exit 1
fi

echo "flake.lock check passed."
