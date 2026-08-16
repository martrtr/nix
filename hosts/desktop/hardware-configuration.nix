# Hardware profile for:
# - Gigabyte B550M AORUS ELITE
# - AMD Ryzen 5 5600
# - AMD Radeon RX 7800 XT
# - ADATA LEGEND 960 NVMe
#
# File systems are declared by disko.nix, so they must not be duplicated here.
{ config, lib, ... }:
{
  boot.initrd.availableKernelModules = [
    "nvme"
    "xhci_pci"
    "ahci"
    "usb_storage"
    "usbhid"
    "sd_mod"
  ];
  boot.initrd.kernelModules = [ "amdgpu" ];
  boot.kernelModules = [
    "kvm-amd"
    "v4l2loopback"
  ];
  boot.extraModulePackages = with config.boot.kernelPackages; [
    v4l2loopback
  ];
  boot.extraModprobeConfig = ''
    options v4l2loopback devices=1 video_nr=10 card_label="OBS Virtual Camera" exclusive_caps=1
  '';

  hardware.cpu.amd.updateMicrocode =
    lib.mkDefault config.hardware.enableRedistributableFirmware;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
