{
  description = "Omaterm headless terminal environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
    }:
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
          lazyvim-starter = pkgs.callPackage ./nix/packages/lazyvim-starter.nix { };
          omadots = pkgs.callPackage ./nix/packages/omadots.nix { };
          omaterm-nixos-bootstrap = pkgs.writeShellApplication {
            name = "omaterm-nixos-bootstrap";
            text = builtins.readFile ./install/nixos.sh;
          };
        in
        {
          inherit
            lazyvim-starter
            omadots
            omaterm-scripts
            omaterm-nixos-bootstrap
            ;
          default = omaterm-scripts;
        }
      );

      apps = forAllSystems (system: {
        nixos-bootstrap = {
          type = "app";
          program = "${self.packages.${system}.omaterm-nixos-bootstrap}/bin/omaterm-nixos-bootstrap";
          meta.description = "Bootstrap a fresh headless NixOS system with Omaterm";
        };
      });

      nixosModules = rec {
        omaterm = ./nix/modules/nixos/omaterm.nix;
        default = omaterm;
      };

      homeManagerModules = rec {
        omaterm = ./nix/modules/home-manager/omaterm.nix;
        default = omaterm;
      };

      templates = {
        headless = {
          path = ./templates/headless;
          description = "Fresh headless NixOS system with Omaterm and Home Manager";
        };
        default = self.templates.headless;
      };

      checks = forAllSystems (
        system:
        {
          omaterm-scripts = self.packages.${system}.omaterm-scripts;
          omaterm-nixos-bootstrap = self.packages.${system}.omaterm-nixos-bootstrap;
          lazyvim-starter = self.packages.${system}.lazyvim-starter;
          omadots = self.packages.${system}.omadots;

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
                  authorizedKeys = [
                    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAITestKeyOnlyForEvaluation omaterm@example"
                  ];
                };
              }
            ];
          }).config.system.build.toplevel;

          home-manager-module = (
            home-manager.lib.homeManagerConfiguration {
              pkgs = import nixpkgs { inherit system; };
              modules = [
                self.homeManagerModules.omaterm
                {
                  home = {
                    username = "omaterm";
                    homeDirectory = "/home/omaterm";
                    stateVersion = "25.05";
                  };

                  programs.omaterm = {
                    enable = true;
                    theme = "default";
                  };
                }
              ];
            }
          ).activationPackage;
        }
      );
    };
}
