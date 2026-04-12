# NixOS Configuration Overview

## System Information

| Property | Value |
|----------|-------|
| NixOS Version | 25.11 (Xantusia) |
| Hostname | nixos |
| Architecture | x86_64-linux (Intel) |
| Configuration Type | Flake-based (flake.nix + configuration.nix + home.nix) |
| Home Manager | Managed as flake input (pinned via flake.lock) |
| Flakes | Enabled and in use — system config managed via `flake.nix` |

---

## Configuration File Structure

```
/etc/nixos/
├── flake.nix                # Flake entrypoint — declares inputs (nixpkgs, home-manager) and outputs
├── flake.lock               # Pinned input commits — do not edit by hand, updated via `nix flake update`
├── configuration.nix        # System-level config (hardware, services, system packages)
├── hardware-configuration.nix  # Auto-generated hardware config (do not edit)
├── home.nix                 # User environment (luke's packages, dotfiles, shell, git)
└── starship.toml            # Starship prompt config (read by home.nix at build time)
```

### What goes where

| Concern | File |
|---------|------|
| Boot, kernel, hardware | `configuration.nix` |
| System services (pipewire, sddm, printing) | `configuration.nix` |
| System-wide packages (`environment.systemPackages`) | `configuration.nix` |
| Enabling shells system-wide (`programs.fish.enable`) | `configuration.nix` |
| User packages (`home.packages`) | `home.nix` |
| Shell aliases and user shell config | `home.nix` |
| Git identity and config | `home.nix` |
| Starship prompt settings | `home.nix` (reads `starship.toml`) |

---

## Installed Packages

### System Packages (`configuration.nix` → `environment.systemPackages`)

| Package | Description |
|---------|-------------|
| `vim` | Terminal text editor (always available for emergency edits) |
| `claude-code` | Anthropic's AI coding assistant CLI |
| `kdePackages.qtstyleplugin-kvantum` | Kvantum theme engine for Qt/KDE apps |
| `bat` | Syntax-highlighted cat replacement |
| `eza` | Modern ls replacement with color and git awareness |
| `brave` | Privacy-focused Chromium-based browser |
| `micro` | Nano-like terminal text editor |
| `bitwarden-desktop` | Bitwarden password manager |
| `gh` | GitHub CLI |
| `vesktop` | Discord desktop replacement |
| `duf` | Colorful df replacement |
| `fastfetch` | Fast system info / neofetch alternative |
| `age` | Encryption tool used by sops-nix to encrypt/decrypt secrets |
| `sops` | Secrets editor — run `sops secrets/secrets.yaml` to add or edit secrets |

### User Packages (`home.nix` → `home.packages`)

| Package | Description |
|---------|-------------|
| `kdePackages.kate` | KDE advanced text editor |
| `glow` | CLI Markdown terminal renderer |
| `nodejs_22` | Node.js 22 runtime — required for npx-based MCP servers (e.g. context7) |

### Programs enabled via `programs.*`

| Program | Location | Notes |
|---------|----------|-------|
| `firefox` | `configuration.nix` | System-level browser install |
| `fish` | `configuration.nix` | Registers fish as a valid login shell |
| `git` | `home.nix` | User identity + config |
| `fish` (aliases/config) | `home.nix` | User-level shell config |
| `starship` | `home.nix` | User prompt, reads `starship.toml` |

### Implicitly installed (via services/desktop)

| Component | Source |
|-----------|--------|
| KDE Plasma 6 | `services.desktopManager.plasma6.enable` |
| SDDM | `services.displayManager.sddm.enable` |
| X11 | `services.xserver.enable` |
| PipeWire | `services.pipewire.enable` |
| CUPS | `services.printing.enable` |
| NetworkManager | `networking.networkmanager.enable` |

---

## Configuration Breakdown

### Boot & Kernel
```nix
boot.loader.systemd-boot.enable = true;
boot.loader.efi.canTouchEfiVariables = true;
boot.kernelPackages = pkgs.linuxPackages_latest;
```

- **`systemd-boot`** — A minimal EFI bootloader that lives in your EFI System Partition (ESP). It's simpler and more modern than GRUB. When you power on, your firmware hands control directly to systemd-boot, which presents a menu of NixOS generations so you can boot or roll back.
- **`canTouchEfiVariables`** — Allows NixOS to write boot entries directly into your motherboard's UEFI NVRAM. This is what makes your system appear in your BIOS boot list. Required for systemd-boot to register itself properly on first install.
- **`linuxPackages_latest`** — Tracks the newest stable kernel release rather than the kernel pinned to your NixOS channel (which prioritizes stability over recency). You get newer driver support and hardware compatibility, with slightly more exposure to kernel regressions. Worth it on modern hardware.
- **LUKS encryption** — Your disk is encrypted at the block device level via LUKS (Linux Unified Key Setup). The `boot.initrd.luks.devices` entry tells the kernel to unlock the encrypted partition during early boot (initrd stage), before the root filesystem is even mounted. You enter your passphrase at the console before anything else loads.

