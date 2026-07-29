# OWASP Top 10 for Agentic Applications (2026) — coverage mapping

This is a **pre-merge, static** CI gate plus a **sandboxed runtime container**.
Several ASI risks only manifest in an agent's live behavior — in what it
*decides* to do, not in what files look like at merge time — and no amount
of `grep` in a pipeline catches those. This document is meant to be read
honestly: it says which risks this repo actually mitigates, and names the
ones it does not, rather than implying blanket coverage.

| ASI | Risk | Covered here? | How | If not — what's still needed |
|---|---|---|---|---|
| ASI01 | Agent Goal Hijack | ❌ No | — | Runtime instruction/content isolation and human confirmation on sensitive actions. Not something a CI gate or a static file check can observe. |
| ASI02 | Tool Misuse & Exploitation | ⚠️ Partial | `check-dangerous-flags.sh` blocks permission-bypass flags (e.g. `--dangerously-skip-permissions`, `bypassPermissions`) introduced outside a sandboxed context | Full coverage needs runtime validation of actual tool-call parameters, not just static-diff pattern matching. |
| ASI03 | Identity & Privilege Abuse | ✅ Yes | `check-secrets-scan.sh` (gitleaks across the PR's full commit history); the devcontainer never bind-mounts `$HOME`, `~/.ssh`, `~/.aws`, or any credential directory — see `agents/example-agent.yaml`, which requires `credentials: workload-identity-federation` instead of a static key | Also needs periodic credential/identity review outside CI (e.g. auditing the WIF trust relationships themselves). |
| ASI04 | Agentic Supply Chain | ✅ Yes | `check-aibom-updated.sh` fails a PR that touches dependency manifests, MCP server configs, or agent YAML files without also updating `aibom.json` | The check only enforces that an update happened, not that it's correct or complete. A real SCA / AI-inventory tool should replace the hand-maintained `aibom.json` in production — see the note in that file. |
| ASI05 | Unexpected Code Execution | ✅ Yes | `check-sandbox-integrity.sh` plus the devcontainer's default-deny egress firewall (`.devcontainer/init-firewall.sh`) — even arbitrary agent-generated code can't exfiltrate data or reach an unapproved host | The firewall resolves allowlisted domains to IPs once, at container start — see the limitation comment in `init-firewall.sh`. CDN/rotating-IP domains may need periodic re-resolution or an SNI-aware egress proxy. |
| ASI06 | Memory & Context Poisoning | ❌ No | — | Runtime concern: validating writes to any persistent agent memory, keeping context stores ephemeral or signed. No CI equivalent exists. |
| ASI07 | Insecure Inter-Agent Communication | ❌ No | — | Only relevant once multiple agents communicate with each other; would need mutual auth and signed messages at runtime, not a file check. |
| ASI08 | Cascading Failures | ❌ No | — | Needs runtime circuit breakers and blast-radius isolation. `nightly-sandbox-ttl-sweep.yml` is a partial mitigation for unbounded resource sprawl (and is itself a stub — see its honest-gap note), not cascading-failure protection. |
| ASI09 | Human-Agent Trust Exploitation | ⚠️ Partial | `check-dangerous-flags.sh` (same control as ASI02) stops permission-bypass flags from being normalized outside a sandbox | Needs a UI-level control that shows the human the raw action being taken, not an agent-authored summary of it — outside what this repo can enforce. |
| ASI10 | Rogue Agents | ✅ Yes | `check-agent-lifecycle.sh` fails a PR if any file under `agents/` is missing `owner:` or `expires:` | Also needs a runtime process that actually revokes/kills an agent once its `expires` date passes — this repo only enforces that the date is *declared*, not that anything acts on it. |

**Bottom line:** 4 of 10 risks are fully covered pre-merge, 3 are partially
covered, and 3 (ASI01, ASI06, ASI07 — plus most of ASI08) require runtime
behavioral monitoring that this repository does not attempt to fake. Treat
this as "the half that's tractable in a CI gate," with the rest named
explicitly as follow-up work, not silently assumed away.
