# owasp-driven-dev-env

A sandboxed development environment for teams using AI coding agents,
built around the controls described in the OWASP Top 10 for Agentic
Applications (2026): a firewalled devcontainer with no static credentials,
a pinned (Nix) dev toolchain, an agent manifest format that can't go
ownerless, an AI Bill of Materials, and a pull-request gate that enforces
all of the above before merge.

## Quick start

1. **Generate the lock file once**, with network access:
   ```
   nix flake lock
   ```
   (requires Nix installed locally, or build the devcontainer once before
   the CI gate will pass — see the honesty note in `flake.nix`.) Commit
   the resulting `flake.lock`.
2. Open this repository in a Dev Containers-compatible editor (VS Code:
   "Reopen in Container"). This builds `.devcontainer/Dockerfile` — Debian
   trixie base + single-user Nix install — and starts the container with
   every Linux capability dropped except `NET_ADMIN`/`NET_RAW`, no other
   elevated privileges, and no host directories mounted beyond the
   project workspace itself.
3. On container creation, `postCreateCommand` runs
   `sudo bash .devcontainer/init-firewall.sh`, which locks egress down to
   loopback, established connections, DNS to a configured resolver, and a
   fixed allowlist of domains.
4. Verify the firewall from inside the container:
   ```
   sudo iptables -L OUTPUT -v
   ```
   You should see policy `DROP` on `OUTPUT`, with `ACCEPT` rules only for
   loopback, established/related traffic, DNS to the configured resolver,
   and the `allowed-egress` ipset.
5. Enter the pinned toolchain with `nix develop`, or install direnv and
   just `cd` into the folder — `.envrc` auto-loads it.
6. Open a pull request against `main` to see `owasp-agentic-gate.yml` run
   its seven checks against your diff.

## What's in here

```
flake.nix                 — pinned dev toolchain (Nix); see its header for
                             how to generate flake.lock (not shipped here)
.envrc                     — optional direnv auto-load of the flake devShell

.devcontainer/
  devcontainer.json    — sandbox definition: all capabilities dropped
                          except NET_ADMIN/NET_RAW, no credential-
                          directory bind mounts, runs the firewall script
                          via postCreateCommand
  Dockerfile            — Debian trixie base pinned by tag+digest,
                          single-user Nix install, non-root `agent` user,
                          sudo scoped to exactly the Nix-profile iptables
                          + ipset binaries
  init-firewall.sh      — default-deny egress firewall (ASI05)

agents/
  example-agent.yaml    — sample agent manifest; owner + expires are
                          required fields (ASI10)

aibom.json              — seed AI Bill of Materials for the example
                          agent (ASI04)

.github/workflows/
  owasp-agentic-gate.yml         — PR gate: 7 jobs, each mapped to the
                                    ASI risk it addresses
  nightly-sandbox-ttl-sweep.yml  — scheduled stub for sandbox TTL
                                    enforcement, with an honest gap noted
  policies/*.sh                  — one small script per gate job

policy/OWASP-ASI-MAPPING.md      — honest coverage table for all ten ASI
                                    risks: what's covered, how, and what
                                    isn't
policy/OWASP-DOCKER-MAPPING.md   — same honesty, for the OWASP Docker
                                    Top 10 (image, runtime, and supply-
                                    chain hardening vs. host/daemon/
                                    registry concerns out of this repo's
                                    reach)

README.md                — this file
```

## The PR gate

`owasp-agentic-gate.yml` runs on every pull request into `main`. Each job
scopes its check to `git diff` against the PR's base SHA, not the whole
repository:

| Job | ASI risk | Script |
|---|---|---|
| `secrets-scan` | ASI03 — Identity & Privilege Abuse | `policies/check-secrets-scan.sh` |
| `sandbox-integrity` | ASI05 — Unexpected Code Execution | `policies/check-sandbox-integrity.sh` |
| `aibom-updated` | ASI04 — Agentic Supply Chain | `policies/check-aibom-updated.sh` |
| `flake-lock-pinned` | ASI04 — Agentic Supply Chain (toolchain pinning) | `policies/check-flake-lock.sh` |
| `cost-tags` | spend accountability for IaC changes | `policies/check-cost-tags.sh` |
| `dangerous-flags` | ASI02 / ASI09 — Tool Misuse & Trust Exploitation | `policies/check-dangerous-flags.sh` |
| `agent-lifecycle` | ASI10 — Rogue Agents | `policies/check-agent-lifecycle.sh` |

