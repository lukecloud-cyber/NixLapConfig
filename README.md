# NixLapConfig

Luke's NixOS configuration — flake-based, with secrets managed by [sops-nix](https://github.com/Mic92/sops-nix).

## Repository structure

```
~/projects/NixLapConfig/
├── flake.nix                  # Entrypoint — declares nixpkgs, home-manager, sops-nix inputs
├── flake.lock                 # Pinned input versions (commit hashes) — commit this
├── configuration.nix          # System config: packages, services, boot, sops secrets
├── home.nix                   # User config (Home Manager): shell, git, prompt, aliases
├── starship.toml              # Starship prompt theme (read by home.nix at build time)
├── hardware-configuration.nix # Auto-generated hardware/disk config — machine-specific
├── nixswitch                  # Build + commit script (symlinked to ~/nixswitch by home-manager)
├── my_nix_config.md           # Human-readable config summary (copied from ~/ by nixswitch)
├── .sops.yaml                 # Tells sops which age key encrypts which files
└── secrets/
    ├── secrets.yaml           # Encrypted secrets (safe to commit — ciphertext only)
    └── age-key.txt            # !! GITIGNORED !! Private key — back this up to Bitwarden
```

The age private key must also exist at `/etc/nixos/secrets/age-key.txt` — that's the absolute path sops-nix reads at boot to decrypt secrets.

## Day-to-day usage

**Rebuild after editing config:**
```bash
nixswitch
```
This rebuilds NixOS from the repo, then prompts for a commit message. Enter one to commit and push, or leave empty to skip.

**Rebuild and commit in one shot:**
```bash
nixswitch --commit "add new package"
```

**Update all flake inputs to latest, then rebuild:**
```bash
nixswitch update
```

**Add or edit a secret:**
```bash
SOPS_AGE_KEY_FILE=/etc/nixos/secrets/age-key.txt sops ~/projects/NixLapConfig/secrets/secrets.yaml
```
This opens your editor with the decrypted YAML. Save and close — sops re-encrypts automatically.
After adding a new secret, declare it in `configuration.nix`:
```nix
sops.secrets.my_new_secret = { owner = "luke"; };
```
Then reference it in `home.nix` Fish shellInit as `cat /run/secrets/my_new_secret`.

---

## Restoring config on an existing system

If you need to pull your config onto an already-running NixOS system (e.g. after a reinstall where you didn't clone during setup, or syncing to a second machine):

```bash
# Git may not be installed yet on a fresh system
nix-shell -p git

# Clone to the standard location
git clone https://github.com/luke-c/NixLapConfig ~/projects/NixLapConfig

# Place the age key where sops-nix expects it
sudo mkdir -p /etc/nixos/secrets
sudo nano /etc/nixos/secrets/age-key.txt   # paste from Bitwarden

# Build and switch from the clone
sudo nixos-rebuild switch --flake ~/projects/NixLapConfig#nixos
```

---

## Recovery steps

> Use this guide to fully restore this system after a hardware failure, reinstall, or new machine setup.

### What you need before starting

- This repository (GitHub)
- Your **age private key** — stored in Bitwarden as a secure note titled `NixLapConfig age private key`
- A NixOS installer USB (download from [nixos.org](https://nixos.org/download))

---

### Step 1 — Boot the NixOS installer

Boot from the USB. You will land in a live environment with networking and a browser.

---

### Step 2 — Connect to the internet

The installer uses NetworkManager. Either connect via the GUI or:
```bash
nmcli device wifi connect "YourSSID" password "YourPassword"
```

---

### Step 3 — Partition and encrypt the disk

Partition your disk with LUKS encryption. Adjust `/dev/nvme0n1` to your actual disk:

```bash
# Create GPT partition table
parted /dev/nvme0n1 -- mklabel gpt

# Create EFI partition (512MB)
parted /dev/nvme0n1 -- mkpart ESP fat32 1MB 512MB
parted /dev/nvme0n1 -- set 1 esp on

# Create root partition (rest of disk)
parted /dev/nvme0n1 -- mkpart primary 512MB 100%

# Encrypt the root partition
cryptsetup luksFormat /dev/nvme0n1p2
cryptsetup open /dev/nvme0n1p2 cryptroot

# Format
mkfs.fat -F 32 -n boot /dev/nvme0n1p1
mkfs.ext4 -L nixos /dev/mapper/cryptroot

# Mount
mount /dev/disk/by-label/nixos /mnt
mkdir -p /mnt/boot
mount /dev/disk/by-label/boot /mnt/boot
```

---

### Step 4 — Generate hardware config and clone the repo

```bash
# Generate hardware-configuration.nix for this machine's actual disk UUIDs
nixos-generate-config --root /mnt

# Git is not on the installer by default
nix-shell -p git

# Clone the repo — will be the source for install
git clone https://github.com/luke-c/NixLapConfig /mnt/etc/nixos/repo

# Copy the freshly generated hardware-configuration.nix into the repo
# (this has the correct UUIDs for your new partitions)
cp /mnt/etc/nixos/hardware-configuration.nix /mnt/etc/nixos/repo/hardware-configuration.nix
```

**Important:** Even on the same hardware, fresh partitions get new UUIDs. Always use the generated `hardware-configuration.nix`, not the one from the repo.

---

### Step 5 — Retrieve the age private key from Bitwarden

Open Firefox in the live environment and go to **bitwarden.com**.

Log in and find the secure note titled **`NixLapConfig age private key`**. Copy the full contents.

Place it where sops-nix expects it:
```bash
mkdir -p /mnt/etc/nixos/repo/secrets
nano /mnt/etc/nixos/repo/secrets/age-key.txt   # paste the key, save with Ctrl+O, exit with Ctrl+X

# Also place it at the absolute path sops-nix reads at boot
mkdir -p /mnt/etc/nixos/secrets
cp /mnt/etc/nixos/repo/secrets/age-key.txt /mnt/etc/nixos/secrets/age-key.txt
```

The key file should look like:
```
# created: 2026-04-12T...
# public key: age1srnzl36smrhrquwc6z5hzwuehqq2y6q74fvlg7l8g6304sganqxqmxed9l
AGE-SECRET-KEY-1...
```

---

### Step 6 — Install

```bash
nixos-install --flake /mnt/etc/nixos/repo#nixos
```

This will download and build all packages. Set the root password when prompted.

---

### Step 7 — Set luke's password before rebooting

`nixos-install` only sets the root password. Luke's account has no password yet, so you won't be able to log in at SDDM without setting one now:

```bash
nixos-enter --root /mnt
passwd luke
exit
```

---

### Step 8 — Reboot

```bash
reboot
```

Log in as `luke`. Your full environment — shell, aliases, prompt, git config — will be active immediately. Secrets are decrypted from `secrets.yaml` on boot and available at `/run/secrets/`.

---

### Step 9 — Move the repo to its permanent location

After booting, move the cloned repo from the install location to where nixswitch expects it:

```bash
mkdir -p ~/projects
sudo mv /etc/nixos/repo ~/projects/NixLapConfig
sudo chown -R luke:users ~/projects/NixLapConfig
```

Verify everything works:
```bash
nixswitch
```

---

### Notes

- **New age key:** If you generate a new age key (e.g. new machine with different identity), you must re-encrypt `secrets/secrets.yaml` with `sops updatekeys secrets/secrets.yaml` and update `.sops.yaml` with the new public key.
- **Adding secrets:** See "Day-to-day usage" above.
