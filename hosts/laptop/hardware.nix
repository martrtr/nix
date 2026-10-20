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

  # Optional launchers that explicitly select the discrete NVIDIA GPU.
  # Keeping plain PrismLauncher and plain DaVinci available on the AMD APU
  # avoids forcing the RTX 3060 to stay awake for every desktop application.
  home-manager.users.mart.xdg.dataFile = lib.mkIf primeReady {
    "applications/prismlauncher-rtx.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=PrismLauncher (RTX 3060)
      Exec=nvidia-offload prismlauncher
      Icon=prismlauncher
      Categories=Game;
      Terminal=false
    '';
    "applications/davinci-resolve-rtx.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=DaVinci Resolve (RTX 3060)
      Exec=nvidia-offload davinci-resolve-nixos
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
