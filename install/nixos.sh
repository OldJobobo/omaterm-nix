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

prompt_confirm() {
  local label="$1"
  local default="$2"
  local reply
  local suffix

  case "$default" in
    yes) suffix="Y/n" ;;
    no) suffix="y/N" ;;
    *)
      echo "Unknown prompt default: $default" >&2
      exit 1
      ;;
  esac

  printf "%s [%s] " "$label" "$suffix" > /dev/tty
  IFS= read -r reply < /dev/tty
  case "${reply,,}" in
    "")
      [ "$default" = "yes" ]
      ;;
    y|yes)
      return 0
      ;;
    n|no)
      return 1
      ;;
    *)
      echo "Please answer yes or no." >&2
      prompt_confirm "$label" "$default"
      ;;
  esac
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

detect_boot_mode() {
  if [ -d /sys/firmware/efi ]; then
    echo "uefi"
  else
    echo "bios"
  fi
}

detect_efi_mount_point() {
  if findmnt --mountpoint /boot/efi >/dev/null 2>&1; then
    echo "/boot/efi"
  elif findmnt --mountpoint /boot >/dev/null 2>&1; then
    echo "/boot"
  else
    echo "/boot"
  fi
}

root_parent_disk() {
  local source pkname

  source="$(findmnt -no SOURCE / 2>/dev/null || true)"
  if [ -z "$source" ]; then
    return 1
  fi

  pkname="$(lsblk -no PKNAME "$source" 2>/dev/null | head -n 1 || true)"
  if [ -z "$pkname" ]; then
    return 1
  fi

  echo "/dev/$pkname"
}

partition_table_type() {
  local disk="$1"

  lsblk -ndo PTTYPE "$disk" 2>/dev/null | head -n 1
}

has_bios_boot_partition() {
  local disk="$1"

  lsblk -nrpo PARTTYPE "$disk" 2>/dev/null \
    | grep -qi '^21686148-6449-6e6f-744e-656564454649$'
}

write_bootloader_module() {
  local mode="$1"
  local module_file="$2"
  local bootloader_tmp
  local efi_mount
  local grub_device
  local partition_table

  bootloader_tmp="$(mktemp)"
  tmpfiles+=("$bootloader_tmp")

  case "$mode" in
    uefi)
      efi_mount="$(detect_efi_mount_point)"
      cat > "$bootloader_tmp" <<EOF
{ lib, ... }:

{
  boot.loader.grub.enable = lib.mkForce false;
  boot.loader.systemd-boot.enable = lib.mkForce true;
  boot.loader.efi.canTouchEfiVariables = lib.mkForce true;
  boot.loader.efi.efiSysMountPoint = "$efi_mount";
}
EOF
      ;;
    bios)
      grub_device="${OMATERM_GRUB_DEVICE:-$(root_parent_disk || true)}"
      if [ -z "$grub_device" ]; then
        cat >&2 <<EOF
Could not detect the root disk for BIOS GRUB installation.
Set OMATERM_GRUB_DEVICE=/dev/disk/by-id/... and rerun the bootstrap.
EOF
        exit 1
      fi

      partition_table="$(partition_table_type "$grub_device")"
      if [ "$partition_table" = "gpt" ] && ! has_bios_boot_partition "$grub_device"; then
        cat >&2 <<EOF
Detected legacy BIOS boot on $grub_device, but no BIOS Boot Partition exists.
GRUB cannot be installed permanently to a GPT disk without that partition.

Create a 1 MiB BIOS Boot Partition on $grub_device, or reinstall/boot NixOS in
UEFI mode so Omaterm can use systemd-boot.
EOF
        exit 1
      fi

      cat > "$bootloader_tmp" <<EOF
{ lib, ... }:

{
  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.loader.grub.enable = lib.mkForce true;
  boot.loader.grub.device = lib.mkForce "$grub_device";
  boot.loader.grub.efiSupport = lib.mkForce false;
}
EOF
      ;;
    *)
      echo "Unknown boot mode: $mode" >&2
      exit 1
      ;;
  esac

  sudo install -m 0644 "$bootloader_tmp" "$module_file"
}

