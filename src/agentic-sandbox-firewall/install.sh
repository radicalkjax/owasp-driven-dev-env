#!/usr/bin/env bash
set -euo pipefail

# Dev Container Feature install script. Runs as root during the image
# build (after the consuming project's own Dockerfile), regardless of
# that Dockerfile's final USER — see the containers.dev Features spec.
#
# Feature options arrive here as build-time environment variables, named
# by upper-casing the option id with no other transformation (confirmed
# against devcontainers/cli's getSafeId: non-word chars -> '_', then
# toUpperCase — camelCase boundaries are NOT split). So option
# "allowedDomains" arrives as $ALLOWEDDOMAINS, "dnsResolver" as
# $DNSRESOLVER, "remoteUser" as $REMOTEUSER.
REMOTE_USER="${REMOTEUSER:-vscode}"
ALLOWED_DOMAINS_CSV="${ALLOWEDDOMAINS:-api.anthropic.com,github.com,codeload.github.com,registry.npmjs.org,pypi.org,files.pythonhosted.org}"
DNS_RESOLVER="${DNSRESOLVER:-1.1.1.1}"

# If the consuming project's own Dockerfile already provides iptables/
# ipset/dig on PATH (e.g. via Nix, as this repo's own root .devcontainer
# does), reuse those rather than installing a second copy. Otherwise
# fall back to apt. This Feature currently only auto-installs on
# Debian/Ubuntu (apt-based) images — that covers the large majority of
# devcontainer base images in practice, but it's a real, honest
# limitation, not full cross-distro support.
if command -v iptables >/dev/null 2>&1 && command -v ipset >/dev/null 2>&1 && command -v dig >/dev/null 2>&1; then
  echo "iptables/ipset/dig already present on PATH — reusing them."
elif command -v apt-get >/dev/null 2>&1; then
  apt-get update
  apt-get install -y --no-install-recommends iptables ipset dnsutils sudo
  rm -rf /var/lib/apt/lists/*
else
  echo "ERROR: iptables/ipset/dig not found, and no apt-get available to install them." >&2
  echo "This Feature currently only auto-installs its dependencies on Debian/Ubuntu" >&2
  echo "(apt-based) images. Install iptables, ipset, and dig yourself first on other" >&2
  echo "distros, then re-apply this Feature." >&2
  exit 1
fi

IPTABLES_PATH="$(command -v iptables)"
IPSET_PATH="$(command -v ipset)"
DIG_PATH="$(command -v dig)"

# Scoped sudo: REMOTE_USER may run exactly the two resolved binaries
# above as root, and nothing else. Written as an explicit sudoers rule
# (not "ALL=(ALL) NOPASSWD: ALL") on purpose.
echo "${REMOTE_USER} ALL=(root) NOPASSWD: ${IPTABLES_PATH}, ${IPSET_PATH}" \
  > /etc/sudoers.d/agentic-sandbox-firewall
chmod 0440 /etc/sudoers.d/agentic-sandbox-firewall
visudo -c

mkdir -p /usr/local/share/agentic-sandbox-firewall

# Two-stage heredoc, same technique the official docker-in-docker Feature
# uses for its docker-init.sh: the first stage (unquoted delimiter) bakes
# this install's resolved paths/options in as literal values; the second
# stage (quoted delimiter) pastes the firewall logic unmodified. There is
# no JSON-level option substitution for Features (unlike Templates), so
# this is the only way option values reach a script that runs later, at
# container start.
tee /usr/local/share/agentic-sandbox-firewall/entrypoint.sh > /dev/null << EOF
#!/bin/sh
set -e

IPTABLES="${IPTABLES_PATH}"
IPSET="${IPSET_PATH}"
DIG="${DIG_PATH}"
DNS_RESOLVER="${DNS_RESOLVER}"
ALLOWED_DOMAINS_CSV="${ALLOWED_DOMAINS_CSV}"
EOF

tee -a /usr/local/share/agentic-sandbox-firewall/entrypoint.sh > /dev/null << 'EOF'

# Default-deny egress firewall (OWASP ASI05: Unexpected Code Execution).
# Runs as this script's own entrypoint, so it re-applies on EVERY
# container start (including resuming a stopped container), not just
# first creation — iptables rules live in the container's network
# namespace and do not survive a stop/start cycle on their own.
#
# KNOWN LIMITATION: domains are resolved to IPs once, per container
# start. A domain behind a rotating IP (a CDN) may need the container
# restarted, or an SNI-aware egress proxy instead of this ipset approach.

sudo_if() {
  if [ "$(id -u)" -ne 0 ]; then
    sudo "$@"
  else
    "$@"
  fi
}

sudo_if "$IPTABLES" -F OUTPUT
sudo_if "$IPTABLES" -P OUTPUT DROP
sudo_if "$IPTABLES" -A OUTPUT -o lo -j ACCEPT
sudo_if "$IPTABLES" -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
sudo_if "$IPTABLES" -A OUTPUT -p udp --dport 53 -d "$DNS_RESOLVER" -j ACCEPT
sudo_if "$IPTABLES" -A OUTPUT -p tcp --dport 53 -d "$DNS_RESOLVER" -j ACCEPT

sudo_if "$IPSET" create allowed-egress hash:ip -exist

OLD_IFS="$IFS"
IFS=','
for domain in $ALLOWED_DOMAINS_CSV; do
  IFS="$OLD_IFS"
  ips=$("$DIG" +short "$domain" @"$DNS_RESOLVER" 2>/dev/null | grep -E '^[0-9]+\.' || true)
  for ip in $ips; do
    sudo_if "$IPSET" add allowed-egress "$ip" -exist
  done
  IFS=','
done
IFS="$OLD_IFS"

sudo_if "$IPTABLES" -A OUTPUT -m set --match-set allowed-egress dst -j ACCEPT

echo "Default-deny egress active (agentic-sandbox-firewall)."
echo "Allowed domains: $ALLOWED_DOMAINS_CSV"
echo "Verify with: sudo $IPTABLES -L OUTPUT -v"

# Hand off to whatever command the container was actually started with —
# this is what lets this script be set as the container's ENTRYPOINT
# while the original CMD still runs.
exec "$@"
EOF

chmod +x /usr/local/share/agentic-sandbox-firewall/entrypoint.sh
chown "${REMOTE_USER}:root" /usr/local/share/agentic-sandbox-firewall/entrypoint.sh 2>/dev/null || true

echo "agentic-sandbox-firewall installed. Entrypoint: /usr/local/share/agentic-sandbox-firewall/entrypoint.sh"
