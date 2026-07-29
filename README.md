# owasp-driven-dev-env

A sandboxed development environment for teams using AI coding agents,
built around the controls described in the OWASP Top 10 for Agentic
Applications (2026): a firewalled devcontainer with no static credentials,
a pinned (Nix) dev toolchain, an agent manifest format that can't go
ownerless, an AI Bill of Materials, and a pull-request gate that enforces
all of the above before merge.

The default-deny egress firewall itself is packaged separately as a
reusable [Dev Container Feature](https://containers.dev/features) —
`agentic-sandbox-firewall` — so any project can add it to its own
devcontainer, not just this one. This repo both publishes that Feature
and dogfoods it in its own `.devcontainer/`.

Licensed under MIT — see [`LICENSE`](LICENSE).

## Using just the firewall in your own project

Add this to your own `devcontainer.json`:

```json
{
  "runArgs": ["--cap-drop=ALL"],
  "features": {
    "ghcr.io/radicalkjax/owasp-driven-dev-env/agentic-sandbox-firewall:1": {
      "remoteUser": "vscode"
    }
  }
}
```

No `postCreateCommand`/`postStartCommand` wiring needed — the Feature
declares its own `capAdd` (`NET_ADMIN`, `NET_RAW`) and its own
`entrypoint`, which re-applies the firewall on *every* container start
(not just first creation, unlike a plain `postCreateCommand`). See
[`src/agentic-sandbox-firewall/README.md`](src/agentic-sandbox-firewall/README.md)
for the full option reference and known limitations.

## Quick start (this whole repo)

1. Open this repository in a Dev Containers-compatible editor (VS Code:
   "Reopen in Container"). This builds `.devcontainer/Dockerfile` — Debian
   trixie base + single-user Nix install — then applies the
   `agentic-sandbox-firewall` Feature (referenced locally from
   `src/agentic-sandbox-firewall/`) on top: every Linux capability
   dropped except `NET_ADMIN`/`NET_RAW`, no host directories mounted
   beyond the project workspace itself.
2. Verify the firewall from inside the container:
   ```
   sudo iptables -L OUTPUT -v
   ```
   You should see policy `DROP` on `OUTPUT`, with `ACCEPT` rules only for
   loopback, established/related traffic, DNS to the configured resolver,
   and the `allowed-egress` ipset.
3. Enter the pinned toolchain with `nix develop`, or install direnv and
   just `cd` into the folder — `.envrc` auto-loads it.
4. Open a pull request against `main` to see `owasp-agentic-gate.yml` run
   its seven checks against your diff.

## Cutting a release

`release-features.yml` publishes `src/agentic-sandbox-firewall` to
`ghcr.io/radicalkjax/owasp-driven-dev-env/agentic-sandbox-firewall` when
a GitHub Release is published (or on-demand via `workflow_dispatch`).
Bump `version` in `src/agentic-sandbox-firewall/devcontainer-feature.json`
(semver), merge that, then cut a GitHub Release from `main` — the
workflow does the rest, including opening a follow-up PR with regenerated
option-reference docs.

## What's in here

```
LICENSE                    — MIT
flake.nix                  — pinned dev toolchain (Nix) for THIS repo's own
                              contributor sandbox
flake.lock                  — real, verified lock file (see flake.nix's
                              header for how it was generated and how to
                              regenerate it after changing an input)
.envrc                      — optional direnv auto-load of the flake devShell

src/agentic-sandbox-firewall/  — the published, reusable Dev Container
                                   Feature: default-deny egress firewall
                                   (ASI05), installable in ANY project
  devcontainer-feature.json    — id/version/options/capAdd/entrypoint
  install.sh                    — build-time setup; generates the
                                   runtime firewall script from options
  README.md                     — usage + option reference for consumers

.devcontainer/              — THIS repo's own contributor sandbox
                              (dogfoods the Feature above via a local
                              "features" reference, plus this repo's own
                              Nix-based toolchain — unrelated to what the
                              published Feature requires)
  devcontainer.json           — --cap-drop=ALL, no credential-directory
                                 bind mounts, references
                                 ../src/agentic-sandbox-firewall locally
  Dockerfile                   — Debian trixie base pinned by tag+digest,
                                 single-user Nix install, non-root
                                 `agent` user

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
  release-features.yml           — publishes src/agentic-sandbox-firewall
                                    to ghcr.io on release
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

`sandbox-integrity` checks both halves of the split above: the
`agentic-sandbox-firewall` Feature's own files/declared capabilities
under `src/`, and that this repo's own `.devcontainer/devcontainer.json`
still references it and still runs `--cap-drop=ALL`.

`flake.lock` is committed and real — genuinely produced by running
`nix flake lock`, not hand-written (see `flake.nix`'s header). If you
change an input, regenerate it the same way and commit the result;
`flake-lock-pinned` fails the PR otherwise.

## Supply-chain hardening in the CI gate itself

The gate that checks this repo's supply chain has its own supply chain, so
it's held to the same standard:

- `actions/checkout` and `devcontainers/action` are pinned by commit SHA,
  not a mutable tag (version noted in a comment alongside each) — a
  re-tagged or compromised upstream action can't silently change what runs.
- Every workflow declares an explicit `permissions:` block, scoped to
  only what that workflow actually does.
- The two binaries fetched over the network — the Nix installer in
  `Dockerfile` and gitleaks in `check-secrets-scan.sh` — are pinned to a
  specific version and checked against a sha256 published by the
  upstream project, instead of a bare `curl | sh`/unverified download.
- The devcontainer's base image is pinned by tag *and* content digest
  (see `Dockerfile`), and `--cap-drop=ALL` runs before the
  `agentic-sandbox-firewall` Feature adds back only what it needs.

All version pins above (base image, Nix, gitleaks, `actions/checkout`,
`devcontainers/action`) were current as of July 2026. They're concrete
values, not `latest`, so a future bump shows up as a reviewable line in a
diff — see `policy/OWASP-DOCKER-MAPPING.md` (D07) for the honest caveat
that nothing in this repo automates *making* that bump yet.

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
  sandbox, which is what this repo's own `.devcontainer` is. If you later
  run Nix somewhere with multiple concurrent users sharing a host, switch
  to the multi-user install (nix-daemon) instead.
- **The published Feature is apt-only for now**: `src/agentic-sandbox-firewall/install.sh`
  auto-installs `iptables`/`ipset`/`dig` via apt if they're not already on
  `PATH`. On a non-Debian/Ubuntu base image without those already
  installed, it fails loudly rather than silently doing nothing — see
  its README for details.

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
  securing the Docker host and daemon, and centralized container log
  collection, are infrastructure decisions that belong to wherever this
  container actually runs, not to a devcontainer definition in a git repo.

`nightly-sandbox-ttl-sweep.yml` is also explicitly a stub — it cannot
reach sandboxes running on a developer's local Docker daemon; that gap
needs either a local watchdog process or moving sandboxes off laptops
entirely.
