{ settings, ... }:
{
  # Clash Verge Rev is a full desktop frontend for Mihomo. Service mode keeps
  # privileged TUN operations in the system service instead of running the GUI
  # itself with network capabilities.
  programs.clash-verge = {
    enable = true;
    serviceMode = true;
    tunMode = true;
    autoStart = false;
    group = "users";
  };

  # The normal user is already a member of users, but keeping the service group
  # explicit documents who may access Clash Verge's privileged service socket.
  users.users.${settings.username}.extraGroups = [ "users" ];
}
