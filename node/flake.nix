{
  description = "A Nix-flake-based Node.js development environment with pre-commit hooks";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    git-hooks-nix.url = "github:cachix/git-hooks.nix";
    git-hooks-nix.inputs.nixpkgs.follows = "nixpkgs";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = inputs @ {
    self,
    flake-parts,
    ...
  }:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];

      imports = [inputs.git-hooks-nix.flakeModule];

      perSystem = {
        system,
        pkgs,
        lib,
        config,
        ...
      }: let
        # Pick your preferred Node.js; 22 = current, 20 = LTS as of 2025.
        node = pkgs.nodejs_20;
        npml = pkgs.nodePackages_latest;
      in {
        devShells.default = pkgs.mkShell {
          packages = [
            node
            npml.pnpm
            npml.yarn
            npml.typescript
            npml.eslint
            npml.prettier
          ];

          shellHook = ''
            # Ensure Corepack shims are enabled so pnpm/yarn work like on stock Node installs.
            if command -v corepack >/dev/null 2>&1; then
              corepack enable >/dev/null 2>&1 || true
            fi

            # Keep npm cache local to the project to avoid permissions issues in Nix shells.
            export npm_config_cache="$PWD/.npm-cache"
          '';
        };

        # Mirror the Python flake's pre-commit setup, adjusted for JS/TS
        pre-commit = {
          check.enable = true;

          settings = {
            # Hooks that operate on the working tree or staged files.
            hooks = {
              prettier = {
                enable = true;
                entry = "${npml.prettier}/bin/prettier --write";
                files = "\\.(js|jsx|ts|tsx|json|yaml|yml|md)$";
              };
              eslint = {
                enable = true;
                entry = "${npml.eslint}/bin/eslint --fix";
                files = "\\.(js|jsx|ts|tsx)$";
              };
            };

            # Ensure tools are available to hooks at runtime (parity with the Python flake's pattern)
            enabledPackages =
              (config.pre-commit.settings.enabledPackages or [])
              ++ [
                node
                npml.pnpm
                npml.yarn
                npml.typescript
                npml.eslint
                npml.prettier
              ];
          };
        };
      };

      flake = {};
    };
}
