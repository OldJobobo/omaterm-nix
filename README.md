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

Use the NixOS module instead of the shell installer:

```nix
{
  inputs.omaterm.url = "github:omacom-io/omaterm";

  outputs = { nixpkgs, omaterm, ... }: {
    nixosConfigurations.server = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        omaterm.nixosModules.omaterm
        {
          programs.omaterm = {
            enable = true;
            user = "john";
            enableDocker = true;
            enableSSH = true;
            enableTailscale = false;
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

- **Shell**: Bash with starship prompt, fzf, eza, zoxide
- **Editors**: Neovim (LazyVim), opencode, claude-code
- **Dev tools**: mise, docker, GitHub CLI (`gh`), lazygit, lazydocker
- **Networking**: SSH, tailscale
- **Git**: Interactive config for user name/email, helpful aliases

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
