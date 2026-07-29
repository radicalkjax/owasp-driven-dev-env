#!/usr/bin/env bash
set -euo pipefail

# ASI04 — Agentic Supply Chain: every dependency, MCP server, or agent
# definition change must be reflected in the AI Bill of Materials in the
# same PR that introduces it.

BASE="${BASE_SHA:-origin/main}"
changed=$(git diff --name-only "${BASE}"...HEAD || true)

touches_deps=$(echo "$changed" | grep -E 'package\.json|requirements\.txt|pyproject\.toml|mcp\.(json|yaml|yml)|agents/.*\.ya?ml' || true)
touches_aibom=$(echo "$changed" | grep -E '^aibom\.json$' || true)

if [ -n "$touches_deps" ] && [ -z "$touches_aibom" ]; then
  echo "::error::Dependency manifest, MCP server config, or agent YAML changed but aibom.json was not updated in this PR."
  echo "Files that require a matching aibom.json entry:"
  echo "$touches_deps"
  exit 1
fi

echo "AIBOM check passed."
