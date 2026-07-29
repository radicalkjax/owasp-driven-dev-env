#!/usr/bin/env bash
set -euo pipefail

# Default-deny egress firewall for the agent sandbox.
# Maps to OWASP ASI05 (Unexpected Code Execution): even if the agent
# generates and runs arbitrary code, it cannot exfiltrate data or reach
# an unapproved host, because only allowlisted destinations are reachable.
#
# KNOWN LIMITATION: domain names below are resolved to IPs once, at
# container start. If an allowed domain sits behind a rotating IP (a CDN
# or load balancer), egress to its new IP will be blocked until this
# script is re-run. Long-lived containers should either re-run this on a
# timer or replace the ipset approach with a transparent egress proxy
# that allowlists by SNI/hostname instead of IP.

IPTABLES="/usr/sbin/iptables"
IPSET="/usr/sbin/ipset"
DIG="/usr/bin/dig"

# Configurable list of domains the sandbox is allowed to reach.
ALLOWED_DOMAINS=(
  "api.anthropic.com"
  "github.com"
  "codeload.github.com"
  "registry.npmjs.org"
  "pypi.org"
  "files.pythonhosted.org"
)

# Configurable DNS resolver. Replace with your internal/corporate resolver
# if one is required by policy.
DNS_RESOLVER="1.1.1.1"

"$IPTABLES" -F OUTPUT
"$IPTABLES" -P OUTPUT DROP

# Loopback and already-established/related connections are always fine.
"$IPTABLES" -A OUTPUT -o lo -j ACCEPT
"$IPTABLES" -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# DNS is allowed only to the configured resolver, not to arbitrary hosts.
"$IPTABLES" -A OUTPUT -p udp --dport 53 -d "$DNS_RESOLVER" -j ACCEPT
"$IPTABLES" -A OUTPUT -p tcp --dport 53 -d "$DNS_RESOLVER" -j ACCEPT

"$IPSET" create allowed-egress hash:ip -exist

for domain in "${ALLOWED_DOMAINS[@]}"; do
  ips=$("$DIG" +short "$domain" @"$DNS_RESOLVER" | grep -E '^[0-9]+\.' || true)
  for ip in $ips; do
    "$IPSET" add allowed-egress "$ip" -exist
  done
done

"$IPTABLES" -A OUTPUT -m set --match-set allowed-egress dst -j ACCEPT

echo "Default-deny egress active."
echo "Allowed domains: ${ALLOWED_DOMAINS[*]}"
echo "Verify with: sudo $IPTABLES -L OUTPUT -v"
