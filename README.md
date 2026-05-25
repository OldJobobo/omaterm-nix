# Omaterm

An Omakase Terminal Setup For Arch/Debian/Ubuntu/Fedora by DHH

## Requirements

- Base Arch/Debian/Ubuntu/Fedora Linux installation, or NixOS with flakes
- Internet connection
- `sudo` privileges

## Install on Arch/Debian/Ubuntu/Fedora

```bash
curl -fsSL https://omaterm.org/install | bash
```

## Install on NixOS

Use the NixOS module instead of the shell installer.

For a fresh headless system, run the bootstrap and answer the prompts:

```bash
sudo nix --extra-experimental-features 'nix-command flakes' run github:omacom-io/omaterm#nixos-bootstrap
```

Or initialize a starter flake:

```bash
nix flake init -t github:omacom-io/omaterm#headless
```

Manual flake example:

```nix
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
          nix.settings.experimental-features = [ "nix-command" "flakes" ];

          programs.omaterm = {
            enable = true;
            user = "john";
            createUser = true;
            authorizedKeys = [ "ssh-ed25519 AAAA..." ];
            enableDocker = true;
            enableSSH = true;
            enableTailscale = false;
          };

          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.john = {
            imports = [ omaterm.homeManagerModules.omaterm ];
            programs.omaterm.enable = true;
            home.stateVersion = "25.05";
          };
        }
      ];
    };
  };
}
```

Then run:

```bash
sudo nixos-rebuild switch --flake .#server
```

## What it sets up

- **Shell**: Zsh with starship prompt, fzf, eza, zoxide
- **Editors**: Neovim (LazyVim), opencode, claude-code
- **Dev tools**: mise, docker, GitHub CLI (`gh`), lazygit, lazydocker
- **Networking**: SSH, tailscale
- **Git**: Interactive config for user name/email, helpful aliases

On NixOS, the system module manages users, packages, Docker, SSH, Tailscale,
and helper scripts. The Home Manager module manages the repo-owned user config
for Neovim, Starship, Lazygit, shell aliases, and tmux auto-start. It also
installs pinned LazyVim starter and Omadots config files declaratively, then
layers Omaterm's Neovim overrides on top.

## Docker

```bash
docker run -it -v omaterm-home:/home/omaterm ghcr.io/omacom-io/omaterm
```

The named volume persists your home directory across container restarts, including git config, gh auth, shell history, and projects.

## Interactive prompts

During installation you'll be asked for:

- Git user name
- Git email address

And you'll be offered to setup:

- Tailscale
- GitHub
- SSH public keys
