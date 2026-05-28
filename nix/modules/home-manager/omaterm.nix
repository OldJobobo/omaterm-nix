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
  lazyvimStarter = pkgs.callPackage ../../packages/lazyvim-starter.nix { };
  omadots = pkgs.callPackage ../../packages/omadots.nix { };

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

  aiPackageNames = [
    "opencode"
    "claude-code"
  ];

  availableAIPackages =
    builtins.map (name: builtins.getAttr name pkgs)
      (builtins.filter (name: builtins.hasAttr name pkgs) aiPackageNames);

  missingAIPackages = builtins.filter (name: !(builtins.hasAttr name pkgs)) aiPackageNames;
in
{
  options.programs.omaterm = {
    enable = lib.mkEnableOption "Omaterm user environment";

    shellIntegration = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to enable Omaterm shell aliases and shell integrations.";
    };

    tmuxAutoStart = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether interactive Zsh shells should attach to the main tmux session.";
    };

    lazyvimConfig = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to install Omaterm's Neovim configuration.";
    };

    lazyvimStarter = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to install the pinned LazyVim starter files.";
    };

    omadotsConfig = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to install pinned Omadots shell, tmux, git, mise, btop, and opencode config.";
    };

    starshipConfig = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to install Omaterm's Starship configuration.";
    };

    lazygitConfig = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to install Omaterm's Lazygit configuration.";
    };

    theme = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "tokyonight";
      description = "Optional Omaterm Neovim theme name written to ~/.config/omaterm/nvim.theme.";
    };

    enableAI = lib.mkEnableOption "AI CLI tools available in nixpkgs";

    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      example = lib.literalExpression "with pkgs; [ ripgrep fd ]";
      description = "Additional user packages to install with Omaterm.";
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      warnings =
        lib.optionals (cfg.enableAI && missingAIPackages != [ ])
          [
            "programs.omaterm.enableAI is true, but these AI tools are not available in this nixpkgs: ${
              lib.concatStringsSep ", " missingAIPackages
            }"
          ];

      home.packages =
        (with pkgs; [
          bat
          curl
          fd
          git
          gh
          wget
          zsh
          starship
          fzf
          eza
          zoxide
          tmux
          btop
          jq
          gum
          vim
          neovim
          ripgrep
          tree-sitter
          unzip
          lazygit
          lazydocker
          nodejs
          ruby
          omatermScripts
        ])
        ++ lib.optional (tldrPackage != null) tldrPackage
        ++ lib.optionals cfg.enableAI availableAIPackages
        ++ cfg.extraPackages;

      home.shellAliases = lib.mkIf cfg.shellIntegration {
        n = "nvim";
        t = "tmux new-session -A -s main";
        d = "docker";
        lzd = "lazydocker";
        lg = "lazygit";
      };

      programs.zsh.enable = lib.mkIf cfg.shellIntegration true;
      programs.starship.enable = lib.mkIf cfg.shellIntegration true;
      programs.zoxide.enable = lib.mkIf cfg.shellIntegration true;
      programs.fzf.enable = lib.mkIf cfg.shellIntegration true;
    }

    (lib.mkIf (cfg.shellIntegration && cfg.tmuxAutoStart) {
      programs.zsh.initContent = ''
        if [[ -o interactive && -z "$TMUX" && -z "''${OMATERM_NO_TMUX:-}" ]]; then
          tmux new-session -A -s main
        fi
      '';
    })

    (lib.mkIf cfg.lazyvimStarter {
      xdg.configFile."nvim/init.lua".source =
        "${lazyvimStarter}/share/lazyvim-starter/init.lua";
      xdg.configFile."nvim/lua/config/autocmds.lua".source =
        "${lazyvimStarter}/share/lazyvim-starter/lua/config/autocmds.lua";
      xdg.configFile."nvim/lua/config/keymaps.lua".source =
        "${lazyvimStarter}/share/lazyvim-starter/lua/config/keymaps.lua";
      xdg.configFile."nvim/lua/config/lazy.lua".source =
        "${lazyvimStarter}/share/lazyvim-starter/lua/config/lazy.lua";
      xdg.configFile."nvim/lua/plugins/example.lua".source =
        "${lazyvimStarter}/share/lazyvim-starter/lua/plugins/example.lua";
      xdg.configFile."nvim/.neoconf.json".source =
        "${lazyvimStarter}/share/lazyvim-starter/.neoconf.json";
      xdg.configFile."nvim/stylua.toml".source =
        "${lazyvimStarter}/share/lazyvim-starter/stylua.toml";
    })

    (lib.mkIf cfg.omadotsConfig {
      xdg.configFile."btop/btop.conf".source =
        "${omadots}/share/omadots/config/btop/btop.conf";
      xdg.configFile."git/config".source =
        "${omadots}/share/omadots/config/git/config";
      xdg.configFile."mise/config.toml".source =
        "${omadots}/share/omadots/config/mise/config.toml";
      xdg.configFile."nvim/lazyvim.json".source =
        "${omadots}/share/omadots/config/nvim/lazyvim.json";
      xdg.configFile."opencode/opencode.json".source =
        "${omadots}/share/omadots/config/opencode/opencode.json";
      xdg.configFile."shell/aliases".source =
        "${omadots}/share/omadots/config/shell/aliases";
      xdg.configFile."shell/all".source =
        "${omadots}/share/omadots/config/shell/all";
      xdg.configFile."shell/envs".source =
        "${omadots}/share/omadots/config/shell/envs";
      xdg.configFile."shell/functions".source =
        "${omadots}/share/omadots/config/shell/functions";
      xdg.configFile."shell/inits".source =
        "${omadots}/share/omadots/config/shell/inits";
      xdg.configFile."shell/inputrc".source =
        "${omadots}/share/omadots/config/shell/inputrc";
      xdg.configFile."shell/zoptions".source =
        "${omadots}/share/omadots/config/shell/zoptions";
      xdg.configFile."tmux/tmux.conf".source =
        "${omadots}/share/omadots/config/tmux/tmux.conf";
    })

    (lib.mkIf (cfg.shellIntegration && cfg.omadotsConfig) {
      programs.zsh.initContent = ''
        if [[ -r "$HOME/.config/shell/all" ]]; then
          source "$HOME/.config/shell/all"
        fi
      '';
    })

    (lib.mkIf cfg.lazyvimConfig {
      xdg.configFile."nvim/lua/config/options.lua".source =
        ../../../config/nvim/lua/config/options.lua;
      xdg.configFile."nvim/lua/plugins/colorscheme.lua".source =
        ../../../config/nvim/lua/plugins/colorscheme.lua;
      xdg.configFile."nvim/lua/plugins/disable-news-alert.lua".source =
        ../../../config/nvim/lua/plugins/disable-news-alert.lua;
      xdg.configFile."nvim/lua/plugins/nixos-tools.lua".text = ''
        return {
          {
            "mason-org/mason.nvim",
            opts = {
              PATH = "append",
            },
          },
        }
      '';
      xdg.configFile."nvim/lua/plugins/snacks-animated-scrolling.lua".source =
        ../../../config/nvim/lua/plugins/snacks-animated-scrolling.lua;
      xdg.configFile."nvim/plugin/after/transparency.lua".source =
        ../../../config/nvim/plugin/after/transparency.lua;
    })

    (lib.mkIf cfg.starshipConfig {
      xdg.configFile."starship.toml".source = ../../../config/starship.toml;
    })

    (lib.mkIf cfg.lazygitConfig {
      xdg.configFile."lazygit/config.yml".source = ../../../config/lazygit/config.yml;
    })

    (lib.mkIf (cfg.theme != null) {
      xdg.configFile."omaterm/nvim.theme".text = cfg.theme + "\n";
    })
  ]);
}
