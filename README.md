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
sudo nix --extra-experimental-features 'nix-command flakes' run github:OldJobobo/omaterm-nix/nixos#nixos-bootstrap
```

The bootstrap writes `/etc/nixos/flake.nix` and an imported
`/etc/nixos/omaterm-bootloader.nix` bootloader module. The bootloader module is
generated from the machine's current boot mode:

- UEFI systems use systemd-boot and disable GRUB.
- Legacy BIOS systems use GRUB on the detected root disk.
- Legacy BIOS systems on GPT must already have a BIOS Boot Partition; without
  that partition, GRUB cannot be installed permanently.

When rerun with `OMATERM_OVERWRITE_NIXOS_FLAKE=1`, the bootstrap also removes
`/etc/nixos/flake.lock` so Nix locks the refreshed inputs instead of reusing an
older failed bootstrap lock file.

Or initialize a starter flake:

```bash
nix flake init -t github:OldJobobo/omaterm-nix/nixos#headless
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
        })
      ];
    };
  };
}
```

Then run:

```bash
sudo nixos-rebuild switch --flake .#server
```

### Bootloader activation failure

The bootstrap imports your existing `/etc/nixos/configuration.nix`, then imports
`/etc/nixos/omaterm-bootloader.nix` after it so stale bootloader settings can be
overridden. If `nixos-rebuild switch` still fails while installing GRUB, for
example with:

```text
this GPT partition label contains no BIOS Boot Partition
embedding is not possible
Failed to install bootloader
```

fix the bootloader settings in `/etc/nixos/configuration.nix` before relying on
a reboot. On legacy BIOS with GPT, this usually means creating a 1 MiB BIOS Boot
Partition or reinstalling/booting in UEFI mode. To activate Omaterm for the
running system while you fix that, run:

```bash
sudo nixos-rebuild test --flake /etc/nixos#YOUR_HOST
```

`test` activates the system without updating the bootloader. After the
bootloader config is fixed, make it persistent with:

```bash
sudo nixos-rebuild switch --flake /etc/nixos#YOUR_HOST
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
