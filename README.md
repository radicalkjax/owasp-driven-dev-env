# owasp-driven-dev-env

A sandboxed development environment for teams using AI coding agents,
built around the controls described in the OWASP Top 10 for Agentic
Applications (2026): a firewalled devcontainer with no static credentials,
an agent manifest format that can't go ownerless, an AI Bill of Materials,
and a pull-request gate that enforces all of the above before merge.

## Quick start

1. Open this repository in a Dev Containers-compatible editor (VS Code:
   "Reopen in Container"). This builds `.devcontainer/Dockerfile` and
   starts the container with only `NET_ADMIN`/`NET_RAW` added — no other
   elevated privileges, and no host directories mounted beyond the
   project workspace itself.
2. On container creation, `postCreateCommand` runs
   `sudo bash .devcontainer/init-firewall.sh`, which locks egress down to
   loopback, established connections, DNS to a configured resolver, and a
   fixed allowlist of domains.
3. Verify the firewall from inside the container:
   ```
   sudo iptables -L OUTPUT -v
   ```
   You should see policy `DROP` on `OUTPUT`, with `ACCEPT` rules only for
   loopback, established/related traffic, DNS to the configured resolver,
   and the `allowed-egress` ipset.
4. Open a pull request against `main` to see `owasp-agentic-gate.yml` run
   its six checks against your diff.

## What's in here

```
.devcontainer/
  devcontainer.json    — sandbox definition: NET_ADMIN/NET_RAW only, no
                          credential-directory bind mounts, runs the
                          firewall script via postCreateCommand
  Dockerfile            — minimal Debian base, non-root `agent` user,
                          sudo scoped to exactly iptables + ipset
  init-firewall.sh      — default-deny egress firewall (ASI05)

agents/
  example-agent.yaml    — sample agent manifest; owner + expires are
                          required fields (ASI10)

aibom.json              — seed AI Bill of Materials for the example
                          agent (ASI04)

.github/workflows/
  owasp-agentic-gate.yml         — PR gate: 6 jobs, each mapped to the
                                    ASI risk it addresses
  nightly-sandbox-ttl-sweep.yml  — scheduled stub for sandbox TTL
                                    enforcement, with an honest gap noted
  policies/*.sh                  — one small script per gate job

policy/OWASP-ASI-MAPPING.md      — honest coverage table for all ten ASI
                                    risks: what's covered, how, and what
                                    isn't

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
| `cost-tags` | spend accountability for IaC changes | `policies/check-cost-tags.sh` |
| `dangerous-flags` | ASI02 / ASI09 — Tool Misuse & Trust Exploitation | `policies/check-dangerous-flags.sh` |
| `agent-lifecycle` | ASI10 — Rogue Agents | `policies/check-agent-lifecycle.sh` |

## What this does NOT cover

This repo is a pre-merge CI gate plus a sandboxed container — it cannot
observe an agent's live behavior. See
[`policy/OWASP-ASI-MAPPING.md`](policy/OWASP-ASI-MAPPING.md) for the full,
honest breakdown, but in short: goal hijacking (ASI01), memory/context
poisoning (ASI06), insecure inter-agent communication (ASI07), and
cascading failures (ASI08) all require runtime behavioral monitoring that
no static file check or PR gate can provide. `nightly-sandbox-ttl-sweep.yml`
is also explicitly a stub — it cannot reach sandboxes running on a
developer's local Docker daemon; that gap needs either a local watchdog
process or moving sandboxes off laptops entirely.
