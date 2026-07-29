# Minimal devcontainer base image for the agentic sandbox.
# Debian slim + only the packages the firewall and dev workflow need —
# no extra tooling that would widen what a compromised agent could reach.
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl git sudo iptables ipset dnsutils \
    && rm -rf /var/lib/apt/lists/*

# Non-root user the agent actually runs as. Never root.
RUN useradd -m -s /bin/bash agent

# Scoped sudo: this user may run exactly iptables and ipset as root, and
# nothing else. This is what lets postCreateCommand apply the firewall
# without granting the agent general root access. Written as an explicit
# sudoers rule (not "agent ALL=(ALL) NOPASSWD: ALL") on purpose.
RUN echo "agent ALL=(root) NOPASSWD: /usr/sbin/iptables, /usr/sbin/ipset" \
      > /etc/sudoers.d/agent-firewall \
    && chmod 0440 /etc/sudoers.d/agent-firewall \
    && visudo -c

COPY init-firewall.sh /usr/local/bin/init-firewall.sh
RUN chmod +x /usr/local/bin/init-firewall.sh

USER agent
WORKDIR /workspace
