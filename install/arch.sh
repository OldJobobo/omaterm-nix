install_packages() {
  local official_pkgs=(
    base-devel git openssh sudo less inetutils whois
    fzf zoxide tmux btop jq man-db
    vim luarocks
    clang llvm rust mise libyaml
    docker docker-buildx docker-compose
    tailscale
    kitty-terminfo
  )

  section "Installing Arch packages..."
  sudo pacman -Syu --needed --noconfirm "${official_pkgs[@]}"
}

enable_services() {
  section "Enabling services..."

  sudo systemctl enable docker.service
  sudo systemctl start --no-block docker.service
  echo "✓ Docker"

  sudo systemctl enable --now sshd.service
  echo "✓ sshd"
}
