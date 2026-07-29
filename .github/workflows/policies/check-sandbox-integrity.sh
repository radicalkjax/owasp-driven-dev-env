#!/usr/bin/env bash
set -euo pipefail

# ASI05 — Unexpected Code Execution: the sandbox boundary (devcontainer +
# firewall) must exist and cannot be silently weakened by a PR.
#
# The firewall itself lives in the agentic-sandbox-firewall Dev Container
# Feature (src/agentic-sandbox-firewall/), not inline in devcontainer.json
# — the root devcontainer references it locally. So this check verifies
# both halves: the Feature's own files/declared capabilities, and that
# the root devcontainer still references it and still drops capabilities
# down first.

FEATURE_DIR="src/agentic-sandbox-firewall"

fail=0

if [ ! -f ".devcontainer/devcontainer.json" ]; then
  echo "::error::.devcontainer/devcontainer.json is missing — no defined sandbox boundary."
  fail=1
fi

if [ ! -f "${FEATURE_DIR}/devcontainer-feature.json" ]; then
  echo "::error::${FEATURE_DIR}/devcontainer-feature.json is missing — the firewall Feature no longer exists."
  fail=1
fi

if [ ! -f "${FEATURE_DIR}/install.sh" ]; then
  echo "::error::${FEATURE_DIR}/install.sh is missing — default-deny egress is not enforced."
  fail=1
fi

if [ -f "${FEATURE_DIR}/devcontainer-feature.json" ] && ! grep -q "NET_ADMIN" "${FEATURE_DIR}/devcontainer-feature.json"; then
  echo "::error::NET_ADMIN removed from ${FEATURE_DIR}/devcontainer-feature.json's capAdd — the firewall can no longer apply iptables rules."
  fail=1
fi

if [ -f "${FEATURE_DIR}/devcontainer-feature.json" ] && ! grep -q '"entrypoint"' "${FEATURE_DIR}/devcontainer-feature.json"; then
  echo "::error::entrypoint field removed from ${FEATURE_DIR}/devcontainer-feature.json — the firewall would no longer re-apply on every container start."
  fail=1
fi

if [ -f ".devcontainer/devcontainer.json" ] && ! grep -q "agentic-sandbox-firewall" .devcontainer/devcontainer.json; then
  echo "::error::devcontainer.json no longer references the agentic-sandbox-firewall Feature — the firewall would never be installed."
  fail=1
fi

if [ -f ".devcontainer/devcontainer.json" ] && ! grep -q -- "--cap-drop=ALL" .devcontainer/devcontainer.json; then
  echo "::error::--cap-drop=ALL removed from devcontainer.json's runArgs — the container would keep Docker's full default capability set instead of only what the Feature adds back."
  fail=1
fi

if [ "$fail" -eq 0 ]; then
  echo "Sandbox integrity check passed."
fi
exit $fail