### Desktop Environment
```nix
services.xserver.enable = true;
services.displayManager.sddm.enable = true;
services.desktopManager.plasma6.enable = true;
```

- **`services.xserver.enable`** — Despite the name, this doesn't just enable X11 — it's the NixOS option that bootstraps the entire graphical display stack. Even if you're running a Wayland session, this option is still required because it initializes display-related infrastructure (input handling, GPU setup, session management) that Wayland compositors on NixOS depend on.
- **`sddm`** — Simple Desktop Display Manager. This is the login screen you see after boot. It handles user authentication and launches your desktop session. SDDM is the official display manager for KDE and supports both X11 and Wayland sessions.
- **`plasma6`** — Enables KDE Plasma 6, the full desktop environment. This installs Plasma Shell, KWin (the window manager/compositor), Dolphin, and the rest of the KDE application suite. Plasma 6 runs on Wayland by default, with X11 available as a fallback.

### Audio
```nix
services.pipewire = {
  enable = true;
  alsa.enable = true;
  alsa.support32Bit = true;
  pulse.enable = true;
};
```

- **`pipewire`** — PipeWire is the modern Linux audio and video routing daemon. It replaced PulseAudio and JACK as the unified solution for handling all audio on the desktop. It manages streams between applications and your hardware with low latency and fine-grained routing control.
- **`alsa.enable`** — ALSA (Advanced Linux Sound Architecture) is the kernel's native audio layer. Enabling it here makes PipeWire expose an ALSA interface, so applications that talk directly to ALSA (rather than PulseAudio) still work correctly.
- **`alsa.support32Bit`** — Installs 32-bit ALSA libraries alongside the 64-bit ones. Required for 32-bit applications (like some older games or Wine) to produce audio. Without this, 32-bit programs either crash or produce no sound.
- **`pulse.enable`** — Runs PipeWire's PulseAudio compatibility server. This makes PipeWire impersonate PulseAudio at the socket level, so any application that expects PulseAudio (the vast majority of Linux software) works without modification. `pavucontrol`, Discord, browsers — they all talk to PipeWire thinking it's PulseAudio.
- **`pulseaudio.enable = false`** (set elsewhere) — Explicitly disables the real PulseAudio daemon so it doesn't conflict with PipeWire's impersonation layer.

### Qt/KDE Theming
```nix
environment.sessionVariables = {
  QT_STYLE_OVERRIDE = "kvantum";
};
```

- **`QT_STYLE_OVERRIDE`** — An environment variable that forces all Qt applications to use a specific style engine, regardless of what's set in system preferences. Setting it to `"kvantum"` tells Qt apps to load the Kvantum theme engine instead of the default Breeze style.
- **Kvantum** is an SVG-based theme engine for Qt that allows highly customized visual styles. Themes are installed to `~/.config/Kvantum/` and selected via the Kvantum Manager GUI app. Without this override, Qt apps would fall back to Breeze even if Kvantum themes are installed.
- **`kdePackages.qtstyleplugin-kvantum`** (in system packages) — The actual Qt style plugin that implements the Kvantum engine. The env var above is useless without this package being present.

### Home Manager
```nix
home-manager.useGlobalPkgs = true;
home-manager.useUserPackages = true;
home-manager.users.luke = import ./home.nix;
```

- **`useGlobalPkgs`** — Tells Home Manager to use the same `nixpkgs` instance as the system, rather than evaluating its own separate copy. Without this, Home Manager would fetch and evaluate nixpkgs independently, doubling build times and potentially pulling in a different package set. Always set this to `true` when using Home Manager as a NixOS module.
- **`useUserPackages`** — Installs user packages (from `home.packages`) into `/etc/profiles/per-user/luke/` instead of `~/.nix-profile`. This makes them available earlier in the boot process and avoids profile-linking quirks. Required for packages to appear correctly in PATH when using `useGlobalPkgs`.
- **`import ./home.nix`** — Loads your `home.nix` file and wires it to the `luke` user. This is the bridge between the system config and your personal environment config.

