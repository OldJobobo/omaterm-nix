{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    omaterm.url = "github:OldJobobo/omaterm-nix/nixos";
  };

  outputs = { nixpkgs, home-manager, omaterm, ... }: {
    nixosConfigurations.server = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
        omaterm.nixosModules.omaterm
        home-manager.nixosModules.home-manager
        ({ lib, ... }: {
          system.stateVersion = lib.mkDefault "25.05";
          networking.hostName = lib.mkForce "server";
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
            enableTailscale = true;
          };

          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.omaterm = {
            imports = [ omaterm.homeManagerModules.omaterm ];
            programs.omaterm.enable = true;
            home.stateVersion = "25.05";
          };
        })
      ];
    };
  };
}
