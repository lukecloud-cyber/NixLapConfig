# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running 'nixos-help').

{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      # Home Manager as a NixOS module — manages user environment declaratively
    ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Use latest kernel.
  boot.kernelPackages = pkgs.linuxPackages_latest;

  boot.initrd.luks.devices."luks-1db9a3db-9ae4-4d81-b981-4617b2e23cda".device = "/dev/disk/by-uuid/1db9a3db-9ae4-4d81-b981-4617b2e23cda";
  networking.hostName = "nixos"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "America/Chicago";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  # Enable the X11 windowing system.
  # You can disable this if you're only using the Wayland session.
  services.xserver.enable = true;

  # Enable the KDE Plasma Desktop Environment.
  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;

  # Make Qt apps use Kvantum theme engine
  environment.sessionVariables = {
    QT_STYLE_OVERRIDE = "kvantum";
  };

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Define a user account. Don't forget to set a password with 'passwd'.
  users.users.luke = {
    isNormalUser = true;
    shell = pkgs.fish;
    description = "luke";
    extraGroups = [ "networkmanager" "wheel" ];
  };

  # Home Manager settings
  home-manager.useGlobalPkgs = true;   # use the system nixpkgs (avoids a second nixpkgs instance)
  home-manager.useUserPackages = true; # install user packages into /etc/profiles instead of ~/.nix-profile
  home-manager.users.luke = import ./home.nix;

  # Passwordless sudo for wheel group members
  security.sudo.wheelNeedsPassword = false;

  # Install firefox.
  programs.firefox.enable = true;

  # Fish shell — fast, friendly, interactive shell with autosuggestions and syntax highlighting
  programs.fish.enable = true;

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Enable modern Nix CLI features.
  # - nix-command: unlocks `nix search`, `nix run`, `nix develop`, etc.
  # - flakes: enables reproducible, self-contained Nix projects with flake.nix
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    vim                              # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    claude-code                      # Anthropic's AI coding assistant CLI
    kdePackages.qtstyleplugin-kvantum # Kvantum theme engine for Qt/KDE apps
    bat                              # Syntax-highlighted cat replacement with git integration
    eza                              # Modern ls replacement with color, icons, and git awareness
    brave                            # Privacy-focused web browser based on Chromium
    micro                            # Nano-like terminal text editor with syntax highlighting
    bitwarden-desktop                # Official Bitwarden password manager desktop app
    gh                               # GitHub CLI — manage PRs, issues, and repos; run `gh auth login` to authenticate
    vesktop                          # Discord Desktop replacmenet app
    duf                              # Colorful and robust df replacement
    fastfetch                        # its fastfetch
    age                              # Encryption tool used by sops-nix to encrypt/decrypt secrets
    sops                             # Secrets editor — run `sops secrets/secrets.yaml` to add or edit secrets
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  # Secrets management via sops-nix
  # secrets.yaml is committed (encrypted); age-key.txt is gitignored and must be restored manually on recovery
  sops.defaultSopsFile = ./secrets/secrets.yaml;
  sops.age.keyFile = "/etc/nixos/secrets/age-key.txt";
  sops.secrets.github_pat = { owner = "luke"; }; # decrypts to /run/secrets/github_pat at boot

  system.stateVersion = "25.11"; # Did you read the comment?

}
