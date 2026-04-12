{ config, pkgs, lib, ... }:

{
  home.stateVersion = "25.11";

  # KWin focus policy — windows gain focus on hover without clicking
  home.activation.kwinFocusFollowsMouse = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 --file kwinrc --group Windows --key FocusPolicy FocusFollowsMouse
    $DRY_RUN_CMD ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 --file kwinrc --group Windows --key NextFocusPrefersMouse true
  '';

  # Autostart Vesktop on login
  xdg.configFile."autostart/vesktop.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Vesktop
    Exec=vesktop
    X-GNOME-Autostart-enabled=true
  '';

  # User-level packages — things only luke needs, not the whole system
  home.packages = with pkgs; [
    kdePackages.kate  # KDE advanced text editor
    glow              # CLI MD terminal renderer
    nodejs_22         # Required for npx-based MCP servers (e.g. context7)
    rclone            # CLI tool to sync files to/from cloud storage (S3, Google Drive, etc.)
  ];

  # Git config — user identity belongs here, not in system config
  programs.git = {
    enable = true;
    userName = "luke";
    userEmail = "luke.cloud@gmail.com";
    extraConfig = {
      init.defaultBranch = "main";
      pull.rebase = false;
      core.autocrlf = "input";
    };
  };

  # Fish shell — user-level config (configuration.nix still enables fish as a login shell)
  programs.fish = {
    enable = true;
    shellAbbrs = {
      ff = "clear && fastfetch";
    };
    shellAliases = {
      cat  = "bat";
      ls   = "eza";
      ll   = "eza -l";
      la   = "eza -la";
      tree      = "eza --tree";
      nixswitch = "~/nixswitch";
    };
    # Read secrets from sops-managed files at /run/secrets/ (decrypted at boot by sops-nix)
    # Using shellInit instead of sessionVariables so the value is read at login time, not baked in at build time
    shellInit = ''
      if test -r /run/secrets/github_pat
        set -gx GITHUB_PERSONAL_ACCESS_TOKEN (string trim (cat /run/secrets/github_pat))
      end
    '';
  };

  # Yazi — TUI file manager with directory tree and file preview
  programs.yazi = {
    enable = true;
    enableFishIntegration = true;  # provides `y` shell wrapper that cd's on exit

    extraPackages = with pkgs; [
      ueberzugpp  # image previews in terminals that don't support kitty/sixel natively
    ];

    settings = {
      manager = {
        show_hidden = false;
        sort_by = "natural";
        sort_dir_first = true;
        show_symlink = true;
      };
      preview = {
        tab_size = 2;
        max_width = 600;
        max_height = 900;
        image_quality = 75;
        image_filter = "lanczos3";
      };
    };

    plugins = {
      glow = pkgs.yaziPlugins.glow;
      vcs-files = pkgs.yaziPlugins.vcs-files;
    };

    initLua = ''
      require("vcs-files"):setup()
    '';
  };

  # Starship prompt — personal preference, belongs with the user
  programs.starship = {
    enable = true;
    settings = builtins.fromTOML (builtins.readFile ./starship.toml); # relative path required — flakes forbid absolute paths like /etc/nixos/starship.toml in pure eval mode
  };
}
