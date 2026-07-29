#!/usr/bin/env bash
set -euo pipefail

# ASI02 — Tool Misuse & Exploitation / ASI09 — Human-Agent Trust
# Exploitation: permission-bypass flags (e.g. --dangerously-skip-permissions,
# bypassPermissions) are only safe behind a sandboxed, firewalled context.
# Block any diff that introduces one outside .devcontainer or a sandbox
# reference.
#
# This script and policy/OWASP-ASI-MAPPING.md both necessarily contain the
# literal flag names — one to detect them, the other to document them —
# so both are excluded from the scan. Without this, editing either file
# makes the check flag its own source as "introducing" the flag it's
# naming.
EXCLUDE_PATHS=(
  ':!.github/workflows/policies/check-dangerous-flags.sh'
  ':!policy/OWASP-ASI-MAPPING.md'
)

BASE="${BASE_SHA:-origin/main}"
diff_content=$(git diff "${BASE}"...HEAD -- . "${EXCLUDE_PATHS[@]}" || true)

added_flags=$(echo "$diff_content" | grep -E '^\+.*(--dangerously-skip-permissions|bypassPermissions)' || true)

if [ -n "$added_flags" ]; then
  outside_sandbox=$(echo "$added_flags" | grep -viE '\.devcontainer|sandbox' || true)
  if [ -n "$outside_sandbox" ]; then
    echo "::error::Permission-bypass flag added outside a sandboxed context:"
    echo "$outside_sandbox"
    echo "This flag is only safe behind the default-deny egress firewall in .devcontainer/."
    exit 1
  fi
fi

echo "No unsandboxed permission-bypass flags found."
