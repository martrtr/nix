{ config, lib, pkgs, ... }:
let
  gpu = import ./gpu-ids.nix;
  primeReady = gpu.amdgpuBusId != null && gpu.nvidiaBusId != null;
in
{
  # The old desktop hardware module configured RX 7800 XT and a Gigabyte
  # motherboard. This notebook instead has a Ryzen APU + RTX 3060 Laptop.
  hardware.enableRedistributableFirmware = true;
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };
  services.xserver.videoDrivers =
    [ "amdgpu" ] ++ lib.optionals primeReady [ "nvidia" ];

  hardware.nvidia = lib.mkIf primeReady {
    # RTX 3060 is Ampere; NVIDIA's open kernel module supports it.
    open = true;
    modesetting.enable = true;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    prime = {
      offload.enable = true;
      offload.enableOffloadCmd = true;
      amdgpuBusId = gpu.amdgpuBusId;
      nvidiaBusId = gpu.nvidiaBusId;
    };
  };

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };
  services.blueman.enable = true;

  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  };
  services.fwupd.enable = true;
  services.upower.enable = true;
  services.power-profiles-daemon.enable = true;
  services.fstrim.enable = true;

  # No desktop-specific OpenRGB motherboard or ROCm ICD in this laptop host.
  environment.systemPackages = with pkgs; [
    vulkan-tools
    mesa-demos
    libva-utils
    pciutils
    usbutils
  ];
}
