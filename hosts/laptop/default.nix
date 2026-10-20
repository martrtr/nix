{ ... }:
{
  # Dedicated Mechrevo host. No desktop Disko profile or desktop hardware config.
  imports = [
    ./hardware-configuration.nix
    ./hardware.nix
    ../../modules/core
    ../../modules/desktop
    ../../modules/gaming
  ];
}
