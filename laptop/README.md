# Mechrevo Laptop (Ryzen APU + RTX 3060) — NixOS / Niri / iNiR

This branch adds an independent `nixosConfigurations.laptop` to `martrtr/nix`.
The existing `desktop` profile for ADATA / RX 7800 XT is unchanged.

## Important limits

- **No disk partitioning or formatting** is performed by this branch or its
  bootstrap script. Do not use the desktop-only `install.sh` on this laptop.
- This branch is intended for an **already installed NixOS** with
  `/etc/nixos/hardware-configuration.nix`. If running from the graphical
  installer USB, complete the ordinary NixOS installation and boot from SSD first.
- The checked-in `hosts/laptop/hardware-configuration.nix` is deliberately
  **non-installable** until replaced with the actual laptop's generated hardware file.
- The GPU IDs are determined from the actual laptop's PCI sysfs entries. No
  hard-coded example addresses are used.
- NVIDIA is enabled with PRIME offload. The Niri desktop uses the AMD APU
  for ordinary rendering; GPU-intensive apps may be launched with `nvidia-offload`.
- RTX 3060 uses the official NVIDIA open kernel modules (`hardware.nvidia.open = true`).
  This is NOT the community reverse-engineered `nouveau` driver.

## Inspect from a NixOS terminal (safe on either USB or installed NixOS)

```sh
git clone --branch feature/mechrevo-laptop-rtx3060 --single-branch https://github.com/martrtr/nix.git
cd nix
bash laptop/bootstrap.sh --inspect
```

This prints root filesystem, disk layout, detected PCI GPUs and whether the
generated NixOS hardware file exists. No changes are made.

## Activate on the installed NixOS

From a terminal in the cloned repository:

```sh
sudo bash laptop/bootstrap.sh --prepare
sudo bash laptop/bootstrap.sh --apply
```

The script copies the installed hardware file, generates real PRIME PCI IDs,
builds first, and only activates after the build succeeds. It preserves the
base NixOS installation and does not format any drive.

> Note: This is a substantial desktop build with Home Manager, iNiR, Discord,
> Zen, Steam and DaVinci; a working network and disk space are needed.
> The build was not executed on the actual laptop yet.

After boot:

```sh
nvidia-smi
nvidia-offload glxinfo -B
niri msg version
```

Check boot and sleep as well as Wi-Fi, audio, Bluetooth and suspend before
treating the port as finished.

## Security of remote installation

If you have posted a screenshot showing the browser terminal's URL and
password, **end that shell.online session and create a new one** before
using it for further administration. A root shell exposed through a shareable
link grants full control to anybody who obtains the link/password.

Avoid publicly committing passwords, device tokens or secrets.