run_rebuild() {
  local flake_ref="/etc/nixos#$host"

  if sudo nixos-rebuild switch --flake "$flake_ref"; then
    return 0
  fi

  cat >&2 <<EOF

nixos-rebuild switch failed.

If the build succeeded but activation failed while installing the bootloader,
you can still activate Omaterm for the running system with nixos-rebuild test.
That does not update the bootloader or make this generation the boot default.
Fix the bootloader configuration before relying on a reboot.
EOF

  if confirm "Retry activation without updating the bootloader?"; then
    sudo nixos-rebuild test --flake "$flake_ref"
    cat <<EOF

Activated Omaterm for the running system only.
After fixing the bootloader, persist this generation with:

  sudo nixos-rebuild switch --flake $flake_ref
EOF
  else
    return 1
  fi
}

if [ -e /etc/nixos/flake.nix ] && [ "${OMATERM_OVERWRITE_NIXOS_FLAKE:-0}" != "1" ]; then
  echo "/etc/nixos/flake.nix already exists."
  echo "Set OMATERM_OVERWRITE_NIXOS_FLAKE=1 to replace it."
  exit 1
fi

if [ ! -e /etc/nixos/configuration.nix ]; then
  echo "/etc/nixos/configuration.nix does not exist."
  echo "Omaterm needs the existing NixOS config so bootloader and filesystem settings are preserved."
  exit 1
fi

flake_url="${OMATERM_FLAKE_URL:-github:OldJobobo/omaterm-nix/nixos}"
host="$(prompt "NixOS host name" "${HOSTNAME:-server}")"
user="$(prompt "Omaterm user" "omaterm")"
ssh_key="$(prompt_optional "SSH public key for $user (leave empty to skip)")"
system="$(system_arch)"
boot_mode="$(detect_boot_mode)"
bootloader_module="./omaterm-bootloader.nix"
bootloader_module_path="/etc/nixos/omaterm-bootloader.nix"
enable_tailscale="false"

if prompt_confirm "Enable Tailscale" "yes"; then
  enable_tailscale="true"
fi

validate_hostname "$host"
validate_username "$user"

authorized_keys="[]"
if [ -n "$ssh_key" ]; then
  authorized_keys="[ \"$ssh_key\" ]"
fi

tmpfile="$(mktemp)"
tmpfiles=("$tmpfile")
trap 'rm -f "${tmpfiles[@]}"' EXIT

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
        ./configuration.nix
        $bootloader_module
        omaterm.nixosModules.omaterm
        home-manager.nixosModules.home-manager
        ({ lib, ... }: {
          system.stateVersion = lib.mkDefault "25.05";
          networking.hostName = lib.mkForce "$host";
          nix.settings.experimental-features = [ "nix-command" "flakes" ];

          programs.omaterm = {
            enable = true;
            user = "$user";
            createUser = true;
            authorizedKeys = $authorized_keys;
            enableDocker = true;
            enableSSH = true;
            enableTailscale = $enable_tailscale;
            enableAI = true;
          };

          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users."$user" = {
            imports = [ omaterm.homeManagerModules.omaterm ];
            programs.omaterm = {
              enable = true;
              enableAI = true;
            };
            home.stateVersion = "25.05";
          };
        })
      ];
    };
  };
}
EOF

sudo install -d /etc/nixos
write_bootloader_module "$boot_mode" "$bootloader_module_path"
sudo install -m 0644 "$tmpfile" /etc/nixos/flake.nix

if [ "${OMATERM_OVERWRITE_NIXOS_FLAKE:-0}" = "1" ] && [ -e /etc/nixos/flake.lock ]; then
  sudo rm -f /etc/nixos/flake.lock
  echo "Removed /etc/nixos/flake.lock so inputs can be locked from the new flake."
fi

echo "Wrote /etc/nixos/flake.nix for host '$host' and user '$user'."
echo "Wrote $bootloader_module_path for detected $boot_mode boot."

if [ -z "$ssh_key" ]; then
  echo "No SSH key was configured. Add a key or password before relying on remote access."
fi

if confirm "Run nixos-rebuild now?"; then
  run_rebuild
else
  echo "Apply it later with: sudo nixos-rebuild switch --flake /etc/nixos#$host"
fi