### Fish Shell Config (home.nix)
```nix
programs.fish = {
  shellAbbrs = {
    ff = "clear && fastfetch";
  };
  shellAliases = {
    cat = "bat";   ls = "eza";   ll = "eza -l";
    la = "eza -la";  tree = "eza --tree";
    nixswitch = "~/nixswitch";
  };
  shellInit = ''
    if test -r /run/secrets/github_pat
      set -gx GITHUB_PERSONAL_ACCESS_TOKEN (string trim (cat /run/secrets/github_pat))
    end
  '';
};
```

- **`shellAbbrs`** — Fish abbreviations expand inline as you type (like live snippets). `ff` expands to `clear && fastfetch` when you press space or enter. Unlike aliases, abbreviations show the expanded command in your history, which makes logs and replays readable.
- **`shellAliases`** — Standard command substitutions. `cat`→`bat` (syntax highlighting), `ls`/`ll`/`la`/`tree`→`eza` variants (modern ls with color/git info), and `nixswitch`→`~/nixswitch` (shortcut to the rebuild script).
- **`shellInit`** — Runs at every Fish login session. Reads the sops-decrypted secret from `/run/secrets/github_pat` and exports it as `GITHUB_PERSONAL_ACCESS_TOKEN`. Using `shellInit` (not `sessionVariables`) is intentional: `sessionVariables` bakes the value into the built config at rebuild time, whereas `shellInit` reads the file at login — essential for secrets that change without a rebuild.

### KWin Focus Policy (home.nix)
```nix
home.activation.kwinFocusFollowsMouse = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
  kwriteconfig6 --file kwinrc --group Windows --key FocusPolicy FocusFollowsMouse
  kwriteconfig6 --file kwinrc --group Windows --key NextFocusPrefersMouse true
'';
```

- **`home.activation`** — Home Manager activation scripts run imperatively after the declarative config is applied. They're for settings that can't be expressed as Nix options — here, writing directly into KDE's config files.
- **`FocusPolicy FocusFollowsMouse`** — Configures KWin so windows gain focus when the mouse hovers over them, without requiring a click. The alternative (`ClickToFocus`) is KDE's default and requires a click to raise/focus a window.
- **`NextFocusPrefersMouse`** — When focus moves (e.g., a window closes), KWin gives focus to whatever window is under the cursor rather than the previously focused window. Without this, focus-follows-mouse can feel inconsistent after window closures.
- **`lib.hm.dag.entryAfter [ "writeBoundary" ]`** — The DAG (directed acyclic graph) ordering ensures this script runs after Home Manager has finished writing all config files. Running it earlier could have its changes overwritten by Home Manager.

### User Account
```nix
users.users.luke = {
  isNormalUser = true;
  shell = pkgs.fish;
  extraGroups = [ "networkmanager" "wheel" ];
};
```

- **`isNormalUser`** — Creates a standard unprivileged user account with a home directory at `/home/luke`, a UID in the normal range (1000+), and sensible defaults. The alternative is `isSystemUser`, used for service accounts with no login shell.
- **`shell = pkgs.fish`** — Sets Fish as the default login shell for this user. Note that `programs.fish.enable = true` in `configuration.nix` is also required — that registers Fish in `/etc/shells`, which is the system-level whitelist of valid login shells. Both settings are necessary.
- **`networkmanager`** group — Allows the user to manage network connections (WiFi, VPN, etc.) without sudo. Without this, NetworkManager would reject connection changes from the desktop.
- **`wheel`** group — The Unix convention for "this user can use sudo." NixOS uses this group to gate administrative access. Combined with `wheelNeedsPassword = false`, it grants full root access without a password prompt.

### Sudo
```nix
security.sudo.wheelNeedsPassword = false;
```

- By default, `wheel` group members must enter their password to run `sudo`. This setting removes that requirement, so `sudo <command>` runs immediately without prompting. Convenient on a single-user personal machine. On a shared or production system, you'd leave this at the default (`true`) to prevent privilege escalation from an unattended session.

### SOPS Secrets Management
```nix
sops.defaultSopsFile = ./secrets/secrets.yaml;
sops.age.keyFile = "/etc/nixos/secrets/age-key.txt";
sops.secrets.github_pat = { owner = "luke"; };
```

