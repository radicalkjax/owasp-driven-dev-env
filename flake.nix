# Pinned dev toolchain for the agentic sandbox.
#
# HONESTY NOTE: this repo does NOT ship a flake.lock. Lock files pin exact
# content hashes for every input, and fabricating one would mean
# fabricating hashes that don't correspond to anything real — worse than
# no lock file at all. Generate the real one yourself, once, with network
# access:
#
#     nix flake lock
#
# then commit flake.lock alongside this file. The CI check
# (.github/workflows/policies/check-flake-lock.sh) enforces that it exists
# and stays in sync with flake.nix from then on.

{
  description = "Agentic dev sandbox — pinned toolchain";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in
      {
        devShells.default = pkgs.mkShell {
          # Every package here is content-hash-pinned via flake.lock once
          # it's generated. This is the ASI04 (Agentic Supply Chain) story:
          # flake.lock gives verifiable, exact versions for the whole
          # toolchain, not "whatever the package index had today."
          buildInputs = with pkgs; [
            git
            ripgrep
            curl
            jq
          ];

          shellHook = ''
            echo "Agentic dev sandbox — Nix devShell active."
            echo "Firewall status: sudo iptables -L OUTPUT -v"
          '';
        };
      });
}
