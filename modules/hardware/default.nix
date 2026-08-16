{ pkgs, ... }:
{
  hardware.enableRedistributableFirmware = true;

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = [
      pkgs.rocmPackages.clr.icd
    ];
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
  services.hardware.openrgb = {
    enable = true;
    motherboard = "amd";
  };

  # Some Gigabyte firmware exposes GPP0 as an always-firing ACPI wake source.
  # /proc/acpi/wakeup uses toggle semantics, so only write when it is enabled.
  systemd.services.disable-gpp0-wakeup = {
    description = "Disable enabled GPP0 ACPI wake source";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      if [ -r /proc/acpi/wakeup ] \
        && ${pkgs.gnugrep}/bin/grep -qE '^GPP0[[:space:]].*\*enabled' /proc/acpi/wakeup
      then
        echo GPP0 > /proc/acpi/wakeup
      fi
    '';
  };

  environment.systemPackages = with pkgs; [
    vulkan-tools
    libva-utils
    mesa-demos
    clinfo
    llama-cpp-vulkan
  ];
}
