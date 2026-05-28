install_packages() {
  section "Updating system packages..."
  sudo apt-get update
  sudo apt-get upgrade -y

  section "Installing Debian packages..."
  sudo apt-get remove -y containerd.io 2>/dev/null || true
  sudo apt-get install -y \
    build-essential git openssh-server libssl-dev sudo less net-tools whois \
    fzf zoxide tmux btop jq man-db \
    vim luarocks \
    clang llvm rustc libyaml-0-2 \
    curl wget gpg \
    docker.io docker-compose-v2 \
    kitty-terminfo

  # docker-buildx (skip if docker-buildx-plugin from Docker's repo is already installed)
  if ! dpkg -l docker-buildx-plugin &>/dev/null; then
    sudo apt-get install -y docker-buildx 2>/dev/null || true
  fi

  # tailscale (not in Debian/Ubuntu repos)
  if ! command -v tailscale &>/dev/null; then
    section "Installing Tailscale..."
    curl -fsSL https://tailscale.com/install.sh | sh
  fi

  # mise (not in Ubuntu repos)
  if ! command -v mise &>/dev/null; then
    section "Installing mise..."
    curl -fsSL https://mise.run | sh 2>/dev/null
    export PATH="$HOME/.local/bin:$PATH"
  fi
}

enable_docker() {
  sudo systemctl enable docker.service
  sudo systemctl start --no-block docker.service
  echo "✓ Docker"
}
