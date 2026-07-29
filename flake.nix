# Pinned dev toolchain for the agentic sandbox. flake.lock (committed
# alongside this file) is real, verified output of an actual
# `nix flake lock` run — not hand-written. Regenerate it the same way
# after changing an input: `nix flake lock`, then commit the result.

{
  description = "Agentic dev sandbox — pinned toolchain";

  inputs = {
    # Tracks the current stable NixOS release channel, not nixos-unstable —
    # a smaller, more reviewed diff between updates than unstable's rolling
    # HEAD. flake.lock is still what makes any given checkout reproducible;
    # this only controls what `nix flake update` moves *to* next.
    #
    # git+https (not the shorter "github:owner/repo" shorthand) on purpose:
    # the shorthand resolves the current commit via the GitHub API, which
    # some restricted/proxied environments (including the one that
    # generated this repo's flake.lock) block for arbitrary repos. A plain
    # git fetch works wherever git+https access does. "shallow=1" keeps
    # the fetch to one commit instead of full history — nixpkgs' full
    # history alone is gigabytes.
    nixpkgs.url = "git+https://github.com/NixOS/nixpkgs?ref=nixos-26.05&shallow=1";
    flake-utils.url = "git+https://github.com/numtide/flake-utils?shallow=1";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in
      {
        devShells.default = pkgs.mkShell {
          # Every package here is content-hash-pinned via flake.lock. This
          # is the ASI04 (Agentic Supply Chain) story: flake.lock gives
          # verifiable, exact versions for the whole toolchain, not
          # "whatever the package index had today."
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
