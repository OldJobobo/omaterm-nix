#!/usr/bin/env bash
set -euo pipefail

if [ ! -f /etc/NIXOS ]; then
  echo "This bootstrap is only for NixOS."
  exit 1
fi

prompt() {
  local label="$1"
  local default="$2"
  local value

  printf "%s [%s]: " "$label" "$default" > /dev/tty
  IFS= read -r value < /dev/tty
  echo "${value:-$default}"
}

prompt_optional() {
  local label="$1"
  local value

  printf "%s: " "$label" > /dev/tty
  IFS= read -r value < /dev/tty
  echo "$value"
}

validate_hostname() {
  local value="$1"

  if [[ ! "$value" =~ ^[A-Za-z0-9][A-Za-z0-9-]*$ ]]; then
    echo "Use a host name containing only letters, numbers, and hyphens." >&2
    exit 1
  fi
}

validate_username() {
  local value="$1"

  if [[ ! "$value" =~ ^[a-z_][a-z0-9_-]*[$]?$ ]]; then
    echo "Use a Linux username like 'omaterm' or 'alice'." >&2
    exit 1
  fi
}

system_arch() {
  case "$(uname -m)" in
    x86_64) echo "x86_64-linux" ;;
    aarch64|arm64) echo "aarch64-linux" ;;
    *)
      echo "Unsupported architecture: $(uname -m)" >&2
      exit 1
      ;;
  esac
}

confirm() {
  local prompt="$1"
  local reply

  printf "%s [Y/n] " "$prompt" > /dev/tty
  IFS= read -r reply < /dev/tty
  case "${reply,,}" in
    ""|y|yes) return 0 ;;
    *) return 1 ;;
  esac
}

if [ -e /etc/nixos/flake.nix ] && [ "${OMATERM_OVERWRITE_NIXOS_FLAKE:-0}" != "1" ]; then
  echo "/etc/nixos/flake.nix already exists."
  echo "Set OMATERM_OVERWRITE_NIXOS_FLAKE=1 to replace it."
  exit 1
fi

flake_url="${OMATERM_FLAKE_URL:-github:omacom-io/omaterm}"
host="$(prompt "NixOS host name" "${HOSTNAME:-server}")"
user="$(prompt "Omaterm user" "omaterm")"
ssh_key="$(prompt_optional "SSH public key for $user (leave empty to skip)")"
system="$(system_arch)"

validate_hostname "$host"
validate_username "$user"

authorized_keys="[]"
if [ -n "$ssh_key" ]; then
  authorized_keys="[ \"$ssh_key\" ]"
fi

tmpfile="$(mktemp)"
trap 'rm -f "$tmpfile"' EXIT

cat > "$tmpfile" <<EOF
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    omaterm.url = "$flake_url";
  };

  outputs = { nixpkgs, home-manager, omaterm, ... }: {
    nixosConfigurations."$host" = nixpkgs.lib.nixosSystem {
      system = "$system";
      modules = [
        ./hardware-configuration.nix
        omaterm.nixosModules.omaterm
        home-manager.nixosModules.home-manager
        {
          system.stateVersion = "25.05";
          networking.hostName = "$host";
          nix.settings.experimental-features = [ "nix-command" "flakes" ];

          programs.omaterm = {
            enable = true;
            user = "$user";
            createUser = true;
            authorizedKeys = $authorized_keys;
            enableDocker = true;
            enableSSH = true;
            enableTailscale = false;
          };

          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users."$user" = {
            imports = [ omaterm.homeManagerModules.omaterm ];
            programs.omaterm.enable = true;
            home.stateVersion = "25.05";
          };
        }
      ];
    };
  };
}
EOF

sudo install -d /etc/nixos
sudo install -m 0644 "$tmpfile" /etc/nixos/flake.nix

echo "Wrote /etc/nixos/flake.nix for host '$host' and user '$user'."

if [ -z "$ssh_key" ]; then
  echo "No SSH key was configured. Add a key or password before relying on remote access."
fi

if confirm "Run nixos-rebuild now?"; then
  sudo nixos-rebuild switch --flake "/etc/nixos#$host"
else
  echo "Apply it later with: sudo nixos-rebuild switch --flake /etc/nixos#$host"
fi
