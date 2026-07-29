#!/usr/bin/env bash
set -euo pipefail

# FinOps / accountability gate: IaC that provisions spend under an
# infra/deploy path must be attributable to a cost-center, a client or
# tenant, and an environment before it can merge.

REQUIRED_TAGS=("cost-center" "client-tenant" "environment")
fail=0

BASE="${BASE_SHA:-origin/main}"
changed_iac=$(git diff --name-only "${BASE}"...HEAD -- '*.bicep' '*.tf' 2>/dev/null || true)
iac_files=$(echo "$changed_iac" | grep -Ei '(^|/)(infra|deploy)/' || true)

if [ -z "$iac_files" ]; then
  echo "No changed *.bicep/*.tf files under an infra/deploy path — skipping cost-tag check."
  exit 0
fi

for f in $iac_files; do
  for tag in "${REQUIRED_TAGS[@]}"; do
    if ! grep -qi "$tag" "$f"; then
      echo "::error file=$f::Missing required tag '$tag' — spend from this resource cannot be attributed to a client/tenant."
      fail=1
    fi
  done
done

if [ "$fail" -eq 0 ]; then
  echo "Cost-tag check passed."
fi
exit $fail
