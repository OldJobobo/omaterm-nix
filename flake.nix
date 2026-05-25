{
  description = "Omaterm headless terminal environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      supportedSystems = [
        "aarch64-linux"
        "x86_64-linux"
      ];

      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
          omaterm-scripts = pkgs.callPackage ./nix/packages/omaterm-scripts.nix {
            src = ./.;
          };
        in
        {
          inherit omaterm-scripts;
          default = omaterm-scripts;
        }
      );

      nixosModules = rec {
        omaterm = ./nix/modules/nixos/omaterm.nix;
        default = omaterm;
      };

      checks = forAllSystems (
        system:
        {
          omaterm-scripts = self.packages.${system}.omaterm-scripts;

          nixos-module = (nixpkgs.lib.nixosSystem {
            inherit system;
            modules = [
              self.nixosModules.omaterm
              {
                boot.loader.grub.enable = false;
                fileSystems."/" = {
                  device = "test";
                  fsType = "ext4";
                };
                system.stateVersion = "25.05";

                programs.omaterm = {
                  enable = true;
                  user = "omaterm";
                  createUser = true;
                  enableTailscale = true;
                };
              }
            ];
          }).config.system.build.toplevel;
        }
      );
    };
}
