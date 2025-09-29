{
  description = "A Nix-flake-based Java development environment with pre-commit shell hook";

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
      imports = [
        inputs.git-hooks-nix.flakeModule
      ];
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      perSystem = {
        config,
        pkgs,
        lib,
        system,
        ...
      }: let
        # ---- Version switch (change this and everything follows) ----
        jdkVersion = 21; # prefer LTS by default (e.g. 17, 21). You can try 23 if available.

        # Try to pick pkgs.jdk${jdkVersion} if it exists; otherwise fall back to pkgs.jdk
        jdkAttr = "jdk" + builtins.toString jdkVersion;
        jdkPackage =
          if builtins.hasAttr jdkAttr pkgs
          then builtins.getAttr jdkAttr pkgs
          else pkgs.jdk;

        # Convenience handles
        maven = pkgs.maven;
        gradle = pkgs.gradle;
        jdtls = pkgs.jdt-language-server;
      in {
        # Make `nix fmt` work like in the Python flake
        formatter = pkgs.alejandra;

        # Pre-commit using cachix/git-hooks.nix, mirroring the Python flake’s setup
        pre-commit.settings = {
          src = ./.;
          hooks = {
            alejandra.enable = true;
            # Add more if you like (editorconfig-checker, commitizen, etc.)
            # editorconfig-checker.enable = true;
            # commitizen.enable = true;
          };
        };

        # A ready-to-use Java dev shell
        devShells.default = pkgs.mkShell {
          # Install and wire up pre-commit, echo a friendly banner
          shellHook = ''
            ${config.pre-commit.installationScript}
          '';

          # Keep the pattern from the Python flake: include hook-required packages, then your tools
          packages =
            config.pre-commit.settings.enabledPackages
            ++ [
              jdkPackage
              maven
              gradle
              jdtls
            ];

          # If you want MAVEN_OPTS / GRADLE_OPTS, put them here
          # MAVEN_OPTS = "-Xms256m -Xmx2g";
          # GRADLE_OPTS = "-Dorg.gradle.jvmargs='-Xms256m -Xmx2g'";
        };

        # Expose useful packages (optional)
        packages = {
          default = jdkPackage;
          jdk = jdkPackage;
          maven = maven;
          gradle = gradle;
          jdtls = jdtls;
        };
      };

      # No special top-level flake outputs needed beyond what’s above
      flake = {};
    };
}
