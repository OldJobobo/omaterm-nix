{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.omaterm;

  omatermScripts = pkgs.callPackage ../../packages/omaterm-scripts.nix {
    src = ../../..;
  };

  firstAvailable =
    names:
    let
      found = builtins.filter (name: builtins.hasAttr name pkgs) names;
    in
    if found == [ ] then null else builtins.getAttr (builtins.head found) pkgs;

  tldrPackage = firstAvailable [
    "tldr"
    "tealdeer"
  ];

  dockerComposePackage = firstAvailable [
    "docker-compose"
    "docker-compose_2"
  ];

  dockerBuildxPackage = firstAvailable [
    "docker-buildx"
  ];

  aiPackageNames = [
    "opencode"
    "claude-code"
  ];

  availableAIPackages =
    builtins.map (name: builtins.getAttr name pkgs)
      (builtins.filter (name: builtins.hasAttr name pkgs) aiPackageNames);

  missingAIPackages = builtins.filter (name: !(builtins.hasAttr name pkgs)) aiPackageNames;

  userGroups = [ "wheel" ] ++ lib.optional cfg.enableDocker "docker";
  userExists = cfg.user != null && builtins.hasAttr cfg.user config.users.users;
  userIsNormal = userExists && (config.users.users.${cfg.user}.isNormalUser or false);
in
{
  options.programs.omaterm = {
    enable = lib.mkEnableOption "Omaterm headless terminal environment";

    user = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "john";
      description = "User account to configure for Omaterm shell access.";
    };

    createUser = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to create the configured Omaterm user as a normal user.";
    };

    enableUserConfig = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to configure the Omaterm user's shell and groups.";
    };

    enableDocker = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to enable Docker and add the Omaterm user to the docker group.";
    };

    enableSSH = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to enable OpenSSH.";
    };

    enableTailscale = lib.mkEnableOption "Tailscale";

    enableAI = lib.mkEnableOption "AI CLI tools available in nixpkgs";

    authorizedKeys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI..."
      ];
      description = "SSH public keys to install for the configured Omaterm user.";
    };

    hashedPassword = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "$y$j9T$...";
      description = "Hashed password for the configured Omaterm user.";
    };

    enablePasswordlessSudo = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to allow the configured Omaterm user to run sudo without a password.";
    };

    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      example = lib.literalExpression "with pkgs; [ ripgrep fd ]";
      description = "Additional packages to install with the Omaterm system environment.";
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      assertions = [
        {
          assertion = !cfg.enableUserConfig || cfg.user != null;
          message = "programs.omaterm.user must be set when enableUserConfig is true.";
        }
        {
          assertion =
            !cfg.enableUserConfig
            || cfg.createUser
            || userIsNormal;
          message = "programs.omaterm.user must name an existing normal user, or createUser must be true.";
        }
      ];

      warnings =
        lib.optionals (cfg.enableAI && missingAIPackages != [ ])
          [
            "programs.omaterm.enableAI is true, but these AI tools are not available in this nixpkgs: ${
              lib.concatStringsSep ", " missingAIPackages
            }"
          ];

      environment.systemPackages =
        (with pkgs; [
          git
          openssh
          sudo
          less
          curl
          wget
          bat
          fd
          inetutils
          nettools
          whois
          zsh
          starship
          fzf
          eza
          zoxide
          tmux
          btop
          jq
          gum
          man-db
          vim
          neovim
          ripgrep
          unzip
          luarocks
          gcc
          gnumake
          pkg-config
          openssl
          clang
          llvm
          rustc
          cargo
          nodejs
          ruby
          mise
          libyaml
          gh
          lazygit
          lazydocker
          kitty.terminfo
          omatermScripts
        ])
        ++ lib.optional (tldrPackage != null) tldrPackage
        ++ lib.optional (dockerComposePackage != null) dockerComposePackage
        ++ lib.optional (dockerBuildxPackage != null) dockerBuildxPackage
        ++ lib.optionals cfg.enableAI availableAIPackages
        ++ cfg.extraPackages;

      programs.zsh.enable = true;
    }

    (lib.mkIf cfg.enableSSH {
      services.openssh.enable = true;
    })

    (lib.mkIf cfg.enableTailscale {
      services.tailscale.enable = true;
    })

    (lib.mkIf cfg.enableDocker {
      virtualisation.docker.enable = true;
    })

    (lib.mkIf (cfg.enableUserConfig && cfg.user != null) {
      users.users.${cfg.user} = {
        shell = pkgs.zsh;
        extraGroups = userGroups;
        openssh.authorizedKeys.keys = cfg.authorizedKeys;
      };
    })

    (lib.mkIf (cfg.enableUserConfig && cfg.createUser && cfg.user != null) {
      users.users.${cfg.user}.isNormalUser = true;
    })

    (lib.mkIf (cfg.enableUserConfig && cfg.hashedPassword != null && cfg.user != null) {
      users.users.${cfg.user}.hashedPassword = cfg.hashedPassword;
    })

    (lib.mkIf (cfg.enableUserConfig && cfg.enablePasswordlessSudo && cfg.user != null) {
      security.sudo.extraRules = [
        {
          users = [ cfg.user ];
          commands = [
            {
              command = "ALL";
              options = [ "NOPASSWD" ];
            }
          ];
        }
      ];
    })
  ]);
}
