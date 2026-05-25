# Repository Guidelines

## Project Structure & Module Organization

Omaterm is a shell-based terminal bootstrapper. The main installer is
`install.sh`, which detects the OS, clones the selected `OMATERM_REF`, and
dispatches into distro-specific installers under `install/`.

- `install/arch.sh`, `install/debian.sh`, `install/fedora.sh`: package lists,
  service setup, and distro-specific installation hooks.
- `bin/`: user-facing helper commands copied into `~/.local/bin`, such as
  `omaterm-setup`, `omaterm-ssh`, `omaterm-theme`, and `omaterm-refresh`.
- `config/`: configuration assets copied into `~/.config`, including Neovim,
  Starship, and Lazygit settings.
- `Dockerfile`: Arch-based container image for local smoke testing and published
  runtime usage.

## Build, Test, and Development Commands

- `bash -n install.sh install/*.sh bin/*`: syntax-check shell entry points.
- `docker build -t omaterm .`: build the container image and verify package
  installation, config copy, and executable permissions.
- `docker run -it -v omaterm-home:/home/omaterm omaterm`: run the local image
  with a persistent home volume for manual setup testing.
- `OMATERM_REF=<branch-or-tag> bash install.sh`: test installation from a
  specific ref when validating installer changes.

## Coding Style & Naming Conventions

Write shell scripts in Bash with `#!/usr/bin/env bash` and `set -euo pipefail`
for executable entry points. Use two-space indentation inside functions and
case blocks. Prefer small functions with action-oriented names, such as
`install_packages`, `enable_services`, or `configure_shell`. Keep helper command
names under `bin/` prefixed with `omaterm-`.

Use arrays for package lists, quote variable expansions, and route privileged
operations through existing helpers such as `as_root` where applicable.

## Testing Guidelines

There is no formal test suite yet. Before opening a PR, run the shell syntax
check and at least one Docker build. For installer behavior changes, manually
exercise the affected distro path in a container or VM when possible. Name any
future tests after the behavior they cover, for example
`install_detects_debian` or `setup_skips_existing_marker`.

## Commit & Pull Request Guidelines

Recent commits use short, imperative summaries, for example `Switch to zsh` and
`Add OMATERM_REF support`. Follow that style: keep the subject concise and state
the user-visible change.

Pull requests should include a brief description, the distro or container used
for verification, commands run, and any interactive prompts or privileged system
changes affected. Include screenshots only when changing visible terminal output
or generated configuration presentation.

## Security & Configuration Tips

Treat installer changes as privileged system changes. Review commands that touch
users, groups, sudoers, services, shell startup files, or remote `curl | bash`
flows carefully. Do not commit secrets, local GitHub credentials, SSH keys, or
machine-specific generated config.
