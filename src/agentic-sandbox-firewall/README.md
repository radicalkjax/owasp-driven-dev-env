# Agentic Sandbox Firewall

Default-deny egress firewall for AI-agent devcontainers ([OWASP ASI05: Unexpected Code Execution](https://github.com/OWASP/www-project-top-10-for-agentic-applications-owasp-asi)) — even if an agent generates and runs arbitrary code, it cannot exfiltrate data or reach an unapproved host, because only allowlisted destinations are reachable.

## Example Usage

```json
"features": {
    "ghcr.io/radicalkjax/owasp-driven-dev-env/agentic-sandbox-firewall:1": {
        "remoteUser": "vscode",
        "allowedDomains": "api.anthropic.com,github.com,registry.npmjs.org",
        "dnsResolver": "1.1.1.1"
    }
}
```

Your own `devcontainer.json` also needs `--cap-drop=ALL` in `runArgs` if you want the container to run with *no* Linux capabilities beyond what this Feature adds back (`NET_ADMIN`/`NET_RAW`, declared automatically via this Feature's `capAdd` — you don't need to add those two yourself):

```json
"runArgs": ["--cap-drop=ALL"]
```

## What this does

- Blocks all outbound traffic by default (`iptables -P OUTPUT DROP`).
- Allows loopback and already-established/related connections.
- Allows DNS only to the configured resolver, not to arbitrary hosts.
- Resolves the configured domain allowlist to IPs and allows only those, via an `ipset`.
- Re-applies on **every** container start (via this Feature's `entrypoint`), not just first creation — `postCreateCommand` alone would miss re-applying after a plain stop/start, since iptables rules live in the container's network namespace and don't survive that cycle.

## Known limitations

- Domains are resolved to IPs once, per container start. A domain behind a rotating IP (a CDN or load balancer) may need the container restarted to pick up a new IP, or you may want to replace the `ipset` approach with an SNI-aware egress proxy for that case.
- Dependency install (`iptables`, `ipset`, `dig`) is currently apt-only. If your base image already provides these (for example via Nix), this Feature detects and reuses them instead of installing a second copy. On a non-apt base image that doesn't already provide them, installation fails loudly rather than silently doing nothing — see `install.sh`.

## Options

| Option | Type | Default | Description |
|---|---|---|---|
| `remoteUser` | string | `vscode` | Non-root username the sudoers rule is scoped to. |
| `allowedDomains` | string | `api.anthropic.com,github.com,codeload.github.com,registry.npmjs.org,pypi.org,files.pythonhosted.org` | Comma-separated domain allowlist. |
| `dnsResolver` | string | `1.1.1.1` | DNS resolver the container may query. |
