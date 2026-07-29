
# Agentic Sandbox Firewall (agentic-sandbox-firewall)

Default-deny egress firewall for AI-agent devcontainers (OWASP ASI05: Unexpected Code Execution). Blocks all outbound traffic except loopback, established connections, DNS to a configured resolver, and an explicit domain allowlist. Re-applies on every container start via the container entrypoint, not just first creation.

## Example Usage

```json
"features": {
    "ghcr.io/radicalkjax/owasp-driven-dev-env/agentic-sandbox-firewall:1": {}
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| remoteUser | Non-root username this devcontainer runs as. A sudoers rule scoped to exactly this user — and exactly iptables/ipset, nothing else — is created for it. | string | vscode |
| allowedDomains | Comma-separated allowlist of domains the container may reach. Resolved to IPs every time the container starts. | string | api.anthropic.com,github.com,codeload.github.com,registry.npmjs.org,pypi.org,files.pythonhosted.org |
| dnsResolver | DNS resolver the container is allowed to query. Replace with an internal/corporate resolver if your policy requires one. | string | 1.1.1.1 |



---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/radicalkjax/owasp-driven-dev-env/blob/main/src/agentic-sandbox-firewall/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
