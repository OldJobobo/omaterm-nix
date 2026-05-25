{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    omaterm.url = "github:omacom-io/omaterm";
  };

  outputs = { nixpkgs, home-manager, omaterm, ... }: {
    nixosConfigurations.server = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./hardware-configuration.nix
        omaterm.nixosModules.omaterm
        home-manager.nixosModules.home-manager
        {
          system.stateVersion = "25.05";
          networking.hostName = "server";
          nix.settings.experimental-features = [ "nix-command" "flakes" ];

          programs.omaterm = {
            enable = true;
            user = "omaterm";
            createUser = true;
            authorizedKeys = [
              # "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI... you@example"
            ];
            enableDocker = true;
            enableSSH = true;
            enableTailscale = false;
          };

          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.omaterm = {
            imports = [ omaterm.homeManagerModules.omaterm ];
            programs.omaterm.enable = true;
            home.stateVersion = "25.05";
          };
        }
      ];
    };
  };
}
