# OWASP Docker Top 10 — coverage mapping

This repo's devcontainer is a Docker image and a runtime config, so it's
worth checking against the [OWASP Docker Top 10](https://github.com/OWASP/Docker-Security)
and the [OWASP Docker Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Docker_Security_Cheat_Sheet.html)
directly, separately from the agent-specific ASI mapping in
`OWASP-ASI-MAPPING.md`. Several of these items are host- or
organization-level concerns that a repo's config files cannot enforce —
named honestly below rather than glossed over.

| # | Risk | Covered here? | How | If not — what's still needed |
|---|---|---|---|---|
| D01 | Secure the host | ❌ No | — | Host OS hardening, kernel patching, and Docker daemon placement are operational concerns outside this repo's reach. |
| D02 | Secure the Docker daemon | ❌ No | — | TLS on the daemon socket, restricting who can reach it, and daemon-level audit logging are host/infra configuration, not something `.devcontainer/` can set. |
| D03 | Secure container images | ✅ Yes | `Dockerfile` pins its base image by both tag and content digest (`mcr.microsoft.com/devcontainers/base:2.1.11-trixie@sha256:...`) on current Debian trixie, installs only the packages the firewall and dev workflow need, and creates a dedicated non-root user | No automated image vulnerability scan (e.g. Trivy/Grype) runs in the PR gate yet — the base image and packages are current as pinned, but nothing re-checks them for newly disclosed CVEs over time. |
| D04 | Secure container runtime | ✅ Yes | `devcontainer.json` runs `--cap-drop=ALL`; the `agentic-sandbox-firewall` Dev Container Feature (`src/agentic-sandbox-firewall/`) declares `capAdd: [NET_ADMIN, NET_RAW]` for exactly what its firewall needs, instead of the container keeping Docker's broader default capability set | No seccomp/AppArmor profile is set, and the root filesystem isn't read-only (a full interactive dev environment needs broad write access, so this repo doesn't attempt that trade-off). |
| D05 | Secure the supply chain | ✅ Yes | Base image pinned by digest; the Nix installer and gitleaks are pinned to specific versions and checksum-verified before running (see `check-secrets-scan.sh` and the Dockerfile); the committed `flake.lock` pins the rest of the dev toolchain to exact, verified content hashes; `actions/checkout` and `devcontainers/action` in the CI gates are pinned by commit SHA, not a mutable tag; the published `agentic-sandbox-firewall` Feature itself is version-pinned (`devcontainer-feature.json`) and consumers reference it by version, not `latest` | No SBOM is generated for the built devcontainer image itself. |
| D06 | Secure container registries | ⚠️ Partial | The Feature publishes to ghcr.io under this repo's own namespace via `release-features.yml`, so provenance is traceable to this source repo | No image signing/verification (e.g. cosign) is set up on the published OCI artifact, and registry-level access control/retention policy is GHCR's default, not something this repo configures further. |
| D07 | Process for handling relevant security patches | ⚠️ Partial | Every pinned version (base image, Nix, gitleaks, `actions/checkout`, `devcontainers/action`) is a concrete value that shows up in a diff when it changes, so a bump is visible and reviewable | There's no automated process (e.g. Dependabot/Renovate) opening those bump PRs — pins currently have to be refreshed by hand. |
| D08 | Collect and store Docker logs | ❌ No | — | Centralized container log collection is an operational/observability concern for wherever the container actually runs, not something this repo configures. |
| D09 | Secure Docker networking | ✅ Yes | The `agentic-sandbox-firewall` Feature enforces default-deny egress — the container can't reach anything beyond loopback, DNS to a configured resolver, and an explicit domain allowlist — and re-applies it on every container start via its `entrypoint`, not just first creation | Only egress is filtered. Ingress/inter-container networking isn't a concern here since this is a single-container dev sandbox, not a multi-service deployment. |
| D10 | Encrypt data at rest / secure secrets | ✅ Yes | No static credentials are ever mounted into the container (`devcontainer.json` mounts only the workspace); real auth is workload-identity-federation, not a bind-mounted key — see `agents/example-agent.yaml` and the README | Doesn't cover encryption of whatever the workload itself persists to disk — that depends on what a given agent run actually writes, which this repo doesn't control. |

**Bottom line:** 5 of 10 are fully covered, 2 are partial, and 3 (host
hardening, daemon hardening, log collection) are infrastructure-level
decisions that belong to wherever this container is actually deployed
and run — not something a devcontainer definition in a git repo can
guarantee on its own.
