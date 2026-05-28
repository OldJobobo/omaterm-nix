# Omaterm

An Omakase Terminal Setup For Arch/Debian/Ubuntu/Fedora/Docker by DHH

## Requirements

- Base Arch/Debian/Ubuntu/Fedora Linux installation or ability to start Docker
- Internet connection
- `sudo` privileges

## Install

```bash
curl -fsSL https://omaterm.org/install | bash
```


## Docker

```bash
docker run -it -v omaterm-home:/home/omaterm ghcr.io/omacom-io/omaterm
```

The named volume persists your home directory across container restarts, including git config, gh auth, shell history, and projects.

You can also add an alias to your .bashrc/.zshrc to make this convenient:

```
alias omaterm='docker run -it -v home:/home/omaterm omacom/omaterm'
```

## What it sets up

- **Shell**: Bash with starship prompt, fzf, eza, zoxide
- **Editors**: Neovim (LazyVim), opencode, claude-code
- **Dev tools**: mise, docker, GitHub CLI (`gh`), lazygit, lazydocker
- **Networking**: SSH, tailscale
- **Git**: Interactive config for user name/email, helpful aliases

## Interactive prompts

During installation you'll be asked for:

- Git user name
- Git email address

And you'll be offered to setup:

- Tailscale
- GitHub
