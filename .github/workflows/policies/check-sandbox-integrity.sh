#!/usr/bin/env bash
set -euo pipefail

# ASI05 — Unexpected Code Execution: the sandbox boundary (devcontainer +
# firewall) must exist and cannot be silently weakened by a PR.

fail=0

if [ ! -f ".devcontainer/devcontainer.json" ]; then
  echo "::error::.devcontainer/devcontainer.json is missing — no defined sandbox boundary."
  fail=1
fi

if [ ! -f ".devcontainer/init-firewall.sh" ]; then
  echo "::error::.devcontainer/init-firewall.sh is missing — default-deny egress is not enforced."
  fail=1
fi

if [ -f ".devcontainer/devcontainer.json" ] && ! grep -q "init-firewall.sh" .devcontainer/devcontainer.json; then
  echo "::error::devcontainer.json no longer invokes init-firewall.sh — the firewall would never run."
  fail=1
fi

if [ -f ".devcontainer/devcontainer.json" ] && ! grep -q "NET_ADMIN" .devcontainer/devcontainer.json; then
  echo "::error::NET_ADMIN capability removed from devcontainer.json — the firewall script can no longer apply iptables rules."
  fail=1
fi

if [ "$fail" -eq 0 ]; then
  echo "Sandbox integrity check passed."
fi
exit $fail
