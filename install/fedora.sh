install_packages() {
  section "Updating system packages..."
  sudo dnf upgrade -y

  section "Installing Fedora packages..."
  sudo dnf install -y @development-tools \
    git openssh-server sudo less net-tools whois \
    zsh fzf zoxide tmux btop jq man-db \
    vim luarocks \
    clang llvm rust cargo libyaml \
    curl wget \
    tailscale \
    kitty-terminfo

  # Docker (not in Fedora repos, needs Docker's official repo)
  if ! command -v docker &>/dev/null; then
    section "Installing Docker..."
    sudo dnf config-manager addrepo --from-repofile=https://download.docker.com/linux/fedora/docker-ce.repo
    sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  fi

  # mise (not in Fedora repos)
  if ! command -v mise &>/dev/null; then
    section "Installing mise..."
    curl -fsSL https://mise.run | sh
    export PATH="$HOME/.local/bin:$PATH"
  fi
}

enable_services() {
  section "Enabling services..."

  sudo systemctl enable docker.service
  sudo systemctl start --no-block docker.service
  echo "✓ Docker"

  sudo systemctl enable --now sshd.service
  echo "✓ sshd"
}
