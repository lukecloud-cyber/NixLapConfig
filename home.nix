{ config, pkgs, ... }:

{
  home.stateVersion = "25.11";

  # User-level packages — things only luke needs, not the whole system
  home.packages = with pkgs; [
    kdePackages.kate  # KDE advanced text editor
    glow              # CLI MD terminal renderer
    nodejs_22         # Required for npx-based MCP servers (e.g. context7)
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
    shellAliases = {
      cat  = "bat";
      ls   = "eza";
      ll   = "eza -l";
      la   = "eza -la";
      tree = "eza --tree";
    };
    # Read secrets from sops-managed files at /run/secrets/ (decrypted at boot by sops-nix)
    # Using shellInit instead of sessionVariables so the value is read at login time, not baked in at build time
    shellInit = ''
      if test -r /run/secrets/github_pat
        set -gx GITHUB_PERSONAL_ACCESS_TOKEN (string trim (cat /run/secrets/github_pat))
      end
    '';
  };

  # Starship prompt — personal preference, belongs with the user
  programs.starship = {
    enable = true;
    settings = builtins.fromTOML (builtins.readFile ./starship.toml); # relative path required — flakes forbid absolute paths like /etc/nixos/starship.toml in pure eval mode
  };
}
