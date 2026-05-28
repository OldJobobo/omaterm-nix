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

  if ! command -v yay &>/dev/null; then
    section "Installing yay..."
    local tmpdir
    tmpdir="$(mktemp -d)"
    git clone https://aur.archlinux.org/yay-bin.git "$tmpdir/yay"
    (cd "$tmpdir/yay" && makepkg -si --noconfirm)
    rm -rf "$tmpdir"
  fi
}

enable_docker() {
  sudo systemctl enable docker.service
  sudo systemctl start --no-block docker.service
  echo "✓ Docker"
}
