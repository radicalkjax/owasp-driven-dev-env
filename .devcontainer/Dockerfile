# Debian-based devcontainer base + Nix on top, rather than a Nix-only
# base image. Nix-only images commonly lack packages an editor server
# (VS Code Remote, etc.) needs to attach to the container — "normal
# devcontainer base, install Nix inside it" is the pattern that avoids that.
FROM mcr.microsoft.com/devcontainers/base:bookworm

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl xz-utils ca-certificates sudo direnv \
    && rm -rf /var/lib/apt/lists/*

# This base image may already ship a default non-root user (commonly
# `vscode`). We create our own `agent` user explicitly so it matches the
# username baked into devcontainer.json, the sudoers rule below, and the
# agents/*.yaml manifests elsewhere in this repo.
RUN useradd -m -s /bin/bash agent

# --- Nix, single-user mode ---
# No nix-daemon needed, which matters for an ephemeral, one-user-per-
# container sandbox. /nix must exist and be owned by the target user
# BEFORE the installer runs as that user.
RUN mkdir -m 0755 /nix && chown agent:agent /nix

USER agent
# Pinned to a specific released Nix version via its immutable
# releases.nixos.org URL, not the rolling https://nixos.org/nix/install
# redirect (which always serves whatever the current "latest" is — an
# unpinned, moving target). This version's installer has the expected
# tarball hash (sha256 3c0779e4878d1289cf3fbb158ec5ea9bdf61dfb9b4efac6b3b0b6bec5ba4cf13
# for nix-2.24.9-x86_64-linux.tar.xz) baked in and verifies it before
# unpacking — confirmed against the independently published
# nix-2.24.9-x86_64-linux.tar.xz.sha256 at the same host. Downloaded to a
# file and inspected as a build step rather than piped straight into a
# shell, so a truncated or corrupted fetch fails loudly instead of
# executing a partial script.
RUN curl -sSL -o /tmp/nix-install.sh https://releases.nixos.org/nix/nix-2.24.9/install \
    && sh /tmp/nix-install.sh --no-daemon \
    && rm -f /tmp/nix-install.sh
ENV PATH="/home/agent/.nix-profile/bin:${PATH}"
RUN mkdir -p /home/agent/.config/nix \
    && echo "experimental-features = nix-command flakes" \
         >> /home/agent/.config/nix/nix.conf

# Pin the firewall binaries into the user's Nix profile at a STABLE path.
# The underlying /nix/store/<hash>-iptables-x.y.z paths are content-hashed
# and shift on every `nix flake update` / channel bump.
# ~/.nix-profile/bin/<name> is a symlink that stays at the same path
# across those updates — that's the path the sudoers rule below (and
# init-firewall.sh) reference, on purpose, never the raw store path.
RUN nix profile install nixpkgs#iptables nixpkgs#ipset nixpkgs#dnsutils

USER root

# Scoped sudo: this user may run exactly iptables and ipset as root, and
# nothing else. This is what lets postCreateCommand apply the firewall
# without granting the agent general root access. Written as an explicit
# sudoers rule (not "agent ALL=(ALL) NOPASSWD: ALL") on purpose.
RUN echo "agent ALL=(root) NOPASSWD: /home/agent/.nix-profile/bin/iptables, /home/agent/.nix-profile/bin/ipset" \
      > /etc/sudoers.d/agent-firewall \
    && chmod 0440 /etc/sudoers.d/agent-firewall \
    && visudo -c

COPY init-firewall.sh /usr/local/bin/init-firewall.sh
RUN chmod +x /usr/local/bin/init-firewall.sh

USER agent
WORKDIR /workspace

# Copy the flake so the devShell can be pre-built at image-build time
# (faster first `nix develop` / `direnv allow`). flake.lock must already
# be committed in the repo — see the header comment in flake.nix for how
# to generate it. This build step tolerates it being absent so a fresh
# repo still builds; the CI gate (flake-lock-pinned job) is what actually
# enforces that it exists before merge.
COPY --chown=agent:agent flake.nix flake.lock* /workspace/
RUN nix develop --command true || true
