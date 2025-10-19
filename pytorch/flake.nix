# Adapted from https://github.com/mschoder/nix-cuda-template
# This flake provides a skeleton dev environment for PyTorch with CUDA support and for CUDA development /
# compilation with NVCC.
#
# To test python:
# $ nix develop
# $ python
# >>> import torch
# >>> torch.cuda.is_available()
# >>> torch.cuda.device_count()
# >>> torch.cuda.get_device_name(0)
#
# To test CUDA (hello-world.cu):
# $ nix develop
# $ nvcc hello-world.cu -o hello
# $ ./hello
{
  description = "A flake providing a dev shell for PyTorch with CUDA and CUDA development using NVCC.";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    git-hooks-nix.inputs.nixpkgs.follows = "nixpkgs";
    git-hooks-nix.url = "github:cachix/git-hooks.nix";
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
        system,
        ...
      }: let
        pkgs = import inputs.nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };

        version = "3.12";

        concatMajorMinor = v:
          pkgs.lib.pipe v [
            pkgs.lib.versions.splitVersion
            (pkgs.lib.sublist 0 2)
            pkgs.lib.concatStrings
          ];

        python = pkgs."python${concatMajorMinor version}";
        pythonWithTorch = python.withPackages (
          ps:
            with ps; [
              torchWithCuda
              # Add other python packages here
            ]
        );

        cudaToolchain = with pkgs; [
          pythonWithTorch
          cudatoolkit
          cudaPackages.cudnn
          cudaPackages.cuda_cudart
          gcc13
        ];

        tooling = with pkgs; [
          uv
          cmake
          ninja
        ];

        cudaLibraryPath = pkgs.lib.makeLibraryPath ([
            "/run/opengl-driver"
          ]
          ++ cudaToolchain);
      in {
        _module.args.pkgs = pkgs;

        pre-commit.settings = {
          hooks = {
            alejandra.enable = true;
            ruff.enable = true;
          };
        };

        devShells.default = pkgs.mkShell {
          packages =
            config.pre-commit.settings.enabledPackages
            ++ cudaToolchain
            ++ tooling;

          shellHook = ''
            ${config.pre-commit.installationScript}
            echo 1>&2 "PyTorch/CUDA dev shell ready (Python ${version})"

            export CUDA_PATH=${pkgs.cudatoolkit}
            export CC=${pkgs.gcc13}/bin/gcc
            export CXX=${pkgs.gcc13}/bin/g++
            export PATH=${pkgs.gcc13}/bin:$PATH

            export LD_LIBRARY_PATH=${cudaLibraryPath}:$LD_LIBRARY_PATH
            export LIBRARY_PATH=${pkgs.lib.makeLibraryPath [
              pkgs.cudatoolkit
            ]}:$LIBRARY_PATH
          '';
        };

        devShells.cuda = pkgs.mkShell {
          name = "cuda-tools";
          packages = cudaToolchain;
          shellHook = ''
            echo 1>&2 "CUDA toolchain shell (NVCC + cuDNN)"
            export CC=${pkgs.gcc13}/bin/gcc
            export CXX=${pkgs.gcc13}/bin/g++
          '';
        };
      };

      flake = {};
    };
}
