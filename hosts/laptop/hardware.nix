{ config, lib, pkgs, ... }:
let
  gpu = import ./gpu-ids.nix;
  nvidiaReady = gpu.nvidiaBusId != null;
  amdReady = gpu.amdgpuBusId != null;
  primeReady = amdReady && nvidiaReady;
in
{
  # The old desktop hardware module configured RX 7800 XT and a Gigabyte
  # motherboard. This notebook instead has a Ryzen APU + RTX 3060 Laptop.
  hardware.enableRedistributableFirmware = true;
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };
  # A MUX switch can hide the AMD iGPU completely. In dGPU-only mode
  # NVIDIA drives the display directly, without PRIME.
  services.xserver.videoDrivers =
    (lib.optionals amdReady [ "amdgpu" ])
    ++ (lib.optionals nvidiaReady [ "nvidia" ]);

  hardware.nvidia = lib.mkIf nvidiaReady {
    # RTX 3060 (Ampere) supports NVIDIA's official open kernel modules.
    open = true;
    modesetting.enable = true;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    prime = lib.mkIf primeReady {
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

  # Use offload only in hybrid mode; a dGPU-only system runs both apps
  # directly, because "nvidia-offload" is not available or needed there.
  home-manager.users.mart.xdg.dataFile = lib.mkIf nvidiaReady {
    "applications/prismlauncher-rtx.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=PrismLauncher (RTX 3060)
      Exec=${if primeReady then "nvidia-offload " else ""}prismlauncher
      Icon=prismlauncher
      Categories=Game;
      Terminal=false
    '';
    "applications/davinci-resolve-rtx.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=DaVinci Resolve (RTX 3060)
      Exec=${if primeReady then "nvidia-offload " else ""}davinci-resolve-nixos
      Icon=davinci-resolve
      Categories=AudioVideo;Video;
      Terminal=false
    '';
  };

  # No desktop-specific OpenRGB motherboard or ROCm ICD in this laptop host.
  environment.systemPackages = with pkgs; [
    vulkan-tools
    mesa-demos
    libva-utils
    pciutils
    usbutils
  ];
}