`flake.lock` isn't committed in this starter repo, on purpose — see the
header comment in `flake.nix`. Until someone generates and commits the
real one, `flake-lock-pinned` will fail on every PR; that's intentional
honesty over a fabricated lock file, not a bug.

## Supply-chain hardening in the CI gate itself

The gate that checks this repo's supply chain has its own supply chain, so
it's held to the same standard:

- `actions/checkout` is pinned by commit SHA, not the mutable `@v7` tag
  (`# v7.0.1` alongside it for readability) — a re-tagged or compromised
  upstream action can't silently change what runs.
- Both workflows declare an explicit `permissions:` block — read-only for
  the PR gate (it only diffs and scans, never writes back), and empty for
  the nightly stub (it doesn't check out the repo or call the API at all).
- The two binaries fetched over the network — the Nix installer in
  `Dockerfile` and gitleaks in `check-secrets-scan.sh` — are pinned to a
  specific version and checked against a sha256 published by the
  upstream project, instead of a bare `curl | sh`/unverified download.
- The devcontainer's base image is pinned by tag *and* content digest
  (see `Dockerfile`), and `--cap-drop=ALL` runs before the two
  `--cap-add` flags in `devcontainer.json` — the container gets only the
  two capabilities it actually uses, not Docker's broader default set.

All version pins above (base image, Nix, gitleaks, `actions/checkout`)
were current as of July 2026. They're concrete values, not `latest`, so
a future bump shows up as a reviewable line in a diff — see
`policy/OWASP-DOCKER-MAPPING.md` (D07) for the honest caveat that nothing
in this repo automates *making* that bump yet.

## Wiring this into a real environment

- **Secrets scan**: `check-secrets-scan.sh` installs and runs gitleaks —
  review its ruleset against your actual key formats.
- **AIBOM check**: currently just checks *presence* of an update, not
  correctness. Swap in a real SCA/AI-inventory tool for CVE-level data.
- **Credentials**: the devcontainer intentionally mounts nothing from the
  host. Wire real auth via Workload Identity Federation (Entra ID, AWS IAM,
  or GCP as the issuer) rather than adding an API key mount back in.
- **Cost tags**: the tag check is a naive grep. Point it at your actual
  Bicep/Terraform module conventions once those exist.
- **TTL sweep**: only reaches cloud-hosted sandboxes. Local devcontainers on
  a laptop need a local watchdog, or should be moved off laptops entirely
  (Codespaces / cloud devpod) if TTL enforcement is a hard requirement.
- **Nix single-user mode**: fine for an ephemeral, one-user-per-container
  sandbox, which is what this is. If you later run Nix somewhere with
  multiple concurrent users sharing a host, switch to the multi-user
  install (nix-daemon) instead — single-user mode doesn't isolate build
  users from each other the way the daemon does.

## What this does NOT cover

This repo is a pre-merge CI gate plus a sandboxed container — it cannot
observe an agent's live behavior, and it isn't a substitute for host- or
registry-level Docker hardening. Two honest breakdowns cover this in
full:

- [`policy/OWASP-ASI-MAPPING.md`](policy/OWASP-ASI-MAPPING.md) — goal
  hijacking (ASI01), memory/context poisoning (ASI06), insecure
  inter-agent communication (ASI07), and cascading failures (ASI08) all
  require runtime behavioral monitoring that no static file check or PR
  gate can provide.
- [`policy/OWASP-DOCKER-MAPPING.md`](policy/OWASP-DOCKER-MAPPING.md) —
  securing the Docker host and daemon, registry access control/image
  signing, and centralized container log collection are all
  infrastructure decisions that belong to wherever this container
  actually runs, not to a devcontainer definition in a git repo.

`nightly-sandbox-ttl-sweep.yml` is also explicitly a stub — it cannot
reach sandboxes running on a developer's local Docker daemon; that gap
needs either a local watchdog process or moving sandboxes off laptops
entirely.
