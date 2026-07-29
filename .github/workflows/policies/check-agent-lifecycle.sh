#!/usr/bin/env bash
set -euo pipefail

# ASI10 — Rogue Agents: every agent manifest needs a named owner and an
# expiry date, or it becomes an orphaned, unaudited agent nobody is
# accountable for.

fail=0

shopt -s nullglob
for f in agents/*.yaml agents/*.yml; do
  if ! grep -q "^owner:" "$f"; then
    echo "::error file=$f::Agent manifest missing 'owner' — orphaned agents are unauditable (ASI10)."
    fail=1
  fi
  if ! grep -q "^expires:" "$f"; then
    echo "::error file=$f::Agent manifest missing 'expires' — no lifecycle boundary (ASI10)."
    fail=1
  fi
done

if [ "$fail" -eq 0 ]; then
  echo "Agent lifecycle check passed."
fi
exit $fail
