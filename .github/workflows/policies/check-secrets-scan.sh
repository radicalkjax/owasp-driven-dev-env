#!/usr/bin/env bash
set -euo pipefail

# ASI03 — Identity & Privilege Abuse: no static credentials may ever be
# committed to this repo. Scans the full diff history of the PR, not just
# the working tree, so a secret added and later "removed" in a follow-up
# commit is still caught.

GITLEAKS_VERSION="8.18.4"
GITLEAKS_ASSET="gitleaks_${GITLEAKS_VERSION}_linux_x64.tar.gz"
# Published in gitleaks' own release checksums file (gitleaks_<version>_checksums.txt)
# for this exact asset. Update this alongside GITLEAKS_VERSION — do not drop
# the check to make a version bump easier.
GITLEAKS_SHA256="ba6dbb656933921c775ee5a2d1c13a91046e7952e9d919f9bac4cec61d628e7d"

if ! command -v gitleaks >/dev/null 2>&1; then
  echo "Installing gitleaks v${GITLEAKS_VERSION}..."
  curl -sSL -o /tmp/gitleaks.tar.gz \
    "https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/${GITLEAKS_ASSET}"

  echo "${GITLEAKS_SHA256}  /tmp/gitleaks.tar.gz" | sha256sum -c -

  tar -xzf /tmp/gitleaks.tar.gz -C /tmp gitleaks
  sudo install -m 0755 /tmp/gitleaks /usr/local/bin/gitleaks
fi

BASE="${BASE_SHA:-origin/main}"

# --log-opts scopes the scan to every commit introduced by this PR
# (base..HEAD), not the entire repository history.
gitleaks detect \
  --source . \
  --log-opts="${BASE}..HEAD" \
  --redact \
  --exit-code 1

echo "Secrets scan passed — no credentials found in this PR's history."
