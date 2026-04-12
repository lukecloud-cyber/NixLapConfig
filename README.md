# NixLapConfig

Luke's NixOS configuration — flake-based, with secrets managed by [sops-nix](https://github.com/Mic92/sops-nix).

## Repository structure

```
/etc/nixos/
├── flake.nix                  # Entrypoint — declares nixpkgs, home-manager, sops-nix inputs
├── flake.lock                 # Pinned input versions (commit hashes) — commit this
├── configuration.nix          # System config: packages, services, boot, sops secrets
├── home.nix                   # User config (Home Manager): shell, git, prompt, aliases
├── starship.toml              # Starship prompt theme (read by home.nix at build time)
├── hardware-configuration.nix # Auto-generated hardware/disk config — machine-specific
├── my_nix_config.md         # Human-readable config summary (copied from ~/ by nixswitch)
├── .sops.yaml                 # Tells sops which age key encrypts which files
└── secrets/
    ├── secrets.yaml           # Encrypted secrets (safe to commit — ciphertext only)
    └── age-key.txt            # !! GITIGNORED !! Private key — back this up to Bitwarden
```

## Day-to-day usage

**After editing any config file:**
```bash
sudo nixos-rebuild switch --flake /etc/nixos#nixos
```

**Add or edit a secret:**
```bash
SOPS_AGE_KEY_FILE=/etc/nixos/secrets/age-key.txt sops /etc/nixos/secrets/secrets.yaml
```
This opens your editor with the decrypted YAML. Save and close — sops re-encrypts automatically.
After adding a new secret, declare it in `configuration.nix`:
```nix
sops.secrets.my_new_secret = { owner = "luke"; };
```
Then reference it in `home.nix` Fish shellInit as `cat /run/secrets/my_new_secret`.

**Update all inputs to latest:**
```bash
sudo nix flake update --flake /etc/nixos
sudo nixos-rebuild switch --flake /etc/nixos#nixos
```

---

## Restoring config on an existing system

If you need to pull your config onto an already-running NixOS system (e.g. after a reinstall where you didn't clone during setup, or syncing to a second machine):

```bash
# Clone to a safe location — do NOT clone directly into /etc/nixos
git clone https://github.com/luke-c/NixLapConfig ~/nixos-restore

# Place the age key
mkdir -p ~/nixos-restore/secrets
nano ~/nixos-restore/secrets/age-key.txt   # paste from Bitwarden

# Build and switch from the clone
sudo nixos-rebuild switch --flake ~/nixos-restore#nixos
```

Once you're happy, you can make the clone your working directory by updating `FLAKE_DIR` in `~/nixswitch`, or copy it over to `/etc/nixos/`.

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

# Create main partition (rest of disk)
parted /dev/nvme0n1 -- mkpart primary 512MB 100%

# Encrypt the main partition
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

### Step 4 — Clone this repo

```bash
# Install git in the live environment
nix-shell -p git

# Clone into /mnt/etc/nixos (replacing the generated config)
git clone https://github.com/luke-c/NixLapConfig /mnt/etc/nixos
```

---

### Step 5 — Retrieve the age private key from Bitwarden

Open Firefox in the live environment and go to **bitwarden.com**.

Log in and find the secure note titled **`NixLapConfig age private key`**. Copy the full contents.

Place it on the target system:
```bash
mkdir -p /mnt/etc/nixos/secrets
nano /mnt/etc/nixos/secrets/age-key.txt   # paste the key, save with Ctrl+O, exit with Ctrl+X
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
nixos-install --flake /mnt/etc/nixos#nixos
```

This will:
- Download and build all packages
- Use `hardware-configuration.nix` from the repo (already matched to this hardware)
- Decrypt `secrets/secrets.yaml` using the age key you placed in Step 5
- Write all secrets to `/run/secrets/` on first boot

Set the root password when prompted at the end.

---

### Step 7 — Reboot

```bash
reboot
```

Log in as `luke`. Your full environment — shell, aliases, prompt, git config, and all secrets — will be active immediately.

---

### Step 8 — Set luke's password

```bash
passwd
```

---

### Notes

- **Different hardware:** If recovering to a different machine, run `nixos-generate-config --root /mnt` after Step 3, then copy the generated `hardware-configuration.nix` over the one in the cloned repo before Step 6.
- **New age key:** If you generate a new age key (e.g. new machine with different identity), you must re-encrypt `secrets/secrets.yaml` with `sops updatekeys secrets/secrets.yaml` and update `.sops.yaml` with the new public key.
- **Adding secrets:** See "Day-to-day usage" above.