- **`sops.defaultSopsFile`** — Points to the encrypted secrets file committed to the repo. SOPS (Secrets OPerationS) encrypts this YAML file with age so it's safe to version-control. At boot, sops-nix decrypts it and materializes each secret as a file under `/run/secrets/`.
- **`sops.age.keyFile`** — The age private key used to decrypt secrets. This file lives at `/etc/nixos/secrets/age-key.txt` and is **not** committed to git (gitignored). It must be manually restored on a fresh install or recovery — without it, the system boots but secrets are unavailable.
- **`sops.secrets.github_pat`** — Declares a single secret named `github_pat`. The `owner = "luke"` ensures the decrypted file at `/run/secrets/github_pat` is readable by the `luke` user (not just root). Fish's `shellInit` reads this file at login to set `GITHUB_PERSONAL_ACCESS_TOKEN`.

### Nixpkgs Settings
```nix
nixpkgs.config.allowUnfree = true;
```

- Nix packages are categorized by license. "Unfree" means the package has a license that restricts redistribution, commercial use, or source access — examples include `brave`, `bitwarden-desktop`, `vesktop`, and `claude-code`. By default, Nix refuses to build or install these. Setting `allowUnfree = true` opts in to building them. Without this, any unfree package in `environment.systemPackages` or `home.packages` would cause the build to fail with a license error.

### Flakes
```nix
# /etc/nixos/flake.nix
inputs = {
  nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  home-manager = {
    url = "github:nix-community/home-manager";
    inputs.nixpkgs.follows = "nixpkgs";
  };
};
```

- **`flake.nix`** — The entrypoint for the entire system config. It declares external dependencies ("inputs") and what the config produces ("outputs"). The outputs block maps the hostname `nixos` to a full system config, assembled from `configuration.nix` and the Home Manager module. Before flakes, these dependencies were supplied by channels — global mutable state. The flake replaces that with an explicit, version-pinned dependency graph.
- **`flake.lock`** — Auto-generated lockfile that records the exact git commit hash of every input (nixpkgs, home-manager). When you rebuild, Nix uses these pinned versions — no surprise package changes. Commit this file to git alongside `flake.nix`. Update it intentionally with `nix flake update`.
- **`inputs.nixpkgs.follows = "nixpkgs"`** — Tells the home-manager flake input to use the same nixpkgs you declared above, rather than fetching its own copy. Without this, you'd end up with two separate evaluations of nixpkgs — different versions, doubled download time, and subtle inconsistencies between system and user packages.
- **Pure evaluation mode** — Flakes evaluate in a sandbox that forbids reading arbitrary absolute paths from the filesystem (e.g. `/etc/nixos/starship.toml`). Any file references in your config must be relative paths (e.g. `./starship.toml`) so Nix can track them as part of the flake's source tree. This is why `home.nix` uses `./starship.toml` instead of the absolute path.

---

## Where to Add New Packages

### System-wide packages (available to all users)
Edit `/etc/nixos/configuration.nix`:
```nix
environment.systemPackages = with pkgs; [
  # add here
];
```

### User-specific packages (luke only)
Edit `/etc/nixos/home.nix`:
```nix
home.packages = with pkgs; [
  # add here
];
```

### User program config (git, shell, prompt, etc.)
Edit `/etc/nixos/home.nix` using `programs.<name>`:
```nix
programs.git = { ... };
programs.fish = { ... };
programs.starship = { ... };
```

After any edit, apply with:
```bash
sudo nixos-rebuild switch --flake /etc/nixos#nixos
```

---

## Quick Reference

| Task | Command |
|------|---------|
| Rebuild and switch | `sudo nixos-rebuild switch --flake /etc/nixos#nixos` |
| Test config without switching | `sudo nixos-rebuild test --flake /etc/nixos#nixos` |
| List generations | `nix-env --list-generations --profile /nix/var/nix/profiles/system` |
| Rollback | `sudo nixos-rebuild switch --rollback` |
| Search packages | `nix search nixpkgs <package>` |
| Garbage collect | `sudo nix-collect-garbage -d` |
| Update all flake inputs | `cd /etc/nixos && nix flake update` |
| Update one flake input | `cd /etc/nixos && nix flake update nixpkgs` |

---

## Nix Commands Tutorial

This section covers the most useful Nix and NixOS commands you'll reach for day-to-day.

---

### Rebuilding the System

```bash
sudo nixos-rebuild switch --flake /etc/nixos#nixos
```
The one you'll use most. Applies your `configuration.nix` and `home.nix` changes and makes them active immediately. Also creates a new generation you can roll back to. The `#nixos` at the end refers to the `nixosConfigurations.nixos` output in `flake.nix` — it must match your hostname.

```bash
sudo nixos-rebuild test --flake /etc/nixos#nixos
```
Applies the config to the running system but **doesn't set it as the default boot entry**. Good for testing changes — if something breaks, rebooting brings you back to the last working config.

