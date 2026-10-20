#!/usr/bin/env bash
set -Eeuo pipefail

# Read-only by default. No partitioning, formatting, disko or disk wipes.
REPO="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
HOST="$REPO/hosts/laptop"
MODE="${1:---inspect}"

usage() {
  echo 'Usage: bash laptop/bootstrap.sh [--inspect|--prepare|--apply]'
  echo '  --inspect  read-only hardware and installation diagnostics'
  echo '  --prepare copy installed hardware config and detect GPU PCI IDs'
  echo '  --apply   prepare, build and switch NixOS to #laptop'
}

if [[ "$MODE" != --inspect && "$MODE" != --prepare && "$MODE" != --apply ]]; then
  usage >&2
  exit 2
fi

inspect() {
  printf '\n== Root filesystem ==\n'
  findmnt -n -o SOURCE,FSTYPE,TARGET / || true
  printf '\n== Disks (read-only) ==\n'
  lsblk -o NAME,MODEL,SIZE,FSTYPE,MOUNTPOINTS || true
  printf '\n== Graphics PCI devices (read-only) ==\n'
  for dev in /sys/bus/pci/devices/*; do
    [[ -r "$dev/class" && -r "$dev/vendor" ]] || continue
    class="$(cat "$dev/class")"
    [[ "$class" == 0x03* ]] || continue
    printf '%s vendor=%s class=%s\n' "${dev##*/}" "$(cat "$dev/vendor")" "$class"
  done
  if [[ -r /etc/nixos/hardware-configuration.nix ]]; then
    echo 'Generated config: /etc/nixos/hardware-configuration.nix exists'
  else
    echo 'Generated config: NOT FOUND at /etc/nixos/hardware-configuration.nix'
  fi
}

inspect

if [[ "$MODE" == --inspect ]]; then
  exit 0
fi

if [[ "$EUID" -ne 0 ]]; then
  echo 'For --prepare or --apply, run with sudo on installed NixOS.' >&2
  exit 1
fi

root_fs="$(findmnt -n -o FSTYPE /)"
case "$root_fs" in
  overlay|squashfs|tmpfs|ramfs)
    echo "Refusing to apply host config from a Live ISO ($root_fs)." >&2
    echo 'Install a base NixOS system first, then boot it from SSD.' >&2
    exit 1 ;;
esac

if [[ ! -f /etc/nixos/hardware-configuration.nix ]]; then
  echo 'Cannot find generated hardware-configuration.nix on installed NixOS.' >&2
  exit 1
fi

mkdir -p "$HOST"
cp /etc/nixos/hardware-configuration.nix "$HOST/hardware-configuration.nix"

amd=''
nvidia=''
pci_bus_id() {
  local bdf="$1" domain rest bus dev fun
  domain="${bdf%%:*}"
  rest="${bdf#*:}"
  bus="${rest%%:*}"
  rest="${rest#*:}"
  dev="${rest%%.*}"
  fun="${rest##*.}"
  printf 'PCI:%d@%d:%d:%d' "$((16#$bus))" "$((16#$domain))" "$((16#$dev))" "$((16#$fun))"
}
for path in /sys/bus/pci/devices/*; do
  [[ -r "$path/class" && -r "$path/vendor" ]] || continue
  class="$(cat "$path/class")"
  [[ "$class" == 0x03* ]] || continue
  vendor="$(cat "$path/vendor")"
  bdf="${path##*/}"
  case "$vendor" in
    0x1002) amd="$(pci_bus_id "$bdf")" ;;
    0x10de) nvidia="$(pci_bus_id "$bdf")" ;;
  esac
done

if [[ -z "$amd" || -z "$nvidia" ]]; then
  echo "Both GPU IDs must be detected: AMD=${amd:-missing} NVIDIA=${nvidia:-missing}" >&2
  echo 'Switch BIOS to Hybrid/Optimus mode, then inspect again.' >&2
  exit 1
fi

cat > "$HOST/gpu-ids.nix" <<EOF
{
  amdgpuBusId = "$amd";
  nvidiaBusId = "$nvidia";
}
EOF

echo "Detected PRIME GPUs: AMD=$amd NVIDIA=$nvidia"
echo 'Hardware configuration copied; existing disks/partitions untouched.'

if [[ "$MODE" == --prepare ]]; then
  echo "Review generated files, then run: sudo bash laptop/bootstrap.sh --apply"
  exit 0
fi

cd "$REPO"
echo '==> Evaluating and building laptop configuration (no activation yet)'
nixos-rebuild build --flake .#laptop
echo '==> Build succeeded; activating laptop configuration'
nixos-rebuild switch --flake .#laptop
echo 'Laptop configuration activated. Reboot to load NVIDIA driver if required.'
