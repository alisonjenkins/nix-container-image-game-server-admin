{
  description = "An lsyncd container image created using Nix";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    ali-neovim.url = "github:alisonjenkins/neovim-nix-flake";
  };

  outputs = {self, ...} @ inputs:
    inputs.flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import inputs.nixpkgs {
        inherit system;
      };

      pkgs_arm64 = import inputs.nixpkgs {
        system = "aarch64-linux";
      };

      admin_shell = {
        pkgs,
        system,
      }:
        with pkgs; [
          dockerTools.binSh
          dockerTools.caCertificates
          htop
          inputs.ali-neovim.packages.${system}.nvim
          netcat-gnu
          rconc
          rdiff-backup
          rsync
          tmux
        ];

      sleep_script = {pkgs}:
        pkgs.writeShellScriptBin ''sleep_script'' ''
          while true; do
            sleep 3600
          done
        '';

      container_x86_64 = pkgs.dockerTools.buildLayeredImage {
        name = "game-server-admin";
        tag = "latest-x86_64";
        config.Cmd = ["/bin/sleep_script"];
        contents = pkgs.buildEnv {
          name = "image-root";
          paths =
            [(sleep_script {inherit pkgs;})]
            ++ admin_shell {
              inherit pkgs;
              system = "x86_64-linux";
            };
          pathsToLink = ["/bin" "/etc" "/var"];
        };
      };

      container_aarch64 = pkgs.pkgsCross.aarch64-multiplatform.dockerTools.buildLayeredImage {
        name = "game-server-admin";
        tag = "latest-aarch64";
        config.Cmd = ["/bin/lsyncd"];
        contents = pkgs.pkgsCross.aarch64-multiplatform.buildEnv {
          name = "image-root";
          paths =
            [(sleep_script {pkgs = pkgs_arm64;})]
            ++ admin_shell {
              inherit pkgs;
              system = "arm64-linux";
            };
          pathsToLink = ["/bin" "/etc" "/var"];
        };
      };
    in {
      packages = {
        container_x86_64 = container_x86_64;
        container_aarch64 = container_aarch64;
      };

      devShells.default = pkgs.mkShell {
        packages = [
          pkgs.just
          pkgs.podman
          pkgs.rdiff-backup
        ];
      };
    });
}