```bash
sudo nixos-rebuild boot --flake /etc/nixos#nixos
```
Builds the new config and sets it as the default for next boot, but doesn't activate it now. Useful when you want changes to take effect after a reboot without disrupting the current session.

```bash
sudo nixos-rebuild build --flake /etc/nixos#nixos
```
Just builds the config without activating anything. Useful to check for errors before committing to a change.

---

### Building a VM for Testing

```bash
sudo nixos-rebuild build-vm
```
Builds a QEMU virtual machine from your current `configuration.nix`. Great for testing risky config changes without touching your real system. After building, run it with:

```bash
./result/bin/run-*-vm
```
The VM is isolated — it doesn't share your real `/etc/nixos` or user data.

---

### Rolling Back

```bash
sudo nixos-rebuild switch --rollback
```
Switches to the previous generation. Useful if an update breaks something.

```bash
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system
```
Lists all system generations with timestamps so you can see what changed when.

```bash
sudo /nix/var/nix/profiles/system-<N>-link/bin/switch-to-configuration switch
```
Roll back to a specific generation number `N` (replace `<N>` with the number from the list above).

---

### Searching for Packages

```bash
nix search nixpkgs <name>
```
Searches nixpkgs for a package by name or description. Example:
```bash
nix search nixpkgs bat
```

```bash
nix-env -qaP | grep <name>
```
Alternative older-style search. Slower but works without flakes.

You can also search at **search.nixos.org** in a browser for a friendlier UI.

---

### Temporary Shells with `nix-shell`

```bash
nix-shell -p <package>
```
Drops you into a temporary shell with that package available, without installing it system-wide. When you exit the shell, it's gone. Example:
```bash
nix-shell -p ffmpeg
ffmpeg -i input.mp4 output.webm
exit  # ffmpeg is no longer available
```

```bash
nix-shell -p python3 nodejs git
```
You can specify multiple packages at once.

```bash
nix shell nixpkgs#<package>
```
The newer flakes-style equivalent of `nix-shell -p`. Does the same thing with slightly different syntax:
```bash
nix shell nixpkgs#bat nixpkgs#eza
```

---

### Updating Inputs (Flake-based workflow)

Since the system is now managed by a flake, `nixpkgs` and `home-manager` are pinned in `flake.lock` rather than tracked by channels. To update, you update the lockfile explicitly.

```bash
cd /etc/nixos && nix flake update
```
Fetches the latest commits for all inputs (nixpkgs, home-manager) and rewrites `flake.lock`. This is the equivalent of `nix-channel --update`. Nothing changes on your running system yet — you still need to rebuild.

```bash
cd /etc/nixos && nix flake update nixpkgs
```
Updates only the `nixpkgs` input, leaving home-manager pinned at its current commit. Useful for targeted updates.

**Full update workflow:**
```bash
cd /etc/nixos && nix flake update && sudo nixos-rebuild switch --flake /etc/nixos#nixos
```

> **Note:** Channels (`nix-channel`) are no longer used for nixpkgs or home-manager. You can ignore them for day-to-day use. `nix-channel --list` will still show the old system channel but it has no effect on flake-based builds.

---

### Garbage Collection

Nix never deletes old packages automatically — old generations and unused store paths accumulate over time.

```bash
sudo nix-collect-garbage
```
Deletes store paths that are no longer referenced by any current generation.

```bash
sudo nix-collect-garbage -d
```
Deletes **all** old generations first, then garbage collects. This is the aggressive version — you lose the ability to roll back after this.

```bash
nix-collect-garbage
```
Without sudo, cleans up your user profile's garbage (not system-wide).

```bash
sudo nix store gc
```
Newer-style equivalent of `nix-collect-garbage`. Same effect.

---

### Inspecting the Nix Store

```bash
nix-store -q --references $(which bat)
```
Lists what a package depends on.

```bash
nix-store -q --referrers $(which bat)
```
Lists what depends on a package (reverse lookup).

```bash
du -sh /nix/store
```
Check how much disk space the Nix store is using.

---

### Ad-hoc Package Running (without installing)

```bash
nix run nixpkgs#<package>
```
Runs a package directly without installing it. Example:
```bash
nix run nixpkgs#cowsay -- "hello from nix"
```

---

### Checking What's Installed

```bash
nix-env -q
```
Lists packages installed in your user profile (via `nix-env`, not `configuration.nix` or `home.nix`).

```bash
nix-env --list-generations
```
Lists generations of your **user** profile (separate from system generations).

---

*Updated: 2026-04-12*
