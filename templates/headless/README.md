# Omaterm Headless NixOS Template

Edit `flake.nix` before rebuilding:

- Set `nixosConfigurations.server` and `networking.hostName`.
- Set `system` to `x86_64-linux` or `aarch64-linux`.
- Replace the `authorizedKeys` placeholder with your SSH public key.
- Change the Omaterm user if you do not want `omaterm`.

Apply with:

```bash
sudo nixos-rebuild switch --flake .#server
```
